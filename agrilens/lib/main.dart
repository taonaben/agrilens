import 'package:agrilens/app/auth/views/auth_page.dart';
import 'package:agrilens/shared/routes/routes.dart';
import 'package:agrilens/shared/theme/app_theme.dart';
import 'package:agrilens/shared/theme/theme_mode_controller.dart';
import 'package:agrilens/shared/utils/logs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

bool _supabaseReady = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    DevLogs.logWarning('Could not load .env file: $e');
  }
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
    try {
      await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
      _supabaseReady = true;
    } catch (e) {
      DevLogs.logWarning('Could not initialize Supabase Auth: $e');
    }
  }
  final container = ProviderContainer();
  final GoRouter router = createRouter(initialRoute: '/');
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: MyApp(router: router),
    ),
  );
}

class MyApp extends ConsumerWidget {
  final GoRouter router;
  const MyApp({super.key, required this.router});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode =
        ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.system;

    final client = _supabaseReady ? Supabase.instance.client : null;
    return StreamBuilder<AuthState>(
      stream: client?.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? client?.auth.currentSession;
        final app =
            session == null
                ? MaterialApp(
                  title: 'AgriLens',
                  theme: AppTheme.light(),
                  darkTheme: AppTheme.dark(),
                  themeMode: themeMode,
                  debugShowCheckedModeBanner: false,
                  home: AuthPage(supabaseReady: client != null),
                )
                : MaterialApp.router(
                  title: 'AgriLens',
                  theme: AppTheme.light(),
                  darkTheme: AppTheme.dark(),
                  themeMode: themeMode,
                  showPerformanceOverlay: false,
                  debugShowCheckedModeBanner: false,
                  routerConfig: router,
                );
        return app;
      },
    );
  }
}
