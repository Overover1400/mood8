import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/auth_user.dart';
import 'models/user_profile.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/effects_service.dart';
import 'services/freeze_service.dart';
import 'services/haptic_service.dart';
import 'services/preferences_service.dart';
import 'services/routine_repository.dart';
import 'services/sfx_service.dart';
import 'services/subscription_service.dart';
import 'services/user_repository.dart';
import 'theme/app_theme.dart';
import 'theme/app_theme_light.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.init();
  if (UserRepository().isOnboardingComplete()) {
    await RoutineRepository().seedDefaultRoutines();
  }
  // Load preferences synchronously so the first frame paints the right theme.
  await PreferencesService.instance.load();
  await SubscriptionService().load();
  await EffectsService().initialize();
  await AuthService().initialize();
  // Auto-replenish streak freezes (no-op if onboarding hasn't created a
  // profile yet — first replenish will happen after onboarding).
  final profile = UserRepository().getCurrentUser();
  if (profile != null) {
    await FreezeService().checkAndReplenish(
      profile,
      isPremium: SubscriptionService().isPremium,
    );
  }
  // Fire-and-forget so a slow audio load doesn't block first paint.
  // Both services degrade silently when assets or capabilities are missing.
  HapticService().initialize();
  SfxService().initialize();
  runApp(const Mood8App());
}

class Mood8App extends StatelessWidget {
  const Mood8App({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: PreferencesService.instance.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Mood8',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: AppLightTheme.theme,
          darkTheme: AppTheme.dark,
          home: const AuthGate(),
        );
      },
    );
  }
}

/// Decides whether to show the welcome / auth flow or the main app.
/// Signed-in users always go to [_Root]. Logged-out users can opt out of
/// auth via "Try without account" — a `mood8.skipAuth` pref persists that
/// choice so the screen doesn't bounce back on every launch.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  /// Clears auth + bypass so the gate returns to [WelcomeScreen]. Used from
  /// Settings → Account.
  static Future<void> resetAuth() async {
    await AuthService().logout();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kSkipAuthPrefKey, false);
    } catch (_) {}
  }

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _skipAuth = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _loadSkip();
  }

  Future<void> _loadSkip() async {
    bool skip = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      skip = prefs.getBool(kSkipAuthPrefKey) ?? false;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _skipAuth = skip;
      _checked = true;
    });
  }

  Future<void> _onBypass() async {
    setState(() => _skipAuth = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kSkipAuthPrefKey, true);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0612),
        body: SizedBox.shrink(),
      );
    }
    return ValueListenableBuilder<AuthUser?>(
      valueListenable: AuthService().currentUserNotifier,
      builder: (context, user, _) {
        debugPrint(
            '[AuthGate] rebuild · user=${user?.email ?? 'null'} · skipAuth=$_skipAuth');
        if (user != null || _skipAuth) {
          return const _Root();
        }
        return WelcomeScreen(onBypass: _onBypass);
      },
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<UserProfile>>(
      valueListenable: UserRepository().watchUser(),
      builder: (context, box, _) {
        final user = box.get(UserRepository.userKey);
        if (user?.hasCompletedOnboarding ?? false) {
          return const MainNavigation();
        }
        return const OnboardingFlow();
      },
    );
  }
}
