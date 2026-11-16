import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/network/api_provider.dart';
import '../../core/theme/sipan_tokens.dart';
import '../../core/widgets/sipan_icon.dart';
import '../orders/order_repository.dart';

class MenuPage extends ConsumerStatefulWidget {
  const MenuPage({
    super.key,
    required this.idMesa,
    required this.etiqueta,
    this.tipo = 'SALON',
    this.idPedido,
    this.comensales,
    this.clienteDelivery,
  });

  final int? idMesa;
  final String etiqueta;
  final String tipo;
  final int? idPedido;
  final int? comensales;
  final Map<String, dynamic>? clienteDelivery;

  @override
  ConsumerState<MenuPage> createState() => _MenuPageState();
}

class _MenuPageState extends ConsumerState<MenuPage> {
  final _dinersController = TextEditingController(text: '1');
  final _generalNoteController = TextEditingController();
  final _searchController = TextEditingController();
  final Map<String, OrderLine> _cart = {};
  final Map<String, TextEditingController> _notes = {};
  late final OrderRepository _orders;
  List<dynamic> _products = [];
  List<dynamic> _modifiers = [];
  String _selectedCategory = 'Todos';
  bool _loading = true;
  bool _submitting = false;
  bool _syncing = false;
  int _pendingCount = 0;
  String? _loadError;
  String? _orderError;

  double get _cartTotal => _cart.values.fold<double>(
    0,
    (total, line) =>
        total +
        line.quantity *
            (line.unitPrice +
                line.modifiers.fold<double>(
                  0,
                  (sum, id) => sum + _modifierPrice(id),
                )),
  );

  @override
  void initState() {
    super.initState();
    if (widget.comensales != null && widget.comensales! > 0) {
      _dinersController.text = widget.comensales.toString();
    }
    _orders = OrderRepository(
      ref.read(apiClientProvider),
      const FlutterSecureStorage(),
    );
    _load();
  }

