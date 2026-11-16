import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/api_provider.dart';
import '../menu/menu_page.dart';
import 'order_repository.dart';

class DeliveryOrderPage extends ConsumerStatefulWidget {
  const DeliveryOrderPage({super.key});

  @override
  ConsumerState<DeliveryOrderPage> createState() => _DeliveryOrderPageState();
}

class _DeliveryOrderPageState extends ConsumerState<DeliveryOrderPage> {
  late final OrderRepository _orders;
  final _queryController = TextEditingController();
  List<Map<String, dynamic>> _customers = [];
  bool _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _orders = OrderRepository(
      ref.read(apiClientProvider),
      const FlutterSecureStorage(),
    );
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.length < 2) {
      setState(() {
        _error = 'Escribe al menos 2 caracteres para buscar un cliente.';
        _customers = [];
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final customers = await _orders.searchDeliveryCustomers(query);
      if (!mounted) return;
      setState(() {
        _customers = customers;
        _searching = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _errorMessage(error);
        _searching = false;
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
    return 'No se pudo buscar clientes: $error';
  }

  Future<void> _createOrder(Map<String, dynamic> customer) async {
    final customerId = int.tryParse(customer['id_cliente']?.toString() ?? '');
    final addressId = int.tryParse(customer['id_direccion']?.toString() ?? '');
    if (customerId == null || addressId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El cliente no tiene una dirección de entrega válida.'),
        ),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MenuPage(
          idMesa: null,
          tipo: 'DELIVERY',
          clienteDelivery: customer,
          etiqueta: 'Delivery · ${customer['nombre'] ?? 'Cliente'}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo pedido delivery')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _queryController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    labelText: 'Buscar cliente',
                    hintText: 'Nombre o teléfono',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      tooltip: 'Buscar',
                      onPressed: _searching ? null : _search,
                      icon: const Icon(Icons.arrow_forward),
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _searching
                ? const Center(child: CircularProgressIndicator())
                : _customers.isEmpty
                ? const Center(
                    child: Text('Busca un cliente con dirección registrada.'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: _customers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final customer = _customers[index];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_outline),
                          ),
                          title: Text(
                            customer['nombre']?.toString() ?? 'Cliente',
                          ),
                          subtitle: Text(
                            '${customer['telefono'] ?? 'Sin teléfono'}\n'
                            '${customer['linea_direccion'] ?? 'Sin dirección'}'
                            ' · ${customer['distrito'] ?? ''}',
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _createOrder(customer),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
