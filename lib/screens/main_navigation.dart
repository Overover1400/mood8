import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../feature_flags.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/tutorial_overlay.dart';
import 'challenges/challenges_list_screen.dart';
import 'coach_screen.dart';
import 'habits_screen.dart';
import 'home_screen.dart';
import 'progress_insights_tab.dart';
import 'routine_screen.dart';

const String _kTabPrefKey = 'mood8.currentTab';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  /// The currently-mounted navigation state. Held statically so callers
  /// that live OUTSIDE the navigation subtree can still drive it — most
  /// importantly the welcome tutorial, which mounts in the root overlay
  /// (a sibling of the app content, not a descendant of MainNavigation).
  /// An ancestor lookup from there resolves to null, which silently broke
  /// tab switching mid-tutorial — every step rendered over the Home tab.
  static _MainNavigationState? _current;

  static void goToTab(BuildContext context, int index) {
    // Prefer the ancestor state when the caller is inside the subtree
    // (keeps behaviour identical for in-app call sites); fall back to the
    // static reference for out-of-tree callers like the tutorial overlay.
    final state = context.findAncestorStateOfType<_MainNavigationState>() ??
        _current;
    state?._onTab(index);
  }

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _index = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    MainNavigation._current = this;
    _loadTab();
    _maybeShowTutorial();
  }

  @override
  void dispose() {
    if (MainNavigation._current == this) MainNavigation._current = null;
    super.dispose();
  }

  static bool _tutorialCheckedThisSession = false;

  Future<void> _maybeShowTutorial() async {
    if (_tutorialCheckedThisSession) return;
    _tutorialCheckedThisSession = true;
    if (await isTutorialCompleted()) return;
    // Let the first paint settle so the cards animate cleanly over a
    // mounted home screen instead of an empty void.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    showTutorial(context);
  }

  Future<void> _loadTab() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_kTabPrefKey) ?? 0;
      if (mounted) {
        setState(() {
          _index = saved.clamp(0, kNavItems.length - 1);
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _onTab(int i) async {
    if (i == _index) return;
    setState(() => _index = i);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kTabPrefKey, i);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      body: Stack(
        children: [
          if (_loaded)
            // Children order MUST match kNavItems exactly — feature
            // flags below decide whether RoutineScreen is included so
            // index constants line up with the visible tab order. See
            // lib/feature_flags.dart for the kRoutineEnabled flag.
            IndexedStack(
              index: _index,
              children: const [
                HomeScreen(),
                HabitsScreen(),
                if (kRoutineEnabled) RoutineScreen(),
                ChallengesListScreen(embedded: true),
                CoachScreen(),
                ProgressInsightsTab(),
              ],
            ),
          Align(
            alignment: Alignment.bottomCenter,
            child: MoodBottomNav(
              currentIndex: _index,
              onTap: _onTab,
            )
                .animate()
                .fadeIn(delay: 550.ms, duration: 500.ms)
                .slideY(begin: 0.4, end: 0, curve: Curves.easeOutCubic),
          ),
        ],
      ),
    );
  }
}

