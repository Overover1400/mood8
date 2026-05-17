import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import 'coach_screen.dart';
import 'habits_screen.dart';
import 'home_screen.dart';
import 'insights_screen.dart';
import 'progress_screen.dart';
import 'routine_screen.dart';

const String _kTabPrefKey = 'mood8.currentTab';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  static void goToTab(BuildContext context, int index) {
    final state = context.findAncestorStateOfType<_MainNavigationState>();
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
    _loadTab();
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
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          if (_loaded)
            IndexedStack(
              index: _index,
              children: const [
                HomeScreen(),
                HabitsScreen(),
                RoutineScreen(),
                CoachScreen(),
                InsightsScreen(),
                ProgressScreen(),
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

