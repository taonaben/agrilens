import 'package:go_router/go_router.dart';
import 'package:agrilens/app/main/app.dart';
import 'package:agrilens/app/auth/services/auth_service.dart';
import 'package:agrilens/app/auth/services/auth_session.dart';
import 'package:agrilens/app/auth/views/auth_page.dart';
import 'package:agrilens/shared/api/api_client.dart';

GoRouter createRouter({
  required String initialRoute,
  required AuthSession authSession,
  required ApiClient apiClient,
}) {
  final authService = AuthService(api: apiClient, session: authSession);
  return GoRouter(
    initialLocation: initialRoute,
    refreshListenable: authSession,
    redirect: (context, state) {
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';
      if (!authSession.isAuthenticated && !isAuthRoute) return '/login';
      if (authSession.isAuthenticated && isAuthRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'app',
        builder:
            (context, state) =>
                App(apiClient: apiClient, authSession: authSession),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder:
            (context, state) =>
                AuthPage(authService: authService, isRegister: false),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder:
            (context, state) =>
                AuthPage(authService: authService, isRegister: true),
      ),
    ],
  );
}
