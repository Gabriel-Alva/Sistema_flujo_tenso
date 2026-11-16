import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/api_provider.dart';
import '../../core/theme/sipan_tokens.dart';
import '../../core/widgets/sipan_icon.dart';
import '../menu/menu_page.dart';
import 'order_repository.dart';

class OrderTrackingPage extends ConsumerStatefulWidget {
  const OrderTrackingPage({super.key, required this.orderId});

  final int orderId;

  @override
  ConsumerState<OrderTrackingPage> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends ConsumerState<OrderTrackingPage> {
  late final OrderRepository _orders;
  Map<String, dynamic>? _details;
  bool _loading = true;
  String? _error;
  bool _cancelling = false;
  final Set<int> _deliveringItems = {};
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _orders = OrderRepository(
      ref.read(apiClientProvider),
      const FlutterSecureStorage(),
    );
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _load();
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final details = await _orders.orderDetails(widget.orderId);
      if (!mounted) return;
      setState(() {
        _details = details;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _errorMessage(error);
        _loading = false;
      });
    }
  }

  String _errorMessage(Object error) {
    if (error is DioException && error.response?.data is Map) {
      final message = (error.response!.data as Map)['message'];
      if (message is String) return message;
    }
    if (error is DioException && error.response == null) {
      return 'No se pudo conectar con el API. Verifica la red y API_BASE.';
    }
    return 'No se pudo cargar el pedido: $error';
  }

  void _showFeedback(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError
              ? const Color(0xFF9B1C31)
              : const Color(0xFF087A45),
          content: Row(
            children: [
              SipanIcon(
                isError ? 'warning' : 'check',
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }

  Color _itemStatusColor(String status) {
    switch (status) {
      case 'PENDIENTE':
        return const Color(0xFFB36B00);
      case 'EN_PREPARACION':
        return const Color(0xFF1769AA);
      case 'LISTO':
        return const Color(0xFF087A45);
      case 'ENTREGADO':
        return const Color(0xFF476B56);
      case 'CANCELADO':
        return const Color(0xFF737B86);
      default:
        return SipanTokens.muted;
    }
  }

  String _itemStatusIcon(String status) {
    switch (status) {
      case 'PENDIENTE':
        return 'clock';
      case 'EN_PREPARACION':
        return 'chef';
      case 'LISTO':
        return 'ready';
      case 'ENTREGADO':
        return 'delivered';
      case 'CANCELADO':
        return 'warning';
      default:
        return 'receipt';
    }
  }

  Widget _statusBadge(String status) {
    final color = _itemStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SipanIcon(_itemStatusIcon(status), color: color, size: 15),
          const SizedBox(width: 6),
          Text(
            status.replaceAll('_', ' '),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountMetric(String label, String value, String icon, Color color) {
    return Container(
      constraints: const BoxConstraints(minWidth: 105),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SipanIcon(icon, color: color, size: 19),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: SipanTokens.muted, fontSize: 11),
              ),
              Text(
                'S/ $value',
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _orderSummaryCard(
    Map<String, dynamic>? order,
    Map<String, dynamic>? account,
    Map<String, dynamic> deliveryInfo,
  ) {
    final status = order?['estado']?.toString() ?? '—';
    final statusColor = status == 'PAGADO'
        ? const Color(0xFF087A45)
        : status == 'ANULADO'
        ? SipanTokens.statusCancelled
        : status == 'EN_PAGO'
        ? const Color(0xFFB36B00)
        : SipanTokens.brandPrimary;
    final isDelivery = order?['tipo'] == 'DELIVERY';
    final location = isDelivery
        ? '${deliveryInfo['linea_direccion'] ?? 'Dirección no disponible'}'
              '${deliveryInfo['distrito'] == null ? '' : ' · ${deliveryInfo['distrito']}'}'
        : 'Mesa ${order?['numero_mesa'] ?? order?['id_mesa'] ?? '—'}'
              ' · ${order?['num_comensales'] ?? '—'} comensales';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SipanTokens.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                alignment: Alignment.center,
                child: SipanIcon('receipt', color: statusColor, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedido #${widget.orderId}',
                      style: const TextStyle(
                        color: SipanTokens.ink,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      location,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SipanTokens.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  status.replaceAll('_', ' '),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _accountMetric(
                'Total',
                account?['total']?.toString() ?? '—',
                'payment',
                SipanTokens.brandPrimary,
              ),
              _accountMetric(
                'Pagado',
                account?['total_pagado']?.toString() ?? '0.00',
                'check',
                const Color(0xFF087A45),
              ),
              _accountMetric(
                'Pendiente',
                account?['saldo_pendiente']?.toString() ?? '—',
                'clock',
                const Color(0xFFB36B00),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _deliverItem(int itemId) async {
    setState(() => _deliveringItems.add(itemId));
    try {
      await _orders.markItemDelivered(itemId);
      await _load();
      if (!mounted) return;
      _showFeedback('Plato marcado como entregado.');
    } catch (error) {
      if (!mounted) return;
      _showFeedback(_errorMessage(error), isError: true);
    } finally {
      if (mounted) setState(() => _deliveringItems.remove(itemId));
    }
  }

  Future<void> _addRound(Map<String, dynamic> order) async {
    final isDelivery = order['tipo'] == 'DELIVERY';
    final tableId = int.tryParse(order['id_mesa']?.toString() ?? '');
    if (!isDelivery && tableId == null) {
      _showFeedback('El pedido no tiene una mesa válida.', isError: true);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MenuPage(
          idMesa: tableId,
          tipo: order['tipo']?.toString() ?? 'SALON',
          idPedido: widget.orderId,
          clienteDelivery: isDelivery ? _deliveryCustomer(order) : null,
          comensales: int.tryParse(order['num_comensales']?.toString() ?? ''),
          etiqueta: 'Pedido #${widget.orderId}',
        ),
      ),
    );
    if (mounted) _load();
  }

  Map<String, dynamic> _deliveryCustomer(Map<String, dynamic> order) {
    final rawSnapshot = order['direccion_snapshot'];
    Map<String, dynamic> snapshot = {};
    if (rawSnapshot is Map) {
      snapshot = Map<String, dynamic>.from(rawSnapshot);
    } else if (rawSnapshot is String) {
      try {
        final decoded = jsonDecode(rawSnapshot);
        if (decoded is Map) snapshot = Map<String, dynamic>.from(decoded);
      } on FormatException {
        snapshot = {};
      }
    }
    return {
      ...snapshot,
      'id_cliente': order['id_cliente'],
      'id_direccion': order['id_direccion_entrega'],
    };
  }

  Future<void> _cancelOrder() async {
    final reasonController = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Row(
            children: [
              SipanIcon(
                'warning',
                color: SipanTokens.statusCancelled,
                size: 22,
              ),
              SizedBox(width: 10),
              Expanded(child: Text('Cancelar pedido')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cuéntanos por qué necesitas cancelar este pedido.',
                style: TextStyle(color: SipanTokens.muted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                maxLength: 250,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Motivo',
                  hintText: 'Escribe al menos 3 caracteres',
                  alignLabelWithHint: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Volver'),
            ),
            FilledButton.icon(
              onPressed: reasonController.text.trim().length < 3
                  ? null
                  : () => Navigator.pop(context, reasonController.text.trim()),
              icon: const Icon(Icons.close_rounded),
              label: const Text('Cancelar pedido'),
              style: FilledButton.styleFrom(
                backgroundColor: SipanTokens.statusCancelled,
              ),
            ),
          ],
        ),
      ),
    );
    reasonController.dispose();
    if (reason == null || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await _orders.cancelOrder(widget.orderId, reason);
      await _load();
      if (!mounted) return;
      _showFeedback('Pedido cancelado.');
    } catch (error) {
      if (!mounted) return;
      _showFeedback(_errorMessage(error), isError: true);
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  String _elapsed(String? value) {
    if (value == null) return 'Tiempo no disponible';
    final sentAt = DateTime.tryParse(value);
    if (sentAt == null) return 'Tiempo no disponible';
    final elapsed = DateTime.now().difference(sentAt.toLocal());
    final minutes = elapsed.inMinutes;
    if (minutes < 1) return 'menos de 1 min';
    if (minutes < 60) return '$minutes min';
    return '${minutes ~/ 60} h ${minutes % 60} min';
  }

  Widget _roundTimer(String round, String sentAt) {
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        border: Border.all(color: const Color(0xFFF2CACA)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SipanIcon('clock', color: SipanTokens.brandPrimary, size: 17),
          const SizedBox(width: 7),
          Text(
            'Ronda $round · ${_elapsed(sentAt)}',
            style: const TextStyle(
              color: SipanTokens.brandPrimaryDark,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderItemCard(Map<String, dynamic> item) {
    final itemId = int.tryParse(item['id_detalle']?.toString() ?? '');
    final status = item['estado_item']?.toString() ?? '—';
    final canDeliver = status == 'LISTO' && itemId != null;
    final note = item['nota']?.toString().trim() ?? '';
    final color = _itemStatusColor(status);
    final isDelivering = itemId != null && _deliveringItems.contains(itemId);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: SipanTokens.line),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: SipanIcon(
                  _itemStatusIcon(status),
                  color: color,
                  size: 21,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['nombre_snapshot']?.toString() ??
                          item['id_producto']?.toString() ??
                          'Producto',
                      style: const TextStyle(
                        color: SipanTokens.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ronda ${item['numero_ronda'] ?? '—'} · '
                      'Cantidad ${item['cantidad'] ?? '—'}',
                      style: const TextStyle(
                        color: SipanTokens.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusBadge(status),
            ],
          ),
          if (note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6F8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.notes_rounded,
                    color: SipanTokens.muted,
                    size: 17,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      note,
                      style: const TextStyle(
                        color: SipanTokens.ink,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (canDeliver) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: isDelivering ? null : () => _deliverItem(itemId),
                icon: isDelivering
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const SipanIcon(
                        'delivered',
                        color: Color(0xFF087A45),
                        size: 18,
                      ),
                label: Text(
                  isDelivering ? 'Actualizando…' : 'Marcar entregado',
                ),
                style: FilledButton.styleFrom(
                  foregroundColor: const Color(0xFF087A45),
                  backgroundColor: const Color(0xFFE9F6EE),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _paymentCard(Map<String, dynamic> payment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: SipanTokens.line),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const SipanIcon('payment', color: SipanTokens.brandPrimary, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment['metodo']?.toString() ?? 'Pago',
                  style: const TextStyle(
                    color: SipanTokens.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  payment['created_at']?.toString() ?? '',
                  style: const TextStyle(
                    color: SipanTokens.muted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            'S/ ${payment['monto'] ?? '—'}',
            style: const TextStyle(
              color: SipanTokens.brandPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _details?['pedido'] as Map<String, dynamic>?;
    final account = _details?['cuenta'] as Map<String, dynamic>?;
    final items = (_details?['items'] as List<dynamic>?) ?? [];
    final payments = (_details?['pagos'] as List<dynamic>?) ?? [];
    final deliveryInfo = order == null
        ? <String, dynamic>{}
        : _deliveryCustomer(order);
    final canAddRound = order?['estado'] == 'ABIERTO';
    final rounds = <String, String>{};
    for (final rawItem in items) {
      if (rawItem is! Map) continue;
      final item = Map<String, dynamic>.from(rawItem);
      final number = item['numero_ronda']?.toString();
      if (number != null) {
        rounds.putIfAbsent(number, () => item['enviado_en']?.toString() ?? '');
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: Row(
          children: [
            const SipanIcon('receipt', color: Colors.white, size: 21),
            const SizedBox(width: 10),
            Text('Pedido #${widget.orderId}'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar pedido',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: SipanTokens.brandPrimary),
            )
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: SipanTokens.line),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SipanIcon(
                        'warning',
                        color: SipanTokens.statusCancelled,
                        size: 38,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: SipanTokens.ink),
                      ),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : RefreshIndicator(
              color: SipanTokens.brandPrimary,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                children: [
                  _orderSummaryCard(order, account, deliveryInfo),
                  const SizedBox(height: 20),
                  const Text(
                    'Productos del pedido',
                    style: TextStyle(
                      color: SipanTokens.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (rounds.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      children: rounds.entries
                          .map((entry) => _roundTimer(entry.key, entry.value))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 6),
                  if (items.isEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: SipanTokens.line),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Row(
                        children: [
                          SipanIcon(
                            'receipt',
                            color: SipanTokens.muted,
                            size: 22,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'El pedido todavía no tiene productos.',
                              style: TextStyle(color: SipanTokens.muted),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ...items.map(
                    (rawItem) => _orderItemCard(
                      Map<String, dynamic>.from(rawItem as Map),
                    ),
                  ),
                  if (payments.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    const Text(
                      'Pagos registrados',
                      style: TextStyle(
                        color: SipanTokens.ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...payments.map(
                      (rawPayment) => _paymentCard(
                        Map<String, dynamic>.from(rawPayment as Map),
                      ),
                    ),
                  ],
                ],
              ),
            ),
      bottomNavigationBar: !_loading && _error == null && canAddRound
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _cancelling ? null : _cancelOrder,
                      icon: _cancelling
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.close_rounded),
                      label: const Text('Cancelar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: SipanTokens.statusCancelled,
                        side: const BorderSide(
                          color: SipanTokens.statusCancelled,
                        ),
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: order == null ? null : () => _addRound(order),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Agregar ronda'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}
