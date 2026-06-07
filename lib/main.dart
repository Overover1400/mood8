import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/auth_user.dart';
import 'models/user_profile.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'screens/challenges/prestige_unlock_screen.dart';
import 'screens/paywall_screen.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/deep_link_service.dart';
import 'services/effects_service.dart';
import 'services/freeze_service.dart';
import 'services/gratitude_repository.dart';
import 'services/habit_repository.dart';
import 'services/habit_reminder_service.dart';
import 'services/haptic_service.dart';
import 'services/intention_repository.dart';
import 'services/notification_feed_service.dart';
import 'services/notification_service.dart';
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
  // Hydrate the SharedPreferences shadow store BEFORE first frame —
  // if a counter-habit tap from a prior session didn't reach Hive
  // because the user backgrounded mid-IndexedDB-transaction, this
  // replays the durable shadow into the Hive box so the home Today
  // list paints the right number on cold start.
  await HabitRepository().ensureShadowReady();
  // Same UTC-shift bug that ate counter logs also corrupted gratitude
  // + morning intention dates (their codecs used the same `_iso` push
  // path that converted local midnight to UTC). Heal any rows that
  // landed on the wrong calendar day before first frame.
  await IntentionRepository().repairCorruptedDates();
  await GratitudeRepository().repairCorruptedDates();
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
  // CRITICAL: init NotificationService BEFORE any code that calls
  // scheduleX or checks isGranted. Both are sync getters that return
  // their cached default (false) until init runs — without this await,
  // every boot-time scheduleAll call bails before doing anything,
  // even for users who already granted permission in a prior session.
  await NotificationService().ensureInitialized();
  await ReminderService().getSettings();
  await ReminderService().scheduleAllReminders();
  // v1: per-habit reminders are cut (see HabitReminderService docstring).
  // Wipe any OS-queued schedules from previous v1 attempts so they
  // don't fire late. Prefs-gated to run once per device.
  // TODO(v2): re-enable habit reminders — see Mood8 v2 reminders work.
  // ignore: discarded_futures
  HabitReminderService().cancelV1Schedules();
  // Fire-and-forget so a slow audio load doesn't block first paint.
  // Both services degrade silently when assets or capabilities are missing.
  HapticService().initialize();
  SfxService().initialize();
  // Listen for mood8:// deep links (Stripe checkout-return path).
  // Web is a no-op — the existing ?checkout=success query handler covers it.
  // ignore: discarded_futures
  DeepLinkService().initialize();
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
    // Cold-start notification poll so the header bell badge is
    // accurate the first time it paints.
    // ignore: discarded_futures
    NotificationFeedService().refresh();
  }
  runApp(const Mood8App());
}

