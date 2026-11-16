import 'dart:convert';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/api_client.dart';

class OrderLine {
  OrderLine({
    required this.productId,
    required this.name,
    required this.quantity,
    this.variantId,
    this.variantName,
    this.unitPrice = 0,
    this.note = '',
    Set<int>? modifiers,
  }) : modifiers = modifiers ?? <int>{};

  final String productId;
  final String name;
  int quantity;
  final int? variantId;
  final String? variantName;
  final double unitPrice;
  String note;
  final Set<int> modifiers;

  Map<String, Object> toRequestJson() {
    final request = <String, Object>{
      'id_producto': productId,
      'cantidad': quantity,
      'prioridad': 'NORMAL',
      'nota': note.trim(),
      'modificadores': modifiers.toList(),
    };
    final selectedVariantId = variantId;
    if (selectedVariantId != null) {
      request['id_variante'] = selectedVariantId;
    }
    return request;
  }
}

class OrderSubmission {
  const OrderSubmission({required this.queued, this.response});

  final bool queued;
  final Map<String, dynamic>? response;
}

class SyncResult {
  const SyncResult({required this.sent, required this.errors});

  final int sent;
  final List<String> errors;
}

class OrderRepository {
  OrderRepository(this._api, this._storage);

  static const _queueKey = 'waiter_pending_orders';
  final ApiClient _api;
  final FlutterSecureStorage _storage;

  Future<int> pendingCount() async => (await _readQueue()).length;

  Future<OrderSubmission> createSalonOrder({
    required int tableId,
    required int diners,
    required List<OrderLine> items,
    String? notes,
    int? orderId,
  }) async {
    final request = <String, Object?>{
      'client_request_id': _newUuid(),
      'tipo': 'SALON',
      'id_mesa': tableId,
      'num_comensales': diners,
      'notas_generales': notes?.trim(),
      'items': items.map((item) => item.toRequestJson()).toList(),
    };
    if (orderId != null) request['id_pedido'] = orderId;

    return _submitOrder(request);
  }

  Future<OrderSubmission> createDeliveryOrder({
    required int customerId,
    required int addressId,
    required Map<String, Object> addressSnapshot,
    required List<OrderLine> items,
    String? notes,
    int? orderId,
  }) {
    final request = <String, Object?>{
      'client_request_id': _newUuid(),
      'tipo': 'DELIVERY',
      'id_cliente': customerId,
      'id_direccion_entrega': addressId,
      'direccion_snapshot': addressSnapshot,
      'notas_generales': notes?.trim(),
      'items': items.map((item) => item.toRequestJson()).toList(),
    };
    if (orderId != null) request['id_pedido'] = orderId;
    return _submitOrder(request);
  }

  Future<OrderSubmission> _submitOrder(Map<String, Object?> request) async {
    try {
      final response = await _api.dio.post('/pedidos', data: request);
      return OrderSubmission(
        queued: false,
        response: Map<String, dynamic>.from(response.data as Map),
      );
    } on DioException catch (error) {
      if (error.response != null || !_isNetworkFailure(error)) rethrow;
      final queue = await _readQueue();
      queue.add(request);
      await _writeQueue(queue);
      return const OrderSubmission(queued: true);
    }
  }

  Future<List<Map<String, dynamic>>> activeOrders() async {
    final responses = await Future.wait([
      _api.dio.get('/pedidos', queryParameters: {'estado': 'ABIERTO'}),
      _api.dio.get('/pedidos', queryParameters: {'estado': 'EN_PAGO'}),
    ]);

    return responses
        .expand((response) => response.data as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList()
      ..sort(
        (left, right) => (int.tryParse(right['id_pedido'].toString()) ?? 0)
            .compareTo(int.tryParse(left['id_pedido'].toString()) ?? 0),
      );
  }

  Future<List<Map<String, dynamic>>> historyOrders() async {
    final responses = await Future.wait([
      _api.dio.get('/pedidos', queryParameters: {'estado': 'PAGADO'}),
      _api.dio.get('/pedidos', queryParameters: {'estado': 'ANULADO'}),
    ]);

    return responses
        .expand((response) => response.data as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList()
      ..sort(
        (left, right) => (int.tryParse(right['id_pedido'].toString()) ?? 0)
            .compareTo(int.tryParse(left['id_pedido'].toString()) ?? 0),
      );
  }

  Future<List<Map<String, dynamic>>> searchDeliveryCustomers(
    String query,
  ) async {
    final response = await _api.dio.get(
      '/pedidos/clientes',
      queryParameters: {'q': query.trim()},
    );
    return (response.data as List<dynamic>)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> orderDetails(int orderId) async {
    final response = await _api.dio.get('/pedidos/$orderId');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> markItemDelivered(int itemId) async {
    await _api.dio.patch('/pedidos/items/$itemId/entregado');
  }

  Future<void> cancelOrder(int orderId, String reason) async {
    await _api.dio.patch(
      '/pedidos/$orderId/cancelar',
      data: {'motivo': reason.trim()},
    );
  }

  Future<SyncResult> syncPending() async {
    final pending = await _readQueue();
    final remaining = <Map<String, dynamic>>[];
    final errors = <String>[];
    var sent = 0;

    for (var index = 0; index < pending.length; index++) {
      final request = pending[index];
      try {
        await _api.dio.post('/pedidos', data: request);
        sent++;
      } on DioException catch (error) {
        remaining.add(request);
        errors.add(_describeError(error));
        if (_isNetworkFailure(error)) {
          remaining.addAll(pending.skip(index + 1));
          break;
        }
      } catch (error) {
        remaining.add(request);
        errors.add(error.toString());
      }
    }
    await _writeQueue(remaining);
    return SyncResult(sent: sent, errors: errors);
  }

  Future<List<Map<String, dynamic>>> _readQueue() async {
    final raw = await _storage.read(key: _queueKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      throw const FormatException(
        'La cola local de pedidos no tiene un formato válido.',
      );
    }
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<void> _writeQueue(List<Map<String, dynamic>> queue) async {
    await _storage.write(key: _queueKey, value: jsonEncode(queue));
  }

  bool _isNetworkFailure(DioException error) =>
      error.response == null &&
      error.type != DioExceptionType.cancel &&
      error.type != DioExceptionType.badResponse;

  String _describeError(DioException error) {
    final body = error.response?.data;
    if (body is Map && body['message'] is String) {
      return body['message'] as String;
    }
    return error.response == null
        ? 'Sin conexión con el API; el pedido permanece guardado.'
        : 'El API rechazó un pedido pendiente (HTTP ${error.response?.statusCode}).';
  }

  String _newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
