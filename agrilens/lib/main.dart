import 'package:agrilens/shared/routes/routes.dart';
import 'package:agrilens/shared/theme/app_theme.dart';
import 'package:agrilens/shared/theme/theme_mode_controller.dart';
import 'package:agrilens/shared/utils/logs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    DevLogs.logWarning('Could not load .env file: $e');
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

    return MaterialApp.router(
      title: 'AgriLens',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      showPerformanceOverlay: false,
      debugShowCheckedModeBanner: false,
      routerConfig: router,
    );
  }
}
