import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/api_provider.dart';
import '../../core/theme/sipan_tokens.dart';
import 'order_repository.dart';
import 'order_tracking_page.dart';

class OrderHistoryPage extends ConsumerStatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  ConsumerState<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends ConsumerState<OrderHistoryPage> {
  late final OrderRepository _orders;
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _orders = OrderRepository(
      ref.read(apiClientProvider),
      const FlutterSecureStorage(),
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final history = await _orders.historyOrders();
      if (!mounted) return;
      setState(() {
        _history = history;
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
    return 'No se pudo cargar el historial: $error';
  }

  Future<void> _openOrder(int orderId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => OrderTrackingPage(orderId: orderId)),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de pedidos'),
        actions: [
          IconButton(
            tooltip: 'Actualizar historial',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : _history.isEmpty
          ? const Center(child: Text('Todavía no tienes pedidos cerrados.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _history.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final order = _history[index];
                  final id = int.tryParse(order['id_pedido'].toString());
                  final status = order['estado']?.toString() ?? '—';
                  final type = order['tipo']?.toString() ?? 'Pedido';
                  final table = order['numero_mesa']?.toString();
                  return Card(
                    color: SipanTokens.surface,
                    child: ListTile(
                      leading: Icon(
                        status == 'PAGADO' ? Icons.check_circle : Icons.cancel,
                        color: status == 'PAGADO'
                            ? SipanTokens.statusReady
                            : SipanTokens.statusCancelled,
                      ),
                      title: Text('Pedido #${id ?? '—'} · $status'),
                      subtitle: Text(
                        [
                          if (type == 'SALON' && table != null) 'Mesa $table',
                          if (type != 'SALON') type,
                          'Fecha: ${order['fecha'] ?? '—'}',
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: id == null ? null : () => _openOrder(id),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
