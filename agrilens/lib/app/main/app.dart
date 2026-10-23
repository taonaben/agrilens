import 'package:agrilens/shared/theme/app_colors.dart';
import 'package:agrilens/shared/utils/app_constants.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:sidebarx/sidebarx.dart';
import 'package:solar_icons/solar_icons.dart';

class _Destination {
  const _Destination(this.title, this.icon, this.pageLabel);

  final String title;
  final IconData icon;
  final String pageLabel;
}

// Add a main page here; navigation and the placeholder title share this list.
const _pages = <_Destination>[
  _Destination('Chat', SolarIconsOutline.chatRound, 'Chat page'),
  _Destination('Store', SolarIconsOutline.shop, 'Store page'),
  _Destination('Weather', SolarIconsOutline.cloudSun, 'Weather page'),
];

// Replace these examples when saved chat history is available.
const _recentChats = <_Destination>[
  _Destination(
    'Crop planning',
    SolarIconsOutline.chatLine,
    'Crop planning chat',
  ),
  _Destination('Soil health', SolarIconsOutline.chatLine, 'Soil health chat'),
  _Destination(
    'Market prices',
    SolarIconsOutline.chatLine,
    'Market prices chat',
  ),
];

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  static final _settingsIndex = _pages.length + _recentChats.length;
  final _sidebarController = SidebarXController(
    selectedIndex: 0,
    extended: true,
  );
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void dispose() {
    _sidebarController.dispose();
    super.dispose();
  }

  void _select(int index, {required bool isDrawer}) {
    _sidebarController.selectIndex(index);
    if (isDrawer) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final destinations = [..._pages, ..._recentChats];
    final isWide = MediaQuery.sizeOf(context).width >= 700;

    return AnimatedBuilder(
      animation: _sidebarController,
      builder: (context, _) {
        final selected = _sidebarController.selectedIndex;
        final title =
            selected == _settingsIndex
                ? 'Settings'
                : destinations[selected].title;
        final pageLabel =
            selected == _settingsIndex
                ? 'Settings page'
                : destinations[selected].pageLabel;

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
                  alignment: Alignment.center,
                  child: Text(pageLabel, style: theme.textTheme.headlineMedium),
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
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'AgriLens',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
        if (index == _pages.length - 1) {
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
