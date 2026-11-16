import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/env_config.dart';

class ApiClient {
  ApiClient._(this._storage) {
    dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.apiBase,
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 20),
        headers: const {'X-Client-Type': 'mobile'},
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
            options.extra[_accessTokenUsedKey] = token;
          } else {
            options.headers.remove('Authorization');
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode != 401 ||
              _isAuthRequest(error.requestOptions.path)) {
            handler.next(error);
            return;
          }

          final options = error.requestOptions;
          if (options.extra[_retriedKey] == true) {
            try {
              await clearTokens();
            } catch (storageError) {
              handler.reject(
                DioException(
                  requestOptions: options,
                  response: error.response,
                  type: error.type,
                  error: storageError,
                  message:
                      'Could not clear expired saved tokens: $storageError',
                ),
              );
              return;
            }
            handler.next(error);
            return;
          }

          String refreshedToken;
          try {
            final failedToken = options.extra[_accessTokenUsedKey] as String?;
            final currentToken = await accessToken;
            refreshedToken = currentToken != null && currentToken != failedToken
                ? currentToken
                : await _refreshAccessToken(failedToken);
          } catch (refreshError) {
            final isNetworkFailure =
                refreshError is DioException && refreshError.response == null;
            if (!isNetworkFailure) {
              try {
                await clearTokens();
              } catch (storageError) {
                handler.reject(
                  DioException(
                    requestOptions: options,
                    error: storageError,
                    message:
                        'Could not clear invalid saved tokens: $storageError',
                  ),
                );
                return;
              }
            }
            handler.reject(
              refreshError is DioException
                  ? refreshError
                  : DioException(
                      requestOptions: options,
                      error: refreshError,
                      message:
                          'Could not refresh the mobile session: $refreshError',
                    ),
            );
            return;
          }

          options.extra[_retriedKey] = true;
          options.headers['Authorization'] = 'Bearer $refreshedToken';
          try {
            final response = await dio.fetch<dynamic>(options);
            handler.resolve(response);
          } on DioException catch (retryError) {
            handler.reject(retryError);
          }
        },
      ),
    );
  }

  static const _accessTokenUsedKey = 'waiter_access_token_used';
  static const _retriedKey = 'waiter_auth_retry';

  static final ApiClient instance = ApiClient._(const FlutterSecureStorage());

  final FlutterSecureStorage _storage;
  late final Dio dio;
  Future<String>? _refreshInProgress;

  Future<String?> get accessToken => _storage.read(key: 'access_token');

  Future<String?> get refreshToken => _storage.read(key: 'refresh_token');

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      await _storage.write(key: 'refresh_token', value: refreshToken);
      await _storage.write(key: 'access_token', value: accessToken);
    } catch (error) {
      try {
        await clearTokens();
      } catch (cleanupError) {
        throw StateError(
          'Could not save or clean up session tokens: $cleanupError',
        );
      }
      rethrow;
    }
  }

  Future<void> clearTokens() async {
    await Future.wait<void>([
      _storage.delete(key: 'access_token'),
      _storage.delete(key: 'refresh_token'),
    ]);
  }

  Future<String> _refreshAccessToken(String? failedToken) {
    final running = _refreshInProgress;
    if (running != null) return running;
    final completer = Completer<String>();
    final refresh = completer.future;
    _refreshInProgress = refresh;
    () async {
      try {
        final currentToken = await accessToken;
        final token = currentToken != null && currentToken != failedToken
            ? currentToken
            : await _performRefresh();
        completer.complete(token);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        if (identical(_refreshInProgress, refresh)) {
          _refreshInProgress = null;
        }
      }
    }();
    return refresh;
  }

  Future<String> _performRefresh() async {
    final savedRefreshToken = await refreshToken;
    if (savedRefreshToken == null || savedRefreshToken.isEmpty) {
      throw StateError('No mobile refresh token is saved.');
    }
    final response = await dio.post<Map<String, dynamic>>(
      '/auth/refresh',
      data: {'refresh_token': savedRefreshToken},
    );
    final access = response.data?['access_token'];
    final refresh = response.data?['refresh_token'];
    if (access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty) {
      throw const FormatException('The API returned incomplete mobile tokens.');
    }
    await saveTokens(accessToken: access, refreshToken: refresh);
    return access;
  }

  bool _isAuthRequest(String path) {
    final normalized = path.startsWith('/') ? path.substring(1) : path;
    return normalized == 'auth/login' || normalized == 'auth/refresh';
  }
}
