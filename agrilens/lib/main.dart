import 'package:agrilens/app/auth/services/auth_session.dart';
import 'package:agrilens/shared/api/api_client.dart';
import 'package:agrilens/shared/routes/routes.dart';
import 'package:agrilens/shared/theme/app_theme.dart';
import 'package:agrilens/shared/theme/theme_mode_controller.dart';
import 'package:agrilens/shared/utils/logs.dart';
import 'package:agrilens/app/chat/data/database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: '.env');
  } catch (error) {
    DevLogs.logWarning('Could not load .env file: $error');
  }

  await _discardLegacyLocalHistory();

  final authSession = AuthSession();
  await authSession.restore();
  final apiClient = ApiClient(
    accessTokenProvider: authSession.readAccessToken,
    unauthorizedHandler: authSession.signOut,
  );
  final router = createRouter(
    initialRoute: '/',
    authSession: authSession,
    apiClient: apiClient,
  );
  final container = ProviderContainer();
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: MyApp(router: router),
    ),
  );
}

Future<void> _discardLegacyLocalHistory() async {
  const migrationKey = 'server_chat_history_migration_complete_v1';
  try {
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool(migrationKey) == true) return;
    final database = AgriLensDatabase();
    try {
      final conversations = await database.getAllConversations();
      for (final conversation in conversations) {
        await database.deleteConversationWithCleanup(conversation.id);
      }
    } finally {
      await database.close();
    }
    await preferences.setBool(migrationKey, true);
  } catch (error) {
    DevLogs.logWarning('Could not clear legacy local chat history: $error');
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key, required this.router});

  final GoRouter router;

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
