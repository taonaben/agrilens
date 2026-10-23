import 'package:go_router/go_router.dart';
import 'package:agrilens/app/main/app.dart';

GoRouter createRouter({required String initialRoute}) {
  return GoRouter(
    initialLocation: initialRoute,
    routes: [
      GoRoute(path: "/", name: "app", builder: (context, state) => const App()),
    ],
  );
}
