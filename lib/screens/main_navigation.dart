import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import 'home_screen.dart';
import 'routine_screen.dart';

const String _kTabPrefKey = 'mood8.currentTab';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

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
                _PlaceholderScreen(title: 'Habits', subtitle: 'Coming soon'),
                RoutineScreen(),
                _PlaceholderScreen(
                    title: 'Insights', subtitle: 'Coming soon'),
                _PlaceholderScreen(
                    title: 'Progress', subtitle: 'Coming soon'),
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

class _PlaceholderScreen extends StatelessWidget {
  const _PlaceholderScreen({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShaderMask(
                shaderCallback: (r) =>
                    AppColors.primaryGradient.createShader(r),
                child: Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall
                      ?.copyWith(color: Colors.white),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppColors.inkDim,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
