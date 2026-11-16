import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waiter_flutter/core/config/env_config.dart';

void main() {
  test('rewrites Android emulator API host for Edge', () {
    expect(
      EnvConfig.resolveApiBase(
        configured: 'http://10.0.2.2:8000/api/v1',
        isWeb: true,
        platform: TargetPlatform.windows,
      ),
      'http://127.0.0.1:8000/api/v1',
    );
  });

  test('keeps emulator host for Android and defaults per target', () {
    expect(
      EnvConfig.resolveApiBase(
        configured: '',
        isWeb: false,
        platform: TargetPlatform.android,
      ),
      'http://10.0.2.2:8000/api/v1',
    );
    expect(
      EnvConfig.resolveApiBase(
        configured: '',
        isWeb: true,
        platform: TargetPlatform.windows,
      ),
      'http://127.0.0.1:8000/api/v1',
    );
  });
}
