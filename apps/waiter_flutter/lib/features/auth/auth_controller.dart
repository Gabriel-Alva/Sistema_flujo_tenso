import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../core/network/api_provider.dart';

class AuthState {
  const AuthState({this.token, this.nombre, this.loading = false, this.error});
  final String? token;
  final String? nombre;
  final bool loading;
  final String? error;
  bool get isLoggedIn => token != null;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    Future<void>.microtask(_restoreToken);
    return const AuthState();
  }

  Future<void> _restoreToken() async {
    try {
      final token = await ref.read(apiClientProvider).accessToken;
      if (state.loading || state.token != null || state.error != null) return;
      if (token != null && token.isNotEmpty) {
        state = AuthState(token: token);
      } else {
        state = const AuthState();
      }
    } catch (error) {
      if (!state.loading && state.token == null) {
        state = AuthState(error: 'No se pudo leer la sesión guardada: $error');
      }
    }
  }

  Future<void> login(String username, String password) async {
    state = const AuthState(loading: true);
    try {
      final api = ref.read(apiClientProvider);
      final res = await api.dio.post(
        '/auth/login',
        data: {'username': username, 'password': password, 'context': 'MESERO'},
      );
      final token = res.data['access_token'] as String;
      final refreshToken = res.data['refresh_token'] as String?;
      if (refreshToken == null || refreshToken.isEmpty) {
        throw const FormatException(
          'El API no devolvió el token de renovación para el cliente móvil.',
        );
      }
      await api.saveTokens(accessToken: token, refreshToken: refreshToken);
      final nombre =
          res.data['user']?['persona']?['nombres'] as String? ?? username;
      state = AuthState(token: token, nombre: nombre);
    } catch (error) {
      state = AuthState(error: _errorMessage(error));
    }
  }

  Future<void> logout() async {
    final previous = state;
    try {
      final api = ref.read(apiClientProvider);
      await api.dio.post('/auth/logout');
      await api.clearTokens();
      state = const AuthState();
    } catch (error) {
      state = AuthState(
        token: previous.token,
        nombre: previous.nombre,
        error: 'No se pudo cerrar sesión con el servidor: $error',
      );
    }
  }

  String _errorMessage(Object error) {
    if (error is DioException) {
      final body = error.response?.data;
      if (body is Map && body['message'] is String) {
        return body['message'] as String;
      }
      if (error.response == null) {
        return 'No se pudo conectar con el API en ${error.requestOptions.baseUrl}. '
            'Verifica que el backend esté activo, la dirección API_BASE sea accesible '
            'desde este dispositivo y la red/firewall permita el puerto 8000.';
      }
    }
    return 'No se pudo iniciar sesión: $error';
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