  @override
  void dispose() {
    _dinersController.dispose();
    _generalNoteController.dispose();
    _searchController.dispose();
    for (final controller in _notes.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final api = ref.read(apiClientProvider);
      final responses = await Future.wait([
        api.dio.get('/catalogo/productos'),
        api.dio.get('/catalogo/modificadores'),
      ]);
      final pending = await _orders.pendingCount();
      if (!mounted) return;
      setState(() {
        _products = responses[0].data as List<dynamic>;
        _modifiers = responses[1].data as List<dynamic>;
        _pendingCount = pending;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = _errorMessage(error);
        _loading = false;
      });
    }
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final body = error.response?.data;
      if (body is Map && body['message'] is String) {
        return body['message'] as String;
      }
      if (error.response == null) {
        return 'No se pudo conectar con el API. Verifica la red y API_BASE.';
      }
    }
    return 'Ocurrió un error: $error';
  }

  void _showToast(String message, {Color? color}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: color ?? SipanTokens.brandPrimaryDark,
          duration: const Duration(seconds: 3),
        ),
      );
  }

  void _addProduct(Map<String, dynamic> product) {
    final id = product['id_producto']?.toString();
    if (id == null || id.isEmpty) {
      setState(
        () => _orderError = 'El producto no tiene un identificador válido.',
      );
      return;
    }
    final variantId = int.tryParse(
      product['_selected_variant']?['id_variante']?.toString() ?? '',
    );
    final variant = product['_selected_variant'];
    final key = '$id:${variantId ?? 'base'}';
    final name = product['nombre']?.toString() ?? 'Producto';
    setState(() {
      final existing = _cart[key];
      if (existing != null) {
        existing.quantity++;
      } else {
        final unitPrice =
            double.tryParse(
              variant is Map
                  ? variant['precio']?.toString() ?? ''
                  : product['precio_actual']?.toString() ?? '',
            ) ??
            0;
        _cart[key] = OrderLine(
          productId: id,
          name: name,
          quantity: 1,
          variantId: variantId,
          variantName: variant is Map ? variant['nombre']?.toString() : null,
          unitPrice: unitPrice,
        );
        _notes[key] = TextEditingController();
      }
      _orderError = null;
    });
    _showToast('$name agregado a la comanda');
  }

  Future<void> _showProductDetails(Map<String, dynamic> product) async {
    final rawVariants = product['variantes'];
    final variants = rawVariants is List
        ? rawVariants
              .whereType<Map>()
              .map((variant) => Map<String, dynamic>.from(variant))
              .where((variant) => variant['activo'] != 0)
              .toList()
        : <Map<String, dynamic>>[];
    Map<String, dynamic>? selectedVariant = variants.isEmpty
        ? null
        : variants.first;
    final image = _productImage(product['imagen_url']?.toString());
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * .85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (image != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(
                        image.toString(),
                        width: double.infinity,
                        height: 190,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _imagePlaceholder(height: 190),
                      ),
                    )
                  else
                    _imagePlaceholder(height: 150),
                  const SizedBox(height: 16),
                  Text(
                    product['nombre']?.toString() ?? 'Producto',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    [
                          product['categoria']?.toString(),
                          product['tipo']?.toString(),
                          if (product['tiempo_prep_min'] != null)
                            '${product['tiempo_prep_min']} min de preparación',
                        ]
                        .whereType<String>()
                        .where((text) => text.isNotEmpty)
                        .join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    product['descripcion']?.toString().trim().isNotEmpty == true
                        ? product['descripcion'].toString()
                        : 'Sin descripción disponible.',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Precio: S/ ${selectedVariant?['precio'] ?? product['precio_actual'] ?? '—'}',
                    style: const TextStyle(
                      color: SipanTokens.brandPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (variants.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Elige una presentación',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    RadioGroup<int>(
                      groupValue: int.tryParse(
                        selectedVariant?['id_variante']?.toString() ?? '',
                      ),
                      onChanged: (value) => setSheetState(() {
                        selectedVariant = variants.firstWhere(
                          (item) =>
                              item['id_variante'].toString() ==
                              value.toString(),
                        );
                      }),
                      child: Column(
                        children: variants.map((variant) {
                          final id = int.tryParse(
                            variant['id_variante']?.toString() ?? '',
                          );
                          if (id == null) return const SizedBox.shrink();
                          return RadioListTile<int>(
                            contentPadding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            selected:
                                selectedVariant?['id_variante'].toString() ==
                                id.toString(),
                            value: id,
                            title: Text(
                              variant['nombre']?.toString() ?? 'Opción',
                            ),
                            subtitle: Text('S/ ${variant['precio'] ?? '—'}'),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, {
                      'variant': selectedVariant,
                    }),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Añadir a comanda'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (result != null && mounted) {
      _addProduct({...product, '_selected_variant': result['variant']});
    }
  }

  Uri? _productImage(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri?.hasScheme == true) return uri;
    final path = value.startsWith('/') ? value.substring(1) : value;
    return Uri.parse(ref.read(apiClientProvider).dio.options.baseUrl)
        .resolve('/$path');
  }

  Widget _imagePlaceholder({double height = 56, double? width}) => Container(
    width: width ?? (height == 56 ? 56 : double.infinity),
    height: height,
    decoration: BoxDecoration(
      color: SipanTokens.paper,
      borderRadius: BorderRadius.circular(12),
    ),
    alignment: Alignment.center,
    child: const Icon(Icons.restaurant, color: SipanTokens.brandGold, size: 32),
  );

  void _changeQuantity(String id, int delta) {
    setState(() {
      final line = _cart[id];
      if (line == null) return;
      line.quantity += delta;
      if (line.quantity < 1) {
        _cart.remove(id);
        _notes.remove(id)?.dispose();
      }
    });
  }

  Future<void> _editModifiers(OrderLine line) async {
    final selected = Set<int>.from(line.modifiers);
    final result = await showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Modificadores · ${line.name}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_modifiers.isEmpty)
                  const Text('El catálogo no ofrece modificadores.')
                else
                  ..._modifiers.map((item) {
                    final modifier = item as Map<String, dynamic>;
                    final id = int.tryParse(
                      modifier['id_modificador']?.toString() ?? '',
                    );
                    if (id == null) return const SizedBox.shrink();
                    return CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        modifier['nombre']?.toString() ?? 'Modificador',
                      ),
                      value: selected.contains(id),
                      onChanged: (enabled) => setSheetState(() {
                        if (enabled == true) {
                          selected.add(id);
                        } else {
                          selected.remove(id);
                        }
                      }),
                    );
                  }),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.pop(context, selected),
                  child: const Text('Aplicar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        line.modifiers
          ..clear()
          ..addAll(result);
      });
    }
  }

  Future<void> _submitOrder() async {
    final tableId = widget.idMesa;
    final diners = int.tryParse(_dinersController.text);
    final deliveryCustomer = widget.clienteDelivery;
    final isDelivery = widget.tipo == 'DELIVERY';
    if (!isDelivery && tableId == null) {
      setState(() => _orderError = 'No se recibió una mesa válida.');
      return;
    }
    if (!isDelivery && (diners == null || diners < 1)) {
      setState(
        () => _orderError = 'Indica un número de comensales mayor que cero.',
      );
      return;
    }
    if (isDelivery &&
        (deliveryCustomer == null ||
            deliveryCustomer['id_cliente'] == null ||
            deliveryCustomer['id_direccion'] == null)) {
      setState(
        () => _orderError = 'Selecciona un cliente con dirección válida.',
      );
      return;
    }
    if (_cart.isEmpty) {
      setState(() => _orderError = 'Agrega al menos un producto al pedido.');
      return;
    }
    final confirmed = await _previewOrder();
    if (confirmed != true || !mounted) return;
    setState(() {
      _submitting = true;
      _orderError = null;
    });
    try {
      for (final entry in _cart.entries) {
        entry.value.note = _notes[entry.key]?.text ?? '';
      }
      final result = isDelivery
          ? await _orders.createDeliveryOrder(
              customerId: int.parse(deliveryCustomer!['id_cliente'].toString()),
              addressId: int.parse(deliveryCustomer['id_direccion'].toString()),
              addressSnapshot: {
                'nombre_cliente':
                    deliveryCustomer['nombre']?.toString() ??
                    deliveryCustomer['nombre_cliente']?.toString() ??
                    '',
                'telefono': deliveryCustomer['telefono']?.toString() ?? '',
                'linea_direccion':
                    deliveryCustomer['linea_direccion']?.toString() ?? '',
                'distrito': deliveryCustomer['distrito']?.toString() ?? '',
              },
              items: _cart.values.toList(),
              notes: _generalNoteController.text,
              orderId: widget.idPedido,
            )
          : await _orders.createSalonOrder(
              tableId: tableId!,
              diners: diners!,
              items: _cart.values.toList(),
              orderId: widget.idPedido,
              notes: _generalNoteController.text,
            );
      final pending = await _orders.pendingCount();
      if (!mounted) return;
      setState(() {
        _cart.clear();
        for (final controller in _notes.values) {
          controller.dispose();
        }
        _notes.clear();
        _pendingCount = pending;
        _submitting = false;
      });
      _showToast(
        result.queued
            ? 'Sin conexión: pedido guardado para reintentar.'
            : 'Comanda enviada correctamente.',
        color: result.queued
            ? SipanTokens.statusPending
            : SipanTokens.statusReady,
      );
      if (!result.queued &&
          (widget.idPedido != null ||
              widget.tipo == 'DELIVERY' ||
              widget.idMesa != null)) {
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _orderError = _errorMessage(error);
        _submitting = false;
      });
    }
  }

  Future<bool?> _previewOrder() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Row(
          children: [
            Icon(Icons.receipt_long, color: SipanTokens.brandPrimary),
            SizedBox(width: 10),
            Expanded(child: Text('Revisar comanda')),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: ListView(
            shrinkWrap: true,
            children: [
              Text(
                widget.etiqueta,
                style: const TextStyle(
                  color: SipanTokens.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.tipo == 'DELIVERY' && widget.clienteDelivery != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Entrega: ${widget.clienteDelivery!['linea_direccion'] ?? ''}'
                    ' · ${widget.clienteDelivery!['distrito'] ?? ''}',
                  ),
                ),
              if (_generalNoteController.text.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Nota general: ${_generalNoteController.text.trim()}',
                  ),
                ),
              const Divider(),
              ..._cart.entries.map((entry) {
                final line = entry.value;
                final modifiers = line.modifiers.map(_modifierName).join(', ');
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${line.quantity} × ${line.name}'
                    '${line.variantName == null ? '' : ' · ${line.variantName}'}',
                  ),
                  subtitle:
                      [
                        if (modifiers.isNotEmpty) 'Extras: $modifiers',
                        if (_notes[entry.key]?.text.trim().isNotEmpty == true)
                          'Nota: ${_notes[entry.key]!.text.trim()}',
                      ].isEmpty
                      ? null
                      : Text(
                          [
                            if (modifiers.isNotEmpty) 'Extras: $modifiers',
                            if (_notes[entry.key]?.text.trim().isNotEmpty ==
                                true)
                              'Nota: ${_notes[entry.key]!.text.trim()}',
                          ].join('\n'),
                        ),
                  trailing: Text(
                    'S/ ${(line.quantity * (line.unitPrice + line.modifiers.fold<double>(0, (sum, id) => sum + _modifierPrice(id)))).toStringAsFixed(2)}',
                  ),
                );
              }),
              const Divider(),
              Text(
                'Total estimado: S/ ${_cartTotal.toStringAsFixed(2)}',
                textAlign: TextAlign.end,
                style: const TextStyle(
                  color: SipanTokens.brandPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'El total definitivo se confirma con la cuenta del sistema.',
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 12, color: SipanTokens.muted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Seguir editando'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.send_rounded),
            label: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  double _modifierPrice(int id) {
    for (final raw in _modifiers) {
      if (raw is Map && raw['id_modificador'].toString() == id.toString()) {
        return double.tryParse(raw['precio_extra']?.toString() ?? '') ?? 0;
      }
    }
    return 0;
  }

  String _modifierName(int id) {
    for (final raw in _modifiers) {
      if (raw is Map && raw['id_modificador'].toString() == id.toString()) {
        return raw['nombre']?.toString() ?? 'Modificador';
      }
    }
    return 'Modificador';
  }

  Future<void> _syncPending() async {
    setState(() => _syncing = true);
    try {
      final result = await _orders.syncPending();
      final pending = await _orders.pendingCount();
      if (!mounted) return;
      setState(() {
        _pendingCount = pending;
        _syncing = false;
      });
      final detail = result.errors.isEmpty ? '' : ' ${result.errors.join(' ')}';
      _showToast(
        'Enviados: ${result.sent}. Pendientes: $pending.$detail',
        color: result.errors.isEmpty
            ? SipanTokens.statusReady
            : SipanTokens.statusPending,
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _syncing = false);
      _showToast(
        'No se pudieron sincronizar pedidos: $error',
        color: SipanTokens.statusCancelled,
      );
    }
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final image = _productImage(product['imagen_url']?.toString());
    final category = product['categoria']?.toString() ?? 'Sin categoría';
    final description = product['descripcion']?.toString().trim() ?? '';
    final variants = product['variantes'];
    final variantCount = variants is List
        ? variants.whereType<Map>().where((item) => item['activo'] != 0).length
        : 0;
    final hasVariants = variantCount > 0;

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: SipanTokens.line),
      ),
      child: InkWell(
        onTap: () => _showProductDetails(product),
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: image == null
                    ? _imagePlaceholder(height: 84, width: 84)
                    : Image.network(
                        image.toString(),
                        width: 84,
                        height: 84,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _imagePlaceholder(height: 84, width: 84),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SipanTokens.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product['nombre']?.toString() ?? 'Producto',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: SipanTokens.ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: SipanTokens.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'S/ ${product['precio_actual'] ?? '—'}',
                          style: const TextStyle(
                            color: SipanTokens.brandPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (product['tiempo_prep_min'] != null)
                          Text(
                            '${product['tiempo_prep_min']} min',
                            style: const TextStyle(
                              color: SipanTokens.muted,
                              fontSize: 11,
                            ),
                          ),
                        if (hasVariants)
                          Text(
                            '$variantCount opciones',
                            style: const TextStyle(
                              color: SipanTokens.muted,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                tooltip: hasVariants
                    ? 'Elegir presentación'
                    : 'Agregar producto',
                onPressed: () => hasVariants
                    ? _showProductDetails(product)
                    : _addProduct(product),
                icon: Icon(
                  hasVariants ? Icons.tune_rounded : Icons.add_rounded,
                ),
                style: IconButton.styleFrom(
                  foregroundColor: SipanTokens.brandPrimary,
                  backgroundColor: SipanTokens.brandPrimary.withValues(
                    alpha: 0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCartLine(String key, OrderLine line) {
    final modifiersPrice = line.modifiers.fold<double>(
      0,
      (sum, id) => sum + _modifierPrice(id),
    );
    final lineTotal = (line.unitPrice + modifiersPrice) * line.quantity;

    return Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: SipanTokens.line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${line.name}${line.variantName == null ? '' : ' · ${line.variantName}'}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: SipanTokens.ink,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'S/ ${lineTotal.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: SipanTokens.brandPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: SipanTokens.paper,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Quitar uno',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _changeQuantity(key, -1),
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      Text(
                        '${line.quantity}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      IconButton(
                        tooltip: 'Agregar uno',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _changeQuantity(key, 1),
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _editModifiers(line),
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: Text(
                        line.modifiers.isEmpty
                            ? 'Extras'
                            : 'Extras ${line.modifiers.length}',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            TextField(
              controller: _notes[key],
              maxLength: 250,
              decoration: const InputDecoration(
                labelText: 'Nota para cocina',
                hintText: 'Ej. sin cebolla',
                prefixIcon: Icon(Icons.edit_note_rounded),
                isDense: true,
                counterText: '',
                filled: true,
                fillColor: SipanTokens.paper,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingNotice() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6E5),
        border: Border.all(color: const Color(0xFFF2D49A)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.cloud_upload_outlined,
            color: Color(0xFF9A6700),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$_pendingCount pedido(s) esperan conexión.',
              style: const TextStyle(
                color: Color(0xFF72500A),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _syncing ? null : _syncPending,
            child: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderError() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        border: Border.all(color: const Color(0xFFF2C5C5)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: SipanTokens.statusCancelled,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _orderError!,
              style: const TextStyle(color: Color(0xFF8F1D1D), fontSize: 13),
            ),
          ),
          IconButton(
            tooltip: 'Cerrar aviso',
            onPressed: () => setState(() => _orderError = null),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildCartFooter() {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: SipanTokens.line),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 12,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_cart.values.fold<int>(0, (sum, line) => sum + line.quantity)} productos',
                    style: const TextStyle(
                      color: SipanTokens.muted,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    'S/ ${_cartTotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: SipanTokens.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: _submitting || _cart.isEmpty ? null : _submitOrder,
              icon: _submitting
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.receipt_long_rounded, size: 19),
              label: Text(_submitting ? 'Enviando…' : 'Revisar pedido'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 46),
                padding: const EdgeInsets.symmetric(horizontal: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final searchTerm = _searchController.text.trim().toLowerCase();
    final categories =
        _products
            .whereType<Map<String, dynamic>>()
            .map((product) => product['categoria']?.toString().trim() ?? '')
            .where((category) => category.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final categoryFilters = ['Todos', ...categories];
    final visibleProducts = _products.where((item) {
      final product = item as Map<String, dynamic>;
      final nameMatches =
          searchTerm.isEmpty ||
          product['nombre']?.toString().toLowerCase().contains(searchTerm) ==
              true ||
          product['categoria']?.toString().toLowerCase().contains(searchTerm) ==
              true;
      final categoryMatches =
          _selectedCategory == 'Todos' ||
          product['categoria']?.toString() == _selectedCategory;
      return nameMatches && categoryMatches;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        title: Row(
          children: [
            const SipanIcon('catalog', color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.idPedido == null
                    ? widget.etiqueta
                    : 'Agregar ronda · ${widget.etiqueta}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Actualizar catálogo',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: SipanTokens.brandPrimary),
            )
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      color: SipanTokens.muted,
                      size: 42,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: SipanTokens.muted),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Volver a intentar'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                if (_pendingCount > 0)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                    child: _buildPendingNotice(),
                  ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 16, 14, 20),
                    children: [
                      if (widget.tipo == 'SALON')
                        Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: SipanTokens.line),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TextField(
                            controller: _dinersController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Comensales',
                              prefixIcon: Icon(Icons.people_outline_rounded),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: SipanTokens.line),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: 'Buscar platos o categorías',
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: searchTerm.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: 'Limpiar búsqueda',
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 17),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Categorías',
                              style: TextStyle(
                                color: SipanTokens.ink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${visibleProducts.length} productos',
                            style: const TextStyle(
                              color: SipanTokens.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      SizedBox(
                        height: 39,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: categoryFilters.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final category = categoryFilters[index];
                            final selected = category == _selectedCategory;
                            return ChoiceChip(
                              label: Text(category),
                              selected: selected,
                              showCheckmark: false,
                              onSelected: (_) =>
                                  setState(() => _selectedCategory = category),
                              backgroundColor: Colors.white,
                              selectedColor: SipanTokens.brandPrimary,
                              side: BorderSide(
                                color: selected
                                    ? SipanTokens.brandPrimary
                                    : SipanTokens.line,
                              ),
                              labelStyle: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : SipanTokens.ink,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 17),
                      Text(
                        widget.tipo == 'DELIVERY'
                            ? 'Catálogo para delivery'
                            : 'Elige tus productos',
                        style: const TextStyle(
                          color: SipanTokens.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (visibleProducts.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 26,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: SipanTokens.line),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Column(
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                color: SipanTokens.muted,
                                size: 34,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'No encontramos productos con esos filtros.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: SipanTokens.muted),
                              ),
                            ],
                          ),
                        ),
                      ...visibleProducts.map((item) {
                        final product = item as Map<String, dynamic>;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildProductCard(product),
                        );
                      }),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Tu comanda',
                              style: TextStyle(
                                color: SipanTokens.ink,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            '${_cart.length} líneas',
                            style: const TextStyle(
                              color: SipanTokens.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_cart.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 18,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: SipanTokens.line),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.shopping_basket_outlined,
                                color: SipanTokens.muted,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Agrega productos y aparecerán aquí.',
                                  style: TextStyle(color: SipanTokens.muted),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ..._cart.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildCartLine(entry.key, entry.value),
                        );
                      }),
                      if (_cart.isNotEmpty && widget.idPedido == null)
                        Container(
                          margin: const EdgeInsets.only(top: 4),
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: SipanTokens.line),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: TextField(
                            controller: _generalNoteController,
                            maxLength: 2000,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Nota general (opcional)',
                              hintText: 'Indicaciones para toda la comanda',
                              prefixIcon: Icon(Icons.notes_rounded),
                              alignLabelWithHint: true,
                              border: InputBorder.none,
                              counterText: '',
                            ),
                          ),
                        ),
                      if (_orderError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: _buildOrderError(),
                        ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _loadError == null && !_loading
          ? _buildCartFooter()
          : null,
    );
  }
}
