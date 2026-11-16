import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/theme/sipan_tokens.dart';
import '../../core/widgets/sipan_icon.dart';
import '../salon/salon_page.dart';
import 'auth_controller.dart';
import 'saved_credentials_store.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final user = TextEditingController();
  final pass = TextEditingController();
  late final SavedCredentialsStore _credentialsStore;
  bool _showPassword = false;
  bool _rememberCredentials = false;
  bool _credentialsLoading = true;
  bool _deferNavigation = false;
  bool _navigating = false;
  String? _credentialNotice;

  @override
  void initState() {
    super.initState();
    _credentialsStore = const SavedCredentialsStore(FlutterSecureStorage());
    _loadSavedCredentials();
  }

  @override
  void dispose() {
    user.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final saved = await _credentialsStore.read();
      if (!mounted) return;
      setState(() {
        if (saved != null) {
          user.text = saved.username;
          pass.text = saved.password;
          _rememberCredentials = true;
        }
        _credentialsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _credentialsLoading = false;
        _credentialNotice = 'No se pudieron leer los datos guardados. Puedes iniciar sesión manualmente.';
      });
    }
  }

  Future<void> _setRememberCredentials(bool remember) async {
    if (!remember) {
      try {
        await _credentialsStore.clear();
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _credentialNotice = 'No fue posible borrar las credenciales guardadas. Inténtalo nuevamente.';
        });
        return;
      }
    }
    if (!mounted) return;
    setState(() {
      _rememberCredentials = remember;
      _credentialNotice = null;
    });
  }

  Future<void> _submitLogin() async {
    if (_credentialsLoading || ref.read(authControllerProvider).loading) return;
    if (user.text.trim().isEmpty || pass.text.isEmpty) {
      setState(() {
        _credentialNotice = 'Ingresa tu usuario y contraseña para continuar.';
      });
      return;
    }

    setState(() {
      _deferNavigation = true;
      _credentialNotice = null;
    });
    await ref
        .read(authControllerProvider.notifier)
        .login(user.text.trim(), pass.text);
    if (!mounted) return;
    if (!ref.read(authControllerProvider).isLoggedIn) {
      setState(() => _deferNavigation = false);
      return;
    }

    String? storageWarning;
    try {
      if (_rememberCredentials) {
        await _credentialsStore.save(user.text.trim(), pass.text);
      } else {
        await _credentialsStore.clear();
      }
    } catch (error) {
      storageWarning = _rememberCredentials
          ? 'Sesión iniciada, pero no se pudo guardar la contraseña de forma segura.'
          : 'Sesión iniciada, pero no se pudieron borrar los datos guardados.';
    }
    if (!mounted) return;
    if (storageWarning != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF8A5A00),
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(child: Text(storageWarning)),
            ],
          ),
        ),
      );
    }
    setState(() => _deferNavigation = false);
    _openSalon();
  }

  void _openSalon() {
    if (!mounted || _navigating) return;
    _navigating = true;
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const SalonPage()));
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    ref.listen(authControllerProvider, (prev, next) {
      if (next.isLoggedIn && !_deferNavigation) _openSalon();
    });

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              SipanTokens.brandPrimaryDark,
              SipanTokens.brandPrimary,
              Color(0xFF3A0D0D),
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                color: Colors.white,
                elevation: 12,
                shadowColor: const Color(0x55000000),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: SipanTokens.brandGoldSoft),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset(
                          'assets/images/logo.jpg',
                          width: 112,
                          height: 112,
                          fit: BoxFit.cover,
                          semanticLabel: 'Logo de Chifa Sipán',
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Meseros',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Text(
                        'Chifa Sipán',
                        style: TextStyle(
                          color: SipanTokens.muted,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: user,
                        enabled: !auth.loading && !_credentialsLoading,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'Usuario',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12),
                            child: SipanIcon('user', color: SipanTokens.muted),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: pass,
                        enabled: !auth.loading && !_credentialsLoading,
                        obscureText: !_showPassword,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submitLogin(),
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.all(12),
                            child: SipanIcon('lock', color: SipanTokens.muted),
                          ),
                          suffixIcon: IconButton(
                            tooltip: _showPassword
                                ? 'Ocultar contraseña'
                                : 'Mostrar contraseña',
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: SipanTokens.muted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      CheckboxListTile(
                        value: _rememberCredentials,
                        onChanged: auth.loading || _credentialsLoading
                            ? null
                            : (value) =>
                                  _setRememberCredentials(value ?? false),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        dense: true,
                        activeColor: SipanTokens.brandPrimary,
                        title: const Text(
                          'Recordarme en este dispositivo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text(
                          'Usuario y contraseña se guardan cifrados y solo si lo activas.',
                          style: TextStyle(
                            color: SipanTokens.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      if (auth.error != null) ...[
                        const SizedBox(height: 8),
                        _LoginNotice(message: auth.error!, isError: true),
                      ],
                      if (_credentialNotice != null) ...[
                        const SizedBox(height: 8),
                        _LoginNotice(
                          message: _credentialNotice!,
                          isError: false,
                        ),
                      ],
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: auth.loading || _credentialsLoading
                            ? null
                            : _submitLogin,
                        icon: auth.loading || _credentialsLoading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.login_rounded),
                        label: Text(
                          _credentialsLoading
                              ? 'Cargando…'
                              : auth.loading
                              ? 'Ingresando…'
                              : 'Iniciar sesión',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginNotice extends StatelessWidget {
  const _LoginNotice({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? SipanTokens.statusCancelled
        : const Color(0xFF8A5A00);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border.all(color: color.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.info_outline_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: color, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
