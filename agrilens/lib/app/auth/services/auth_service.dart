import 'package:agrilens/shared/api/api_client.dart';
import 'package:agrilens/app/auth/services/auth_session.dart';

class AuthService {
  const AuthService({required ApiClient api, required AuthSession session})
    : _api = api,
      _session = session;

  final ApiClient _api;
  final AuthSession _session;

  Future<void> signIn({required String email, required String password}) async {
    final response = await _api.postJson('/login', {
      'email': email,
      'password': password,
    }, requiresAuth: false);
    final token = response['access_token'];
    if (token is! String || token.trim().isEmpty) {
      throw const ApiRequestException(
        'The sign-in service returned an invalid access token.',
      );
    }
    await _session.saveAccessToken(token.trim());
  }

  Future<void> register({
    required String email,
    required String password,
  }) async {
    final credentials = {'email': email, 'password': password};
    await _api.postJson('/register', credentials, requiresAuth: false);
    await signIn(email: email, password: password);
  }
}
