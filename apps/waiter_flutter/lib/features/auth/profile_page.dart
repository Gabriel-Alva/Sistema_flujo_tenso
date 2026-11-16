import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/api_provider.dart';
import '../../core/theme/sipan_tokens.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(apiClientProvider).dio.get('/auth/me');
      final body = Map<String, dynamic>.from(response.data as Map);
      final user = body['data'] ?? body;
      if (user is! Map) {
        throw const FormatException('El API devolvió un perfil no válido.');
      }
      if (!mounted) return;
      setState(() {
        _profile = Map<String, dynamic>.from(user);
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
    return 'No se pudo cargar el perfil: $error';
  }

  @override
  Widget build(BuildContext context) {
    final person = _profile?['persona'];
    final name = person is Map
        ? [
            person['nombres'],
            person['primer_apellido'],
          ].whereType<String>().where((part) => part.isNotEmpty).join(' ')
        : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi perfil'),
        actions: [
          IconButton(
            tooltip: 'Actualizar perfil',
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
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  margin: const EdgeInsets.all(20),
                  color: SipanTokens.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircleAvatar(
                          radius: 42,
                          backgroundColor: SipanTokens.brandPrimary,
                          child: Icon(
                            Icons.person,
                            size: 44,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          name.isEmpty ? 'Mesero' : name,
                          style: Theme.of(context).textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        _ProfileRow(
                          icon: Icons.badge_outlined,
                          label: 'Usuario',
                          value: _profile?['username']?.toString() ?? '—',
                        ),
                        _ProfileRow(
                          icon: Icons.work_outline,
                          label: 'Perfil activo',
                          value: _profile?['rol']?.toString() ?? 'MESERO',
                        ),
                        if (_profile?['id_estacion'] != null)
                          _ProfileRow(
                            icon: Icons.restaurant,
                            label: 'Estación',
                            value: _profile!['id_estacion'].toString(),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: SipanTokens.brandPrimary),
    title: Text(label),
    subtitle: Text(value),
  );
}
