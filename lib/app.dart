import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/feedback/interaction_feedback.dart';
import 'core/theme/app_theme_controller.dart';
import 'core/security/app_lock_controller.dart';
import 'core/security/private_album_controller.dart';
import 'features/app_lock/app_lock_pages.dart';
import 'features/home/home_page.dart';
import 'features/library/library_page.dart';
import 'features/onboarding/first_use_guide_page.dart';
import 'features/settings/settings_page.dart';
import 'features/settings/photo_source_controller.dart';
import 'features/timeline/timeline_page.dart';
import 'widgets/floating_bottom_navigation.dart';

class PhotoStorerApp extends StatefulWidget {
  const PhotoStorerApp({super.key});

  @override
  State<PhotoStorerApp> createState() => _PhotoStorerAppState();
}

class _PhotoStorerAppState extends State<PhotoStorerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final lock = context.read<AppLockController>();
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      lock.markBackgrounded();
      // Private albums relock immediately on background: the user expects to
      // re-enter the password every time the app is left and reopened.
      context.read<PrivateAlbumController>().lockAll();
    } else if (state == AppLifecycleState.resumed) {
      lock.handleResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppThemeController>(
      builder: (context, themeController, _) {
        return MaterialApp(
          title: '相册分类',
          debugShowCheckedModeBanner: false,
          theme: themeController.lightTheme,
          darkTheme: themeController.darkTheme,
          themeMode: themeController.themeMode,
          builder: (context, child) => InteractionFeedbackLayer(
            enabled: context.watch<InteractionFeedbackController>().enabled,
            child: child ?? const SizedBox.shrink(),
          ),
          home: Consumer2<PhotoSourceController, AppLockController>(
            builder: (_, sourceController, lockController, __) {
              if (lockController.enabled && !lockController.isUnlocked) {
                return const AppLockPage();
              }
              return sourceController.firstUseCompleted
                  ? MainShell(
                      key: ValueKey(sourceController.dataRevision),
                    )
                  : const FirstUseGuidePage();
            },
          ),
        );
      },
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  /// Bumped every time the gallery or timeline tab is (re)selected so the
  /// kept-alive pages inside the IndexedStack can silently reload new data.
  final ValueNotifier<int> _tabRefreshSignal = ValueNotifier<int>(0);

  late final List<Widget?> _pages;

  @override
  void initState() {
    super.initState();
    // Only initialize the visible tab. Gallery and timeline both query the
    // database, so eagerly creating all tabs can make the first load appear
    // stuck on slower devices.
    _pages = <Widget?>[const HomePage(), null, null, null];
  }

  @override
  void dispose() {
    _tabRefreshSignal.dispose();
    super.dispose();
  }

  Widget _pageFor(int index) => switch (index) {
        0 => const HomePage(),
        1 => LibraryPage(refreshSignal: _tabRefreshSignal),
        2 => TimelinePage(refreshSignal: _tabRefreshSignal),
        _ => const SettingsPage(),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: List.generate(
          _pages.length,
          (index) => _pages[index] ?? const SizedBox.shrink(),
        ),
      ),
      bottomNavigationBar: FloatingBottomNavigation(
        selectedIndex: _currentIndex,
        onSelected: (index) {
          setState(() {
            _pages[index] ??= _pageFor(index);
            _currentIndex = index;
          });
          if (index == 1 || index == 2) {
            _tabRefreshSignal.value++;
          }
        },
      ),
    );
  }
}
