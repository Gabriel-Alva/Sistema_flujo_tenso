import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/api_provider.dart';
import '../../core/theme/sipan_tokens.dart';
import 'order_repository.dart';
import 'order_tracking_page.dart';

class ActiveOrdersPage extends ConsumerStatefulWidget {
  const ActiveOrdersPage({super.key});

  @override
  ConsumerState<ActiveOrdersPage> createState() => _ActiveOrdersPageState();
}

class _ActiveOrdersPageState extends ConsumerState<ActiveOrdersPage> {
  late final OrderRepository _orders;
  List<Map<String, dynamic>> _activeOrders = [];
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
      final orders = await _orders.activeOrders();
      if (!mounted) return;
      setState(() {
        _activeOrders = orders;
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
    return 'No se pudieron cargar los pedidos: $error';
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
        title: const Text('Pedidos activos'),
        actions: [
          IconButton(
            tooltip: 'Actualizar pedidos',
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
          : _activeOrders.isEmpty
          ? const Center(child: Text('No tienes pedidos activos.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _activeOrders.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final order = _activeOrders[index];
                  final id = int.tryParse(order['id_pedido'].toString());
                  final table = order['numero_mesa']?.toString();
                  final status = order['estado']?.toString() ?? 'ABIERTO';
                  return Card(
                    color: SipanTokens.surface,
                    child: ListTile(
                      leading: const Icon(
                        Icons.receipt_long,
                        color: SipanTokens.brandPrimary,
                      ),
                      title: Text('Pedido #${id ?? '—'} · $status'),
                      subtitle: Text(
                        [
                          if (table != null) 'Mesa $table',
                          'Comensales: ${order['num_comensales'] ?? '—'}',
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
