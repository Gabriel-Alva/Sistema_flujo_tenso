import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SavedCredentials {
  const SavedCredentials({required this.username, required this.password});

  final String username;
  final String password;
}

class SavedCredentialsStore {
  const SavedCredentialsStore(this._storage);

  static const _rememberKey = 'waiter_remember_credentials';
  static const _usernameKey = 'waiter_saved_username';
  static const _passwordKey = 'waiter_saved_password';

  final FlutterSecureStorage _storage;

  Future<SavedCredentials?> read() async {
    if (await _storage.read(key: _rememberKey) != 'true') return null;

    final username = await _storage.read(key: _usernameKey);
    final password = await _storage.read(key: _passwordKey);
    if (username == null || username.isEmpty || password == null) {
      await clear();
      return null;
    }

    return SavedCredentials(username: username, password: password);
  }

  Future<void> save(String username, String password) async {
    await _storage.write(key: _usernameKey, value: username);
    await _storage.write(key: _passwordKey, value: password);
    await _storage.write(key: _rememberKey, value: 'true');
  }

  Future<void> clear() async {
    await _storage.delete(key: _rememberKey);
    await _storage.delete(key: _passwordKey);
    await _storage.delete(key: _usernameKey);
  }
}
