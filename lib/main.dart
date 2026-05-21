import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'services/reminder_service.dart';
import 'services/sync_service.dart';
import 'widgets/tutorial_overlay.dart';
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
  await warmUpTutorialState();
  await FreezeService().warmUpPromptCache();
  final profile = UserRepository().getCurrentUser();
  if (profile != null) {
    await FreezeService().checkAndReplenish(
      profile,
      isPremium: SubscriptionService().isPremium,
    );
  }
  // Smart reminders: ensures the settings record exists (creating defaults
  // on first launch) and schedules timers if enabled + permission granted.
  // No-op silently if either condition is missing — the user can grant
  // permission from the settings screen at any time.
  await ReminderService().getSettings();
  await ReminderService().scheduleAllReminders();
  // Fire-and-forget so a slow audio load doesn't block first paint.
  // Both services degrade silently when assets or capabilities are missing.
  HapticService().initialize();
  SfxService().initialize();
  // Cloud sync: open the tombstone box, then schedule a pull + periodic
  // sync if the user is already signed in. Fresh-install logins run
  // fullRestore via AuthGate's post-login flow instead.
  await SyncService.warmUp();
  // Refresh subscription status in the background — local cache covers
  // the first frame; the server has the canonical state.
  // ignore: discarded_futures
  SubscriptionService().refreshStatus();
  if (AuthService().token != null) {
    // Existing session — do an initial-upload migration (for beta users
    // who had local data before sync shipped), then a normal pull.
    // ignore: discarded_futures
    SyncService().migrateInitialUploadIfNeeded().then((_) {
      // ignore: discarded_futures
      SyncService().pullChanges();
    });
    SyncService().startPeriodicSync();
  }
  runApp(const Mood8App());
}

/// Global key so the resume-time premium refresh can surface a snackbar
/// even when no specific screen is in scope.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class Mood8App extends StatefulWidget {
  const Mood8App({super.key});

  @override
  State<Mood8App> createState() => _Mood8AppState();
}

class _Mood8AppState extends State<Mood8App> with WidgetsBindingObserver {
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
    // Flush pending writes on background; catch other-device changes on
    // resume. Both fire-and-forget so framework lifecycle isn't blocked.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // ignore: discarded_futures
      SyncService().pushChanges();
    } else if (state == AppLifecycleState.resumed) {
      // ignore: discarded_futures
      SyncService().pullChanges();
      // Premium status may have flipped server-side while we were
      // backgrounded — e.g. a Stripe checkout webhook fired while the
      // user was in the Stripe browser tab. Refresh + announce.
      // ignore: discarded_futures
      _refreshPremiumOnResume();
    }
  }

  Future<void> _refreshPremiumOnResume() async {
    final pendingCheckout =
        await SubscriptionService().consumeCheckoutInProgress();
    final justUnlocked = await SubscriptionService().refreshStatus();
    // Pending flag + no flip yet? Webhook might still be propagating.
    // Try once more after a short delay. After that, the user can hit
    // the paywall "Already paid? Refresh" button.
    if (pendingCheckout && !justUnlocked && !SubscriptionService().isPremium) {
      await Future<void>.delayed(const Duration(seconds: 3));
      await SubscriptionService().refreshStatus();
    }
  }

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
          scaffoldMessengerKey: rootScaffoldMessengerKey,
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
  static bool _checkoutReturnHandled = false;
  // Sync-after-login lifecycle:
  //   null  = not yet decided
  //   true  = restore is currently running, show the loading veneer
  //   false = done, render normally
  String? _lastSyncedUserEmail;
  bool _restoreInFlight = false;

  @override
  void initState() {
    super.initState();
    _loadSkip();
    _maybeHandleCheckoutReturn();
    SubscriptionService().premiumJustUnlockedNotifier
        .addListener(_onPremiumJustUnlocked);
  }

  @override
  void dispose() {
    SubscriptionService().premiumJustUnlockedNotifier
        .removeListener(_onPremiumJustUnlocked);
    super.dispose();
  }

  void _onPremiumJustUnlocked() {
    if (!SubscriptionService().premiumJustUnlockedNotifier.value) return;
    // Show via the root ScaffoldMessenger so it works regardless of
    // which screen is mounted when the resume hook fires.
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Text('Welcome to Mood8 Premium ✨ Thanks for being here.'),
        duration: Duration(seconds: 4),
      ),
    );
  }

  void _maybeHandleCheckoutReturn() {
    if (_checkoutReturnHandled) return;
    _checkoutReturnHandled = true;
    try {
      final params = Uri.base.queryParameters;
      final result = params['checkout'];
      if (result == 'success') {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await SubscriptionService().refreshStatus();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Welcome to Mood8 Premium ✨ Thanks for being here.'),
              duration: Duration(seconds: 4),
            ),
          );
        });
      }
      // checkout=cancelled is a no-op (user just lands back on Home).
    } catch (_) {}
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
    // Try-without-account now creates a real (anonymous) server account
    // so the user's data syncs. If the network call fails we still let
    // them through locally — they can register later to fix it.
    if (AuthService().token == null) {
      final result = await AuthService().createGuestAccount();
      if (!result.success) {
        debugPrint('[AuthGate] guest create failed: ${result.message}');
      }
    }
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
        if (user != null && user.email != _lastSyncedUserEmail) {
          // A user just signed in (or switched accounts). Kick off the
          // restore flow once per user-email.
          _lastSyncedUserEmail = user.email;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _runPostLoginSync();
          });
        }
        if (_restoreInFlight) {
          return const _RestoringScreen();
        }
        if (user != null || _skipAuth) {
          return const _Root();
        }
        return WelcomeScreen(onBypass: _onBypass);
      },
    );
  }

  Future<void> _runPostLoginSync() async {
    if (_restoreInFlight) return;
    setState(() => _restoreInFlight = true);
    try {
      final hasLocal = SyncService().hasLocalUserData();
      if (!hasLocal) {
        // Fresh install (or device wipe) → pull everything down.
        debugPrint('[AuthGate] fresh install → fullRestore');
        await SyncService().fullRestore();
      } else {
        // Existing local data → one-time push for legacy beta users
        // who had data pre-sync, then a normal merge pull.
        debugPrint('[AuthGate] existing data → migrate + sync');
        await SyncService().migrateInitialUploadIfNeeded();
        await SyncService().syncNow();
      }
      SyncService().startPeriodicSync();
    } catch (e) {
      debugPrint('[AuthGate] post-login sync failed: $e');
    } finally {
      if (mounted) setState(() => _restoreInFlight = false);
    }
  }
}

class _RestoringScreen extends StatelessWidget {
  const _RestoringScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0612),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 38,
              height: 38,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation(Color(0xFFF472B6)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Bringing your world back…',
              style: GoogleFonts.instrumentSerif(
                color: const Color(0xFFFAF5FF),
                fontStyle: FontStyle.italic,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Restoring your habits, moods, and memories.",
              style: TextStyle(
                color: Color(0xFFA78BB8),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
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
