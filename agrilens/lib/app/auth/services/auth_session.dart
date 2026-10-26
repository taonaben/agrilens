import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class AuthTokenStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class _SecureAuthTokenStorage implements AuthTokenStorage {
  const _SecureAuthTokenStorage();

  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class AuthSession extends ChangeNotifier {
  AuthSession({AuthTokenStorage? storage})
    : _storage = storage ?? const _SecureAuthTokenStorage();

  static const tokenKey = 'access_token';

  final AuthTokenStorage _storage;
  String? _accessToken;
  bool _ready = false;

  bool get isReady => _ready;
  bool get isAuthenticated => _accessToken?.isNotEmpty ?? false;

  Future<String?> readAccessToken() async {
    if (_ready) return _accessToken;
    final token = await _storage.read(tokenKey);
    _accessToken = token?.isNotEmpty == true ? token : null;
    _ready = true;
    return _accessToken;
  }

  Future<void> restore() async {
    try {
      await readAccessToken();
    } catch (_) {
      _accessToken = null;
      _ready = true;
    }
    notifyListeners();
  }

  Future<void> saveAccessToken(String token) async {
    await _storage.write(tokenKey, token);
    _accessToken = token;
    _ready = true;
    notifyListeners();
  }

  Future<void> signOut() async {
    _accessToken = null;
    _ready = true;
    notifyListeners();
    await _storage.delete(tokenKey);
  }
}
