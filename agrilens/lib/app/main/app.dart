import 'package:agrilens/app/chat/data/conversation_repository.dart';
import 'package:agrilens/app/chat/data/database.dart';
import 'package:agrilens/app/chat/data/message_repository.dart';
import 'package:agrilens/app/chat/data/prediction_repository.dart';
import 'package:agrilens/app/chat/models/conversation.dart' as model;
import 'package:agrilens/app/chat/services/diagnosis_pipeline.dart';
import 'package:agrilens/shared/api/api_client.dart';
import 'package:agrilens/shared/services/backend_diagnosis_service.dart';
import 'package:agrilens/shared/services/backend_llm_service.dart';
import 'package:agrilens/app/chat/views/chat_page.dart';
import 'package:agrilens/shared/theme/app_colors.dart';
import 'package:agrilens/shared/utils/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:gap/gap.dart';
import 'package:sidebarx/sidebarx.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _Destination {
  const _Destination({
    required this.title,
    required this.icon,
    required this.pageLabel,
    this.conversationId,
  });

  final String title;
  final IconData icon;
  final String pageLabel;
  final String? conversationId;
}

const _mainPages = <_Destination>[
  _Destination(
    title: 'Chat',
    icon: SolarIconsOutline.chatRound,
    pageLabel: 'Chat page',
  ),
  _Destination(
    title: 'Store',
    icon: SolarIconsOutline.shop,
    pageLabel: 'Store page',
  ),
  _Destination(
    title: 'Weather',
    icon: SolarIconsOutline.cloudSun,
    pageLabel: 'Weather page',
  ),
];

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final _sidebarController = SidebarXController(
    selectedIndex: 0,
    extended: true,
  );
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  late final AgriLensDatabase _database;
  late final ConversationRepository _conversationRepo;
  late final MessageRepository _messageRepo;
  late final PredictionRepository _predictionRepo;
  late final BackendDiagnosisService _diagnosisService;
  late final BackendLlmService _llmService;
  late final DiagnosisPipeline _pipeline;

  bool _initializing = true;
  String? _initializationError;
  String? _serviceWarning;

  List<model.Conversation> _conversations = const [];
  String? _activeConversationId;

  @override
  void initState() {
    super.initState();
    _database = AgriLensDatabase();
    _conversationRepo = ConversationRepository(_database);
    _messageRepo = MessageRepository(_database);
    _predictionRepo = PredictionRepository(_database);
    final api = BackendApiClient.ApiClient(
      accessTokenProvider:
          () async => Supabase.instance.client.auth.currentSession?.accessToken,
      baseUrl: dotenv.env['API_BASE_URL'],
    );
    _diagnosisService = BackendDiagnosisService(api);
    _llmService = BackendLlmService(api);
    _pipeline = DiagnosisPipeline(
      diagnosisService: _diagnosisService,
      llmService: _llmService,
      conversationRepo: _conversationRepo,
      messageRepo: _messageRepo,
      predictionRepo: _predictionRepo,
    );
    _bootstrap();
  }

  @override
  void dispose() {
    _sidebarController.dispose();
    _diagnosisService.dispose();
    _llmService.dispose();
    _database.close();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _initializing = true;
      _initializationError = null;
      _serviceWarning = null;
    });

    try {
      await _diagnosisService.load();
      await _llmService.load();
      if (!_diagnosisService.isConfigured) {
        _serviceWarning =
            'The FastAPI server URL is missing or must use HTTPS. Configure API_BASE_URL.';
      }

      await _reloadConversations();
      if (_conversations.isEmpty) {
        await _createAndSelectConversation();
      } else {
        _activeConversationId ??= _conversations.first.id;
      }
    } catch (e) {
      _initializationError = 'Could not initialize diagnosis services: $e';
    } finally {
      if (mounted) {
        setState(() {
          _initializing = false;
        });
      }
    }
  }

  Future<void> _reloadConversations() async {
    final conversations = await _conversationRepo.getAllConversations();
    if (!mounted) return;
    setState(() {
      _conversations = conversations;
      if (_activeConversationId != null &&
          !_conversations.any((c) => c.id == _activeConversationId)) {
        _activeConversationId =
            _conversations.isEmpty ? null : _conversations.first.id;
      }
      _activeConversationId ??=
          _conversations.isEmpty ? null : _conversations.first.id;
    });
  }

  Future<String> _createAndSelectConversation() async {
    final now = DateTime.now();
    final title =
        'Conversation ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final conv = await _conversationRepo.createConversation(title: title);
    await _reloadConversations();
    if (!mounted) return conv.id;
    setState(() {
      _activeConversationId = conv.id;
      _sidebarController.selectIndex(0);
    });
    return conv.id;
  }

  List<_Destination> get _historyDestinations {
    return _conversations
        .map(
          (c) => _Destination(
            title: c.title,
            icon: SolarIconsOutline.chatLine,
            pageLabel: c.title,
            conversationId: c.id,
          ),
        )
        .toList(growable: false);
  }

  int get _settingsIndex => _mainPages.length + _historyDestinations.length;

  void _select(int index, {required bool isDrawer}) {
    final historyStart = _mainPages.length;
    final historyEnd = historyStart + _historyDestinations.length;

    if (index >= historyStart && index < historyEnd) {
      final dest = _historyDestinations[index - historyStart];
      if (dest.conversationId != null) {
        _activeConversationId = dest.conversationId;
      }
    }

    _sidebarController.selectIndex(index);
    if (isDrawer) Navigator.of(context).pop();
    if (mounted) setState(() {});
  }

  Future<void> _handleSidebarNewChat({required bool isDrawer}) async {
    if (_initializing) return;
    await _createAndSelectConversation();
    if (isDrawer && mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _buildMainContent({
    required int selectedIndex,
    required String pageLabel,
  }) {
    if (_initializing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_initializationError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_initializationError!, textAlign: TextAlign.center),
              const Gap(AppConstants.gapMedium),
              FilledButton(
                onPressed: _bootstrap,
                child: const Text('Retry initialization'),
              ),
            ],
          ),
        ),
      );
    }

    final isChatTab = selectedIndex == 0;
    final isHistoryTab =
        selectedIndex >= _mainPages.length && selectedIndex < _settingsIndex;
    if (isChatTab || isHistoryTab) {
      final activeId =
          _activeConversationId ??
          (_conversations.isNotEmpty ? _conversations.first.id : null);
      if (activeId == null) {
        return Center(
          child: FilledButton(
            onPressed: _createAndSelectConversation,
            child: const Text('Start conversation'),
          ),
        );
      }
      return ChatPage(
        pipeline: _pipeline,
        messageRepository: _messageRepo,
        predictionRepository: _predictionRepo,
        conversationId: activeId,
        onCreateConversation: _createAndSelectConversation,
        onConversationChanged: _reloadConversations,
        serviceWarning: _serviceWarning,
      );
    }

    if (pageLabel == 'Settings page') {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.paddingLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Account',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(Supabase.instance.client.auth.currentUser?.email ?? ''),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Supabase.instance.client.auth.signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Center(
      child: Text(pageLabel, style: Theme.of(context).textTheme.headlineMedium),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final isWide = MediaQuery.sizeOf(context).width >= 700;
    final historyDestinations = _historyDestinations;
    final destinations = [..._mainPages, ...historyDestinations];

    if (_sidebarController.selectedIndex > _settingsIndex) {
      _sidebarController.selectIndex(0);
    }

    return AnimatedBuilder(
      animation: _sidebarController,
      builder: (context, _) {
        final selected = _sidebarController.selectedIndex;
        final title =
            selected == _settingsIndex
                ? 'Settings'
                : selected < destinations.length
                ? destinations[selected].title
                : 'Chat';
        final pageLabel =
            selected == _settingsIndex
                ? 'Settings page'
                : selected < destinations.length
                ? destinations[selected].pageLabel
                : 'Chat page';

        return Scaffold(
          key: _scaffoldKey,
          drawer:
              isWide
                  ? null
                  : Drawer(
                    width: MediaQuery.sizeOf(context).width * 0.7,
                    child: SafeArea(
                      child: _buildSidebar(
                        context,
                        destinations,
                        isDrawer: true,
                      ),
                    ),
                  ),
          appBar:
              isWide
                  ? null
                  : AppBar(
                    leading: IconButton(
                      tooltip: 'Open navigation',
                      icon: const Icon(SolarIconsOutline.hamburgerMenu),
                      onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                    ),
                    title: Text(title),
                  ),
          body: Row(
            children: [
              if (isWide) _buildSidebar(context, destinations, isDrawer: false),
              Expanded(
                child: Container(
                  color: AppColors.background(brightness),
                  child: _buildMainContent(
                    selectedIndex: selected,
                    pageLabel: pageLabel,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSidebar(
    BuildContext context,
    List<_Destination> destinations, {
    required bool isDrawer,
  }) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final primary = theme.colorScheme.primary;
    final foreground = AppColors.textPrimary(brightness);
    final muted = AppColors.textMuted(brightness);

    return SidebarX(
      controller: _sidebarController,
      showToggleButton: false,
      theme: SidebarXTheme(
        width: MediaQuery.sizeOf(context).width * 0.7,
        padding: const EdgeInsets.symmetric(
          vertical: AppConstants.paddingMedium,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            right: BorderSide(color: AppColors.border(brightness)),
          ),
        ),
        iconTheme: IconThemeData(color: foreground, size: 20),
        selectedIconTheme: IconThemeData(color: primary, size: 20),
        itemTextPadding: const EdgeInsets.only(left: AppConstants.paddingSmall),
        itemDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        ),
        selectedItemDecoration: BoxDecoration(
          color: primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppConstants.borderRadiusMedium),
        ),
      ),
      headerBuilder:
          (context, extended) => Padding(
            padding: const EdgeInsets.fromLTRB(26, 12, 16, 32),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'AgriLens',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'New chat',
                  onPressed:
                      _initializing
                          ? null
                          : () => _handleSidebarNewChat(isDrawer: isDrawer),
                  icon: const Icon(SolarIconsOutline.addCircle),
                  color: primary,
                ),
              ],
            ),
          ),
      items: [
        for (var index = 0; index < destinations.length; index++)
          SidebarXItem(
            label: destinations[index].title,
            icon: destinations[index].icon,
            onTap: () => _select(index, isDrawer: isDrawer),
          ),
      ],
      separatorBuilder: (context, index) {
        if (index == _mainPages.length - 1) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(26, 26, 16, 12),
            child: Text(
              'History',
              style: theme.textTheme.labelMedium?.copyWith(
                color: muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }
        return const SizedBox(height: 4);
      },
      footerDivider: Divider(color: AppColors.divider(brightness), height: 1),
      footerBuilder:
          (context, extended) => Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Material(
              color:
                  _sidebarController.selectedIndex == _settingsIndex
                      ? primary.withValues(alpha: 0.10)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(
                AppConstants.borderRadiusMedium,
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(
                  AppConstants.borderRadiusMedium,
                ),
                onTap: () => _select(_settingsIndex, isDrawer: isDrawer),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        SolarIconsOutline.settings,
                        size: 21,
                        color:
                            _sidebarController.selectedIndex == _settingsIndex
                                ? primary
                                : foreground,
                      ),
                      const Gap(14),
                      Text(
                        'Settings',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color:
                              _sidebarController.selectedIndex == _settingsIndex
                                  ? primary
                                  : foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }
}
