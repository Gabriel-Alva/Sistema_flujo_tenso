import 'package:flutter/foundation.dart';

class EnvConfig {
  static const _configuredApiBase = String.fromEnvironment('API_BASE');

  static String get apiBase => resolveApiBase(
    configured: _configuredApiBase,
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
  );

  static String resolveApiBase({
    required String configured,
    required bool isWeb,
    required TargetPlatform platform,
  }) {
    final value = configured.trim();
    if (value.isNotEmpty) {
      final uri = Uri.tryParse(value);
      if ((isWeb || platform == TargetPlatform.windows) &&
          uri?.host == '10.0.2.2') {
        return uri!.replace(host: '127.0.0.1').toString();
      }
      return value;
    }

    if (!isWeb && platform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://127.0.0.1:8000/api/v1';
  }
}