/// Global key so the resume-time premium refresh can surface a snackbar
/// even when no specific screen is in scope.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Global navigator key so listener callbacks fired from outside the
/// widget tree (e.g. the [EffectsService.premiumEffectHintNotifier]
/// snackbar's "See" action) can push routes without needing a
/// BuildContext. The root ScaffoldMessenger sits ABOVE the Navigator
/// in MaterialApp's tree, so its `currentContext` can't resolve a
/// `Navigator.of` — this key bypasses that.
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>();

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
      // TODO(v2): re-enable habit reminders — see Mood8 v2 reminders work.
      // v1: resume hook no longer reschedules per-habit alarms because
      // the feature is cut. The legacy ReminderService (mood
      // check-ins) still rides on its own Timer-based scheduler and
      // doesn't need a resume refresh.
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
    // Also pull /me so the prestige-badge notifier fires if the
    // challenge cron just promoted the user past a threshold while
    // the app was backgrounded.
    // ignore: discarded_futures
    AuthService().refreshMe();
    // Refresh the notification feed so the bell badge updates if a
    // join request landed / cron ended a challenge / etc. while we
    // were backgrounded.
    // ignore: discarded_futures
    NotificationFeedService().refresh();
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
          navigatorKey: rootNavigatorKey,
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

  /// Pulses each time [resetAuth] completes so any live `_AuthGateState`
  /// instance reloads the persisted `skipAuth` pref. Without this, a
  /// user who originally hit "Try without account" (which set
  /// `_skipAuth = true` in state) and later logged in would still see
  /// the main app after sign-out — because we'd flip the pref to false
  /// but never re-read it into memory.
  static final ValueNotifier<int> authResetTick = ValueNotifier<int>(0);

  /// Clears auth + bypass so the gate returns to [WelcomeScreen]. Used
  /// from Settings → Account. Also wipes any cached user-scoped state
  /// (subscription tier, synced Hive entities, sync bookkeeping) so the
  /// next session doesn't inherit the previous user's data or premium
  /// UI. Refresh tokens, premium cards, and the "Manage premium" CTA
  /// all vanish as a result — the app re-renders as a clean signed-out
  /// shell driven by SubscriptionService.tier == free and a null
  /// AuthService.currentUser.
  static Future<void> resetAuth() async {
    await SyncService().clearLocalUserData();
    await SubscriptionService().clearForLogout();
    await AuthService().logout();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kSkipAuthPrefKey, false);
    } catch (_) {}
    authResetTick.value = authResetTick.value + 1;
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
  /// Last-seen server user id. Tracking by id (not email) so we can
  /// distinguish the guest-upgrade flow (REGISTER from guest → backend
  /// returns the SAME user id and we keep local data) from the
  /// guest→login-to-existing flow (LOGIN returns a DIFFERENT user id
  /// because the existing account already has its own server-side
  /// row). The id changing while we have a previous id is the signal
  /// to wipe local Hive + cached subscription state before pulling
  /// the new account down — otherwise Home keeps reading the previous
  /// user's UserProfile while Settings reads the fresh AuthUser, and
  /// the two diverge.
  String? _lastUserId;
  /// UI flag — true while the loading veneer should be shown. Set
  /// SYNCHRONOUSLY inside build() the frame we detect a new user id,
  /// so the very first paint after sign-in is already the loading
  /// screen (no one-frame flash of the previous account's home).
  bool _restoreInFlight = false;
  /// Separate re-entry guard for [_runPostLoginSync]. We can't reuse
  /// `_restoreInFlight` for this — the build sets that flag BEFORE
  /// the post-frame callback that actually starts the sync runs, so
  /// a guard like `if (_restoreInFlight) return;` would trip on the
  /// very first call and the sync would never run (loading screen
  /// stuck forever — the bug fix here). `_syncRunning` flips inside
  /// the sync function itself instead.
  bool _syncRunning = false;

  @override
  void initState() {
    super.initState();
    _loadSkip();
    _maybeHandleCheckoutReturn();
    SubscriptionService().premiumJustUnlockedNotifier
        .addListener(_onPremiumJustUnlocked);
    EffectsService().premiumEffectHintNotifier
        .addListener(_onPremiumEffectHint);
    AuthService().prestigeUnlockedNotifier
        .addListener(_onPrestigeUnlocked);
    AuthGate.authResetTick.addListener(_onAuthReset);
  }

  @override
  void dispose() {
    SubscriptionService().premiumJustUnlockedNotifier
        .removeListener(_onPremiumJustUnlocked);
    EffectsService().premiumEffectHintNotifier
        .removeListener(_onPremiumEffectHint);
    AuthService().prestigeUnlockedNotifier
        .removeListener(_onPrestigeUnlocked);
    AuthGate.authResetTick.removeListener(_onAuthReset);
    super.dispose();
  }

  void _onAuthReset() {
    // resetAuth flipped the persisted skipAuth pref to false. Re-read
    // it into in-memory state so the very next rebuild lands the user
    // on WelcomeScreen (was missed previously for users who'd come
    // through "Try without account" earlier in the session).
    _loadSkip();
  }

  void _onPrestigeUnlocked() {
    final badge = AuthService().prestigeUnlockedNotifier.value;
    if (badge == null || badge.isEmpty) return;
    final ctx = rootScaffoldMessengerKey.currentContext;
    if (ctx == null) return;
    // Full-screen celebration — bigger than the rank-up dialog.
    showGeneralDialog<void>(
      context: ctx,
      barrierDismissible: false,
      barrierLabel: 'Prestige unlock',
      barrierColor: Colors.black.withValues(alpha: 0.92),
      transitionDuration: const Duration(milliseconds: 320),
      pageBuilder: (_, _, _) => PrestigeUnlockScreen(badge: badge),
      transitionBuilder: (_, anim, _, child) {
        return FadeTransition(opacity: anim, child: child);
      },
    );
  }

  void _onPremiumJustUnlocked() {
    if (!SubscriptionService().premiumJustUnlockedNotifier.value) return;
    // Match the celebration copy to whichever tier the user just landed
    // on — Plus subscribers shouldn't be welcomed to "Premium".
    final isPlus = SubscriptionService().isPremiumPlus;
    final label = isPlus ? 'Premium Plus' : 'Premium';
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('Welcome to Mood8 $label ✨ Thanks for being here.'),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _onPremiumEffectHint() {
    final hint = EffectsService().premiumEffectHintNotifier.value;
    if (hint == null) return;
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    // Clear any previous snackbar before showing the new one so a
    // rapid double-fire doesn't queue a second toast behind it.
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(hint),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'See Premium',
          onPressed: () {
            // Dismiss the toast immediately — otherwise it sits above
            // the paywall route (the root ScaffoldMessenger is above
            // the Navigator in MaterialApp's tree).
            messenger.hideCurrentSnackBar();
            // Use the global navigator key — `messenger.context` can't
            // resolve a Navigator since the ScaffoldMessenger is its
            // ancestor.
            rootNavigatorKey.currentState?.push(
              MaterialPageRoute<void>(
                builder: (_) => const PaywallScreen(
                  contextNote: 'Premium unlocks cinematic celebrations.',
                ),
              ),
            );
          },
        ),
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
          // refreshStatus has populated the canonical tier — read it
          // back so the snackbar greets the correct family.
          final label = SubscriptionService().isPremiumPlus
              ? 'Premium Plus'
              : 'Premium';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Welcome to Mood8 $label ✨ Thanks for being here.'),
              duration: const Duration(seconds: 4),
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
            '[AuthGate] rebuild · user=${user?.email ?? 'null'} · '
            'id=${user?.id ?? '-'} · skipAuth=$_skipAuth');
        if (user == null) {
          // Logout drops user → null. Reset the per-id guard so the
          // next sign-in (even as the same account) re-fires the
          // fullRestore path that repopulates wiped Hive boxes.
          _lastUserId = null;
        } else if (user.id != _lastUserId) {
          // A user just signed in or switched accounts. We capture
          // the previous id BEFORE updating it so _runPostLoginSync
          // can detect "account switch" vs "first sync of a fresh
          // session" — the former needs to wipe local data, the
          // latter doesn't.
          final previousId = _lastUserId;
          _lastUserId = user.id;
          // Set the loading flag synchronously DURING this build so
          // the very next return below already renders the loading
          // screen. Without this, the build returns _Root (main app)
          // with stale Hive data for ~1 frame before the post-frame
          // callback fires and flips the flag — long enough for the
          // user to see the wrong identity flash. Mutating the field
          // directly (no setState) is safe because we read it right
          // away in the same build; _runPostLoginSync will call
          // setState later to drop the flag on completion.
          _restoreInFlight = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _runPostLoginSync(previousUserId: previousId);
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

  /// Hard cap on the loading gate. Sync is best-effort — if the
  /// network is slow, the server is down, or any one of the awaits
  /// stalls, the user MUST still be able to enter the app and use
  /// whatever's already in local Hive. The periodic sync started at
  /// the end of [_runPostLoginSync] retries in the background.
  ///
  /// 15s is comfortably above a healthy full-restore (typically <1s
  /// on a small account, ~3-5s on a heavy one over slow 3G) and well
  /// below "user gives up and force-quits".
  static const Duration _postLoginSyncTimeout = Duration(seconds: 15);

  Future<void> _runPostLoginSync({String? previousUserId}) async {
    // Re-entry guard — the build sets _restoreInFlight synchronously
    // BEFORE this fires, so we can't gate on it (the old code did and
    // hung the loading screen forever on every sign-in). _syncRunning
    // tracks whether the actual work is already in flight.
    if (_syncRunning) return;
    _syncRunning = true;
    try {
      await _doPostLoginSync(previousUserId: previousUserId)
          .timeout(_postLoginSyncTimeout, onTimeout: () {
        // A hung sync must NEVER block the user from reaching the app.
        // Fall through to the finally block — the loading gate drops,
        // the user lands on Home/onboarding with local data, and the
        // periodic background sync started below keeps trying.
        debugPrint(
            '[AuthGate] post-login sync timed out after '
            '${_postLoginSyncTimeout.inSeconds}s — entering app with '
            'local data; background sync will retry');
        return null;
      });
    } catch (e, st) {
      // Catch-all so no thrown exception can leave the loading gate
      // stuck. Sync errors are not user-blocking.
      debugPrint('[AuthGate] post-login sync failed: $e\n$st');
    } finally {
      _syncRunning = false;
      if (mounted) setState(() => _restoreInFlight = false);
      // Make absolutely sure the background sync is running even if
      // the foreground call threw or timed out — that's how we'll
      // recover once the network comes back.
      try {
        SyncService().startPeriodicSync();
      } catch (_) {}
    }
  }

  Future<void> _doPostLoginSync({String? previousUserId}) async {
    // `previousUserId != null` AND it differs from the new one means
    // the AuthUser id JUST changed under us — that's an account
    // switch (the only path is guest → log-in-to-existing, since
    // register-from-guest reuses the SAME id and login from a
    // signed-out state has previousUserId == null). The local Hive
    // boxes + cached subscription tier belong to the OLD account
    // and must be wiped before we hydrate the new one, otherwise
    // Home keeps reading the previous user's UserProfile while
    // Settings reads the fresh AuthUser, and we contaminate the
    // new account by pushing the old account's rows up.
    final newUserId = AuthService().currentUser?.id;
    final isAccountSwitch =
        previousUserId != null && previousUserId != newUserId;
    if (isAccountSwitch) {
      debugPrint(
          '[AuthGate] account switch $previousUserId → $newUserId · '
          'wipe + fullRestore + refreshStatus');
      SyncService().stopPeriodicSync();
      await SyncService().clearLocalUserData();
      await SubscriptionService().clearForLogout();
      await SyncService().fullRestore();
      await SubscriptionService().refreshStatus();
      return;
    }
    final hasLocal = SyncService().hasLocalUserData();
    if (!hasLocal) {
      debugPrint('[AuthGate] fresh install → fullRestore');
      await SyncService().fullRestore();
    } else {
      debugPrint('[AuthGate] same-user resume → migrate + sync');
      await SyncService().migrateInitialUploadIfNeeded();
      await SyncService().syncNow();
    }
    await SubscriptionService().refreshStatus();
    // TODO(v2): re-enable habit reminders — see Mood8 v2 reminders work.
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
              style: GoogleFonts.bricolageGrotesque(
                color: const Color(0xFFFAF5FF),
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
