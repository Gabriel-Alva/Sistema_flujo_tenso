import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../core/network/api_provider.dart';
import '../../core/theme/sipan_tokens.dart';
import '../auth/auth_controller.dart';
import '../auth/login_page.dart';
import '../auth/profile_page.dart';
import '../menu/menu_page.dart';
import '../orders/active_orders_page.dart';
import '../orders/delivery_order_page.dart';
import '../orders/order_history_page.dart';
import '../orders/order_tracking_page.dart';

class SalonPage extends ConsumerStatefulWidget {
  const SalonPage({super.key});

  @override
  ConsumerState<SalonPage> createState() => _SalonPageState();
}

class _SalonPageState extends ConsumerState<SalonPage> {
  List<dynamic> mesas = [];
  int? _currentUserId;
  String _waiterName = 'Mesero';
  String? error;
  bool loading = true;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
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
      loading = true;
      error = null;
    });
    try {
      final api = ref.read(apiClientProvider).dio;
      final responses = await Future.wait([
        api.get('/salon/mesas'),
        api.get('/auth/me'),
      ]);
      final profileResponse = Map<String, dynamic>.from(
        responses[1].data as Map,
      );
      final profile = profileResponse['data'] ?? profileResponse;
      final currentUserId = profile is Map
          ? int.tryParse(profile['id_usuario']?.toString() ?? '')
          : null;
      final persona = profile is Map ? profile['persona'] : null;
      final fullName = persona is Map
          ? [
                  persona['nombres']?.toString(),
                  persona['primer_apellido']?.toString(),
                ]
                .whereType<String>()
                .where((part) => part.trim().isNotEmpty)
                .join(' ')
          : '';
      if (!mounted) return;
      setState(() {
        mesas = responses[0].data as List<dynamic>;
        _currentUserId = currentUserId;
        _waiterName = fullName.isEmpty ? 'Mesero' : fullName.split(' ').first;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        this.error = _errorMessage(error);
        loading = false;
      });
    }
  }

  String _errorMessage(Object error) {
    if (error is DioException && error.response == null) {
      return 'No se pudo conectar con el API (${error.message ?? error.type.name}). '
          'Verifica la red y API_BASE.';
    }
    if (error is DioException && error.response?.data is Map) {
      final message = (error.response!.data as Map)['message'];
      if (message is String) return message;
    }
    return 'No se pudo cargar el salón: $error';
  }

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).logout();
    if (!mounted) return;
    final error = ref.read(authControllerProvider).error;
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  Future<void> _openTable(Map<String, dynamic> mesa) async {
    final orderId = int.tryParse(mesa['id_pedido']?.toString() ?? '');
    if (orderId != null) {
      final waiterId = int.tryParse(mesa['id_mesero']?.toString() ?? '');
      if (waiterId != null && waiterId == _currentUserId) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderTrackingPage(orderId: orderId),
          ),
        );
        if (mounted) _load();
      } else {
        final waiter = mesa['nombre_mesero']?.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              waiter == null || waiter.isEmpty
                  ? 'La mesa ya está ocupada por otro pedido.'
                  : 'La mesa está siendo atendida por $waiter.',
            ),
          ),
        );
      }
      return;
    }

    final status = _tableStatus(mesa);
    if (status != 'LIBRE') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('La mesa no está disponible ($status).')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MenuPage(
          idMesa: int.tryParse(mesa['id_mesa']?.toString() ?? ''),
          etiqueta: 'Mesa ${mesa['numero']} · ${mesa['zona'] ?? ''}',
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _openOrders() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ActiveOrdersPage()));
    if (mounted) _load();
  }

  void _openHistory() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const OrderHistoryPage()));
  }

  void _openDelivery() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const DeliveryOrderPage()));
  }

  void _openProfile() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ProfilePage()));
  }

  Color _statusColor(String estado) {
    switch (estado) {
      case 'OCUPADA':
        return const Color(0xFF7416C5);
      case 'LIMPIEZA':
        return const Color(0xFFEF6C00);
      case 'RESERVADA':
        return const Color(0xFF0875D1);
      case 'INACTIVA':
        return const Color(0xFF64748B);
      default:
        return const Color(0xFF078B45);
    }
  }

  String _tableStatus(Map<String, dynamic> mesa) {
    final active = mesa['activa'];
    if (active == false || active == 0 || active?.toString() == '0') {
      return 'INACTIVA';
    }
    return mesa['estado']?.toString() ?? 'LIBRE';
  }

  int _countStatus(String status) => mesas
      .whereType<Map<String, dynamic>>()
      .where((mesa) => _tableStatus(mesa) == status)
      .length;

  int? _occupiedMinutes(Map<String, dynamic> mesa) {
    final occupiedSince = mesa['ocupado_desde']?.toString();
    if (occupiedSince != null) {
      final startedAt = DateTime.tryParse(occupiedSince);
      if (startedAt != null) {
        return DateTime.now()
            .difference(startedAt.toLocal())
            .inMinutes
            .clamp(0, 1000000);
      }
    }
    return int.tryParse(mesa['minutos_ocupacion']?.toString() ?? '');
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF20B3A), Color(0xFFD8002E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 12, 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.white,
                foregroundColor: SipanTokens.brandPrimary,
                child: Text(
                  _waiterName.isEmpty ? 'M' : _waiterName[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hola, $_waiterName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 1),
                    const Text(
                      'Salón',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 27,
                        height: 1.05,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualizar salón',
                onPressed: loading ? null : _load,
                color: Colors.white,
                icon: const Icon(Icons.refresh_rounded, size: 27),
              ),
              PopupMenuButton<String>(
                tooltip: 'Más opciones',
                iconColor: Colors.white,
                iconSize: 29,
                onSelected: (value) {
                  switch (value) {
                    case 'orders':
                      _openOrders();
                    case 'history':
                      _openHistory();
                    case 'logout':
                      _logout();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'orders',
                    child: ListTile(
                      leading: Icon(Icons.receipt_long),
                      title: Text('Pedidos activos'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'history',
                    child: ListTile(
                      leading: Icon(Icons.history),
                      title: Text('Historial'),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'logout',
                    child: ListTile(
                      leading: Icon(Icons.logout),
                      title: Text('Cerrar sesión'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummary() {
    final counts = [
      ('Libres', _countStatus('LIBRE'), const Color(0xFF078B45)),
      ('Ocupadas', _countStatus('OCUPADA'), const Color(0xFF0875D1)),
      ('Reservadas', _countStatus('RESERVADA'), const Color(0xFF7416C5)),
      ('Limpieza', _countStatus('LIMPIEZA'), const Color(0xFFEF6C00)),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCE1E7)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C172033),
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
              const Expanded(
                child: Text(
                  'Resumen',
                  style: TextStyle(
                    color: Color(0xFF172033),
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${mesas.length} mesas',
                style: const TextStyle(
                  color: SipanTokens.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var index = 0; index < counts.length; index++) ...[
                  if (index > 0) const SizedBox(width: 8),
                  _buildStatusChip(
                    counts[index].$1,
                    counts[index].$2,
                    counts[index].$3,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            '$count $label',
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard(Map<String, dynamic> mesa) {
    final status = _tableStatus(mesa);
    final color = _statusColor(status);
    final minutes = _occupiedMinutes(mesa);
    final waiter = mesa['nombre_mesero']?.toString();
    final orderId = int.tryParse(mesa['id_pedido']?.toString() ?? '');
    final isOwnOrder =
        orderId != null &&
        int.tryParse(mesa['id_mesero']?.toString() ?? '') == _currentUserId;
    final isOccupied = status == 'OCUPADA';
    final canStart = status == 'LIBRE';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openTable(mesa),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFD8DEE6)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 37,
                alignment: Alignment.center,
                color: color,
                child: Text(
                  status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mesa ${mesa['numero'] ?? '—'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF172033),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(
                            Icons.person,
                            size: 17,
                            color: Color(0xFF334155),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              waiter?.isNotEmpty == true
                                  ? waiter!
                                  : canStart
                                  ? 'Sin mesero'
                                  : 'Atención no asignada',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF334155),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (isOccupied && minutes != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE7D9),
                            border: Border.all(color: const Color(0xFFFF8B52)),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'Tiempo de servicio',
                                style: TextStyle(
                                  color: Color(0xFFE34B13),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '$minutes min',
                                style: const TextStyle(
                                  color: Color(0xFFE34B13),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Text(
                          canStart
                              ? 'Capacidad ${mesa['capacidad'] ?? '—'}'
                              : 'Zona ${mesa['zona'] ?? 'Salón'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 12,
                          ),
                        ),
                      if (isOccupied && orderId != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Pedido #$orderId',
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Text(
                          isOwnOrder
                              ? 'ABRIR PEDIDO'
                              : canStart
                              ? 'INICIAR PEDIDO'
                              : isOccupied
                              ? 'EN ATENCIÓN'
                              : status,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: SipanTokens.brandPrimary,
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 66,
          child: Row(
            children: [
              _buildNavItem(
                Icons.table_restaurant,
                'Salón',
                selected: true,
                onTap: _load,
              ),
              _buildNavItem(
                Icons.shopping_bag_outlined,
                'Llevar',
                onTap: _openTakeout,
              ),
              _buildNavItem(
                Icons.delivery_dining,
                'Delivery',
                onTap: _openDelivery,
              ),
              _buildNavItem(
                Icons.person_outline,
                'Perfil',
                onTap: _openProfile,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    IconData icon,
    String label, {
    bool selected = false,
    required VoidCallback onTap,
  }) {
    final color = selected ? const Color(0xFFFFD000) : Colors.white;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTakeout() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const MenuPage(
          idMesa: null,
          etiqueta: 'Pedido para llevar',
          tipo: 'LLEVAR',
        ),
      ),
    );
    if (mounted) _load();
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_outlined,
              size: 44,
              color: SipanTokens.muted,
            ),
            const SizedBox(height: 12),
            Text(
              error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: SipanTokens.muted),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.table_restaurant, size: 48, color: SipanTokens.muted),
            SizedBox(height: 12),
            Text(
              'No hay mesas activas en el salón.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF334155),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F4F7),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: loading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: SipanTokens.brandPrimary,
                    ),
                  )
                : error != null
                ? _buildError()
                : mesas.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    color: SipanTokens.brandPrimary,
                    onRefresh: _load,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth < 600
                            ? 2
                            : constraints.maxWidth < 900
                            ? 3
                            : constraints.maxWidth < 1100
                            ? 4
                            : 5;
                        final cardWidth =
                            (constraints.maxWidth - 28 - (columns - 1) * 12) /
                            columns;
                        final cardAspectRatio = cardWidth < 195
                            ? 0.72
                            : cardWidth < 225
                            ? 0.82
                            : cardWidth < 260
                            ? 0.92
                            : 1.0;
                        return CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(child: _buildSummary()),
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                14,
                                16,
                                14,
                                18,
                              ),
                              sliver: SliverGrid(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: columns,
                                      mainAxisSpacing: 12,
                                      crossAxisSpacing: 12,
                                      childAspectRatio: cardAspectRatio,
                                    ),
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) => _buildTableCard(
                                    mesas[index] as Map<String, dynamic>,
                                  ),
                                  childCount: mesas.length,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }
}
