import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/adaptive_suggestion.dart';
import '../models/gratitude_entry.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/mood_entry.dart';
import '../models/reflection.dart';
import '../models/routine_item.dart';
import '../models/sfx_type.dart';
import '../models/user_profile.dart';
import '../services/adaptive_routine_service.dart';
import '../services/badge_service.dart';
import '../services/effects_service.dart';
import '../services/habit_repository.dart';
import '../services/haptic_service.dart';
import '../services/intention_repository.dart';
import '../services/reminder_service.dart';
import '../services/weekly_recap_service.dart';
import '../services/pattern_detection_service.dart';
import '../models/pattern_alert.dart';
import '../widgets/pattern_alert_card.dart';
import 'patterns_screen.dart';
import '../widgets/tutorial_overlay.dart';
import '../widgets/tutorial_targets.dart';
import 'year_in_review_screen.dart';
import '../services/milestone_service.dart';
import '../services/mood_repository.dart';
import '../services/onboarding_service.dart';
import '../services/preferences_service.dart';
import '../services/reflection_repository.dart';
import '../services/routine_repository.dart';
import '../services/score_service.dart';
import '../services/sfx_service.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/badge_unlock_modal.dart';
import '../widgets/cards.dart';
import '../widgets/freeze_badge.dart';
import '../widgets/glow_slider.dart';
import '../widgets/gratitude_sheet.dart';
import '../widgets/habit_log_button.dart';
import '../widgets/intention_sheet.dart';
import 'weekly_recap_screen.dart';
import '../widgets/adaptive_suggestion_card.dart';
import '../widgets/reflection_card.dart';
import '../widgets/responsive_container.dart';
import '../widgets/settings/color_avatar.dart';
import 'habit_detail_screen.dart';
import 'main_navigation.dart';
import 'settings_screen.dart';
import 'auth/register_screen.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MoodRepository _moods = MoodRepository();
  final RoutineRepository _routines = RoutineRepository();
  final UserRepository _users = UserRepository();
  final ReflectionRepository _reflections = ReflectionRepository();
  final HabitRepository _habits = HabitRepository();
  final IntentionRepository _intentions = IntentionRepository();
  final ScoreService _score = ScoreService();
  final AdaptiveRoutineService _adaptive = AdaptiveRoutineService();

  AdaptiveSuggestion? _suggestion;
  bool _applyingSuggestion = false;
  bool _suggestionLoaded = false;

  /// Static so the auto-prompt only fires once per app session, even if
  /// HomeScreen rebuilds (tab switches, hot reload, etc.).
  static bool _intentionPromptShown = false;

  bool _showRecapBanner = false;
  static bool _patternsRanThisSession = false;
  bool _intentionPromptDispatched = false;
  bool _showGuestNudge = false;
  bool _showYirBanner = false;
  static const String _kGuestNudgeDismissedKey =
      'mood8.guestNudge.dismissedAtIso';
  // SharedPreferences key gating the December YIR banner. We append
  // the recap year (e.g. mood8.yir.bannerDismissed.2026) so the user
  // sees a fresh prompt every year and a dismissal in 2026 doesn't
  // suppress the 2027 banner.
  static const String _kYirBannerDismissedPrefix =
      'mood8.yir.bannerDismissed.';

  @override
  void initState() {
    super.initState();
    _loadSuggestion();
    _maybeAwardBadgesOnOpen();
    _maybeRunPatternDetection();
    _maybeShowGuestNudge();
    _hydrateTodayMood();
    // Tutorial-gated prompts: intention + recap banner only after the
    // tutorial completes (or if it was already completed in a prior
    // session). The notifier listener fires both immediately (if the
    // initial value is true) and on later flips (when the user finishes
    // a first-run tutorial).
    tutorialCompletedNotifier.addListener(_onTutorialStateChange);
    if (tutorialCompletedNotifier.value) {
      _onTutorialStateChange();
    }
  }

  /// If the user already checked in today, prefill the sliders with
  /// today's values so further adjustments update the same entry
  /// instead of overwriting from the defaults.
  void _hydrateTodayMood() {
    final today = _moods.getTodayEntry();
    if (today == null) return;
    setState(() {
      _mood = (today.mood / 10).clamp(0.0, 1.0);
      _energy = (today.energy / 10).clamp(0.0, 1.0);
      _focus = (today.focus / 10).clamp(0.0, 1.0);
      // Don't arm the auto-save baseline — opening Home shouldn't
      // re-save the existing entry.
      _initialMoodLoaded = false;
    });
  }

  @override
  void dispose() {
    tutorialCompletedNotifier.removeListener(_onTutorialStateChange);
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  void _onTutorialStateChange() {
    if (!tutorialCompletedNotifier.value) return;
    if (_intentionPromptDispatched) return;
    _intentionPromptDispatched = true;
    _maybePromptIntention();
    _maybeShowRecapBanner();
    _maybeShowYirBanner();
  }

  Future<void> _maybeShowGuestNudge() async {
    // Show the "register to keep your data safe" nudge if (a) the user
    // is a guest, and (b) they haven't dismissed it in the last 3 days.
    // We re-show after 3 days so it's noticeable but not annoying.
    final user = AuthService().currentUserNotifier.value;
    if (user == null || !user.isGuest) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final iso = prefs.getString(_kGuestNudgeDismissedKey);
      if (iso != null) {
        final dismissed = DateTime.tryParse(iso);
        if (dismissed != null &&
            DateTime.now().difference(dismissed) <
                const Duration(days: 3)) {
          return;
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() => _showGuestNudge = true);
  }

  Future<void> _dismissGuestNudge() async {
    HapticService().selection();
    setState(() => _showGuestNudge = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kGuestNudgeDismissedKey,
        DateTime.now().toIso8601String(),
      );
    } catch (_) {}
  }

  Future<void> _openGuestRegister() async {
    HapticService().light();
    if (!mounted) return;
    setState(() => _showGuestNudge = false);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  Future<void> _maybeRunPatternDetection() async {
    if (_patternsRanThisSession) return;
    _patternsRanThisSession = true;
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!mounted) return;
    try {
      await PatternDetectionService().detectPatterns();
    } catch (e) {
      debugPrint('[Home] pattern detection failed: $e');
    }
  }

  void _onPatternAction(PatternAlert a) {
    HapticService().light();
    PatternDetectionService().markViewed(a);
    final route = a.actionRoute;
    if (route == null) return;
    if (route == 'coach') {
      MainNavigation.goToTab(context, kCoachTabIndex);
    } else if (route == 'habits') {
      MainNavigation.goToTab(context, kHabitsTabIndex);
    } else if (route == 'progress') {
      MainNavigation.goToTab(context, kProgressTabIndex);
    } else if (route.startsWith('habit:')) {
      final id = route.substring('habit:'.length);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HabitDetailScreen(habitId: id),
        ),
      );
    }
  }

  void _onPatternDismiss(PatternAlert a) {
    HapticService().selection();
    PatternDetectionService().dismiss(a);
  }

  void _openPatternsScreen() {
    HapticService().light();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PatternsScreen()),
    );
  }

  Future<void> _maybeShowRecapBanner() async {
    final service = WeeklyRecapService();
    if (!service.shouldShowRecapPrompt()) return;
    final prefs = await SharedPreferences.getInstance();
    final key = WeeklyRecapService.bannerDismissedPrefKey(DateTime.now());
    if (prefs.getBool(key) ?? false) return;
    if (!mounted) return;
    setState(() => _showRecapBanner = true);
  }

  /// Only shows during December — the YIR is a December moment.
  /// Dismissable; the dismissed flag is keyed to the year so next year's
  /// banner pops fresh.
  Future<void> _maybeShowYirBanner() async {
    final now = DateTime.now();
    if (now.month != 12) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('$_kYirBannerDismissedPrefix${now.year}') ?? false) {
        return;
      }
    } catch (_) {/* read failure → show by default */}
    if (!mounted) return;
    setState(() => _showYirBanner = true);
  }

  Future<void> _openYearInReview() async {
    HapticService().light();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const YearInReviewScreen(),
      ),
    );
  }

  Future<void> _dismissYirBanner() async {
    HapticService().selection();
    final year = DateTime.now().year;
    setState(() => _showYirBanner = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_kYirBannerDismissedPrefix$year', true);
    } catch (_) {}
  }

  Future<void> _openRecap() async {
    HapticService().light();
    setState(() => _showRecapBanner = false);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const WeeklyRecapScreen(),
      ),
    );
  }

  Future<void> _dismissRecapBanner() async {
    HapticService().selection();
    setState(() => _showRecapBanner = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        WeeklyRecapService.bannerDismissedPrefKey(DateTime.now()),
        true,
      );
    } catch (_) {}
  }

  static bool _coldStartBadgeCheckRan = false;

  Future<void> _maybeAwardBadgesOnOpen() async {
    if (_coldStartBadgeCheckRan) return;
    _coldStartBadgeCheckRan = true;
    // Slight delay so the cold-start render doesn't fight with the modal.
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final awarded = await BadgeService().checkAndAwardBadges();
    if (awarded.isNotEmpty && mounted) {
      await showBadgeUnlockQueue(context, awarded);
    }
  }

  Future<void> _maybePromptIntention() async {
    if (_intentionPromptShown) return;
    if (!PreferencesService.instance.showMorningIntention) return;
    if (DateTime.now().hour < 4) return;
    if (_intentions.hasSetTodaysIntention()) return;
    _intentionPromptShown = true;
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    await showIntentionSheet(context);
  }

  Future<void> _openIntentionSheet({String? existing}) async {
    HapticService().light();
    await showIntentionSheet(context, existingText: existing);
  }

  Future<void> _openGratitudeSheet({GratitudeEntry? existing}) async {
    HapticService().light();
    await showGratitudeSheet(context, existing: existing);
  }

  Future<void> _loadSuggestion() async {
    try {
      final s = await _adaptive.topSuggestion();
      if (!mounted) return;
      setState(() {
        _suggestion = s;
        _suggestionLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _suggestionLoaded = true);
    }
  }

  Future<void> _applySuggestion() async {
    final s = _suggestion;
    if (s == null || _applyingSuggestion) return;
    setState(() => _applyingSuggestion = true);
    try {
      final msg = await _adaptive.apply(s);
      await _adaptive.dismiss(s);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg ?? 'Got it — taking a look.'),
          backgroundColor: BrandColors.bgCard(context),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
      setState(() {
        _suggestion = null;
        _applyingSuggestion = false;
      });
    } catch (_) {
      if (mounted) setState(() => _applyingSuggestion = false);
    }
  }

  Future<void> _toggleRoutine(RoutineItem item) async {
    if (item.isCompleted) {
      item.isCompleted = false;
      item.completedAt = null;
      await _routines.updateRoutine(item);
      HapticService().light();
      debugPrint('[Effects] Routine un-toggled · no celebration');
      return;
    }
    await _routines.markComplete(item.id);
    // Re-fetch fresh after the put completes. Hive .save() returns once the
    // box is mutated, so this list reflects the new state.
    final todays = _routines.getTodayRoutines();
    final completed = todays.where((r) => r.isCompleted).length;
    final total = todays.length;
    final allDone = total > 0 && completed == total;
    debugPrint(
        '[Effects] Routine completion (Home Up Next): $completed/$total · allDone=$allDone');

    // Sound + haptic FIRST, sized by whether this is the perfect-day moment.
    if (allDone) {
      SfxService().fire(SfxType.streakMilestone);
      // ignore: discarded_futures
      HapticService().reward();
    } else {
      SfxService().fire(SfxType.routineDone);
      HapticService().light();
    }
    if (!mounted) return;

    if (allDone) {
      final user = _users.getCurrentUser();
      debugPrint(
          '[Effects] 🎉 ALL ROUTINES COMPLETE — triggering CosmicBloom (user=${user?.name})');
      EffectsService().celebrateAllRoutinesComplete(
        context: context,
        userName: user?.name,
      );
      // Perfect day → record + check routine badges. Delay so we don't
      // step on the CosmicBloom celebration that's just starting.
      Future<void>.delayed(const Duration(milliseconds: 2800), () async {
        await BadgeService().recordPerfectRoutineDay();
        if (!mounted) return;
        final awarded = await BadgeService().checkAndAwardBadges();
        if (awarded.isNotEmpty && mounted) {
          await showBadgeUnlockQueue(context, awarded);
        }
      });
    } else {
      debugPrint('[Effects] Single routine complete — PremiumBloom');
      EffectsService().celebrateHabitComplete(context: context);
    }
  }

  Future<void> _dismissSuggestion() async {
    final s = _suggestion;
    if (s == null) return;
    await _adaptive.dismiss(s);
    if (!mounted) return;
    setState(() => _suggestion = null);
  }

  double _mood = 0.72;
  double _energy = 0.58;
  double _focus = 0.65;
  bool _saving = false;
  // Auto-save debounce: every slider interaction restarts the timer;
  // after ~2 s of quiet we silently upsert today's mood entry and
  // pulse `_savedFlash` true for ~1 s to show the "Saved ✓" stamp.
  Timer? _autoSaveTimer;
  bool _savedFlash = false;
  bool _initialMoodLoaded = false;

  /// Called by every slider's onChanged. Updates local state + resets
  /// the auto-save countdown. The first interaction also flips a flag
  /// so we never auto-save the default (unedited) values.
  void _onSliderChange(void Function() apply) {
    apply();
    _initialMoodLoaded = true;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 2), _runAutoSave);
  }

  Future<void> _runAutoSave() async {
    if (!_initialMoodLoaded) return;
    if (_saving) return;
    final wasNewEntry = _moods.getTodayEntry() == null;
    setState(() => _saving = true);
    try {
      await _moods.upsertTodayEntry(
        mood: _mood * 10,
        energy: _energy * 10,
        focus: _focus * 10,
      );
      HapticService().selection();
      if (!mounted) return;
      setState(() {
        _saving = false;
        _savedFlash = true;
      });
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) setState(() => _savedFlash = false);
      });
      // First save of the day cascades into the existing post-checkin
      // side-effects (streak milestone celebration, badges, reminder
      // suppression). Subsequent slider tweaks are silent updates.
      if (!wasNewEntry) return;
      final streak = _moods.calculateStreak();
      final hitMilestone = _kStreakMilestones.contains(streak);
      if (hitMilestone) {
        SfxService().fire(SfxType.streakMilestone);
        // ignore: discarded_futures
        HapticService().reward();
        EffectsService().celebrateStreakMilestone(
          context: context,
          days: streak,
        );
      } else {
        SfxService().fire(SfxType.checkInSuccess);
        EffectsService().celebrateHabitComplete(context: context);
      }
      final earned = await MilestoneService().checkStreak(streak);
      if (earned != null && mounted && !hitMilestone) {
        EffectsService().celebrateStreakMilestone(
          context: context,
          days: streak,
        );
      }
      Future<void>.delayed(const Duration(milliseconds: 1400), () async {
        final awarded = await BadgeService().checkAndAwardBadges();
        if (awarded.isNotEmpty && mounted) {
          await showBadgeUnlockQueue(context, awarded);
        }
      });
      // ignore: unawaited_futures
      ReminderService().onMoodLogged();
    } catch (e) {
      SfxService().fire(SfxType.errorGentle);
      HapticService().heavy();
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Bottom sheet from the header "+" button. Two quick actions —
  /// intention and gratitude — both replace what used to live on Home
  /// as standalone banners.
  Future<void> _openHomeAddSheet() async {
    HapticService().light();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HomeAddSheet(
        onIntention: () {
          Navigator.of(ctx).maybePop();
          _openIntentionSheet();
        },
        onGratitude: () {
          Navigator.of(ctx).maybePop();
          _openGratitudeSheet();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      body: Stack(
        children: [
          const _BackgroundGlow(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: ResponsiveContainer(
                maxWidth: 480,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ValueListenableBuilder<Box<MoodEntry>>(
                        valueListenable: _moods.watchEntries(),
                        builder: (context, _, _) =>
                            ValueListenableBuilder<Box<UserProfile>>(
                          valueListenable: _users.watchUser(),
                          builder: (context, userBox, _) {
                            final user =
                                userBox.get(UserRepository.userKey);
                            return _Header(
                              name: user?.name ?? 'friend',
                              streak: _moods.calculateStreak(),
                              profile: user,
                              onLongPressName: () =>
                                  _confirmReset(context),
                              onOpenSettings: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              ),
                              onAddTap: _openHomeAddSheet,
                            );
                          },
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 500.ms)
                          .slideY(
                              begin: -0.15,
                              end: 0,
                              curve: Curves.easeOutCubic),
                      ValueListenableBuilder<Box<Reflection>>(
                        valueListenable: _reflections.watchReflections(),
                        builder: (context, _, _) {
                          final today = _reflections.getTodayReflection();
                          final hour = DateTime.now().hour;
                          if (today != null) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: ReflectionCard(
                                reflection: today,
                                compact: true,
                                onTap: () => MainNavigation.goToTab(
                                    context, kCoachTabIndex),
                              )
                                  .animate()
                                  .fadeIn(delay: 60.ms, duration: 500.ms)
                                  .slideY(
                                      begin: 0.06,
                                      end: 0,
                                      curve: Curves.easeOutCubic),
                            );
                          }
                          if (hour >= 18) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: _ReflectionNudge(
                                onTap: () => MainNavigation.goToTab(
                                    context, kCoachTabIndex),
                              )
                                  .animate()
                                  .fadeIn(delay: 60.ms, duration: 500.ms)
                                  .slideY(
                                      begin: 0.06,
                                      end: 0,
                                      curve: Curves.easeOutCubic),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                      if (_showGuestNudge) ...[
                        const SizedBox(height: 18),
                        _GuestNudgeBanner(
                          onTap: _openGuestRegister,
                          onDismiss: _dismissGuestNudge,
                        )
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideY(
                                begin: -0.05,
                                end: 0,
                                curve: Curves.easeOutCubic),
                      ],
                      if (_showRecapBanner) ...[
                        const SizedBox(height: 18),
                        _RecapBanner(
                          onTap: _openRecap,
                          onDismiss: _dismissRecapBanner,
                        )
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideY(
                                begin: -0.05,
                                end: 0,
                                curve: Curves.easeOutCubic),
                      ],
                      if (_showYirBanner) ...[
                        const SizedBox(height: 18),
                        _YirBanner(
                          onTap: _openYearInReview,
                          onDismiss: _dismissYirBanner,
                        )
                            .animate()
                            .fadeIn(duration: 400.ms)
                            .slideY(
                                begin: -0.05,
                                end: 0,
                                curve: Curves.easeOutCubic),
                      ],
                      // Challenges entry card removed — Challenges is now
                      // a bottom-nav tab.
                      ValueListenableBuilder<Box<PatternAlert>>(
                        valueListenable:
                            PatternDetectionService().watch(),
                        builder: (context, _, _) {
                          final unread = PatternDetectionService()
                              .all()
                              .where((a) => a.isUnread)
                              .take(3)
                              .toList();
                          if (unread.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: _PatternsCarousel(
                              alerts: unread,
                              onAction: _onPatternAction,
                              onDismiss: _onPatternDismiss,
                              onSeeAll: _openPatternsScreen,
                            )
                                .animate()
                                .fadeIn(duration: 450.ms)
                                .slideY(
                                    begin: -0.04,
                                    end: 0,
                                    curve: Curves.easeOutCubic),
                          );
                        },
                      ),
                      // Intention banner / nudge / gratitude card are
                      // no longer rendered inline — both flows live in
                      // the header "+" sheet now.
                      const SizedBox(height: 18),
                      ValueListenableBuilder<Box<MoodEntry>>(
                        valueListenable: _moods.watchEntries(),
                        builder: (context, _, _) {
                          return ValueListenableBuilder<Box<RoutineItem>>(
                            valueListenable: _routines.watchRoutines(),
                            builder: (context, _, _) =>
                                ValueListenableBuilder<Box<HabitLog>>(
                              valueListenable: _habits.watchLogs(),
                              builder: (context, _, _) => _StatsRow(
                                streak: _moods.calculateStreak(),
                                completedToday: _routines
                                    .getTodayRoutines()
                                    .where((r) => r.isCompleted)
                                    .length,
                                totalToday:
                                    _routines.getTodayRoutines().length,
                                disciplineScore: _score.getDisciplineScore(),
                                onTapDiscipline: () =>
                                    MainNavigation.goToTab(
                                        context, kProgressTabIndex),
                              ),
                            ),
                          );
                        },
                      )
                          .animate()
                          .fadeIn(delay: 80.ms, duration: 500.ms)
                          .slideY(
                              begin: 0.06, end: 0,
                              curve: Curves.easeOutCubic),
                      const SizedBox(height: 18),
                      _MoodHeroCard(
                        mood: _mood,
                        energy: _energy,
                        focus: _focus,
                        savedFlash: _savedFlash,
                        onMood: (v) => _onSliderChange(() => _mood = v),
                        onEnergy: (v) =>
                            _onSliderChange(() => _energy = v),
                        onFocus: (v) =>
                            _onSliderChange(() => _focus = v),
                      )
                          .animate()
                          .fadeIn(delay: 150.ms, duration: 500.ms)
                          .slideY(
                              begin: 0.06, end: 0,
                              curve: Curves.easeOutCubic),
                      if (_suggestionLoaded && _suggestion != null) ...[
                        const SizedBox(height: 18),
                        AdaptiveSuggestionCard(
                          suggestion: _suggestion!,
                          applying: _applyingSuggestion,
                          onApply: _applySuggestion,
                          onDismiss: _dismissSuggestion,
                        )
                            .animate()
                            .fadeIn(delay: 220.ms, duration: 500.ms)
                            .slideY(
                                begin: 0.05,
                                end: 0,
                                curve: Curves.easeOut),
                      ],
                      const SizedBox(height: 28),
                      ValueListenableBuilder<Box<Habit>>(
                        valueListenable: _habits.watchHabits(),
                        builder: (context, _, _) =>
                            ValueListenableBuilder<Box<HabitLog>>(
                          valueListenable: _habits.watchLogs(),
                          builder: (context, _, _) => _TodayHabits(
                            habits: _habits
                                .getHabitsForDate(DateTime.now())
                                .take(3)
                                .toList(),
                            repo: _habits,
                            onSeeAll: () => MainNavigation.goToTab(
                                context, kHabitsTabIndex),
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 400.ms, duration: 500.ms)
                          .slideY(
                              begin: 0.1, end: 0, curve: Curves.easeOutCubic),
                      const SizedBox(height: 28),
                      ValueListenableBuilder<Box<RoutineItem>>(
                        valueListenable: _routines.watchRoutines(),
                        builder: (context, _, _) => _UpNextSection(
                          routines: _routines.getTodayRoutines(),
                          currentId: _routines.getCurrentRoutine()?.id,
                          onToggle: _toggleRoutine,
                          onSeeAll: () => MainNavigation.goToTab(
                              context, kRoutineTabIndex),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 450.ms, duration: 500.ms)
                          .slideY(
                              begin: 0.1, end: 0, curve: Curves.easeOutCubic),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }


  Future<void> _confirmReset(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrandColors.bgCard(context),
        title: Text('Reset onboarding?',
            style: TextStyle(color: BrandColors.ink(context))),
        content: Text(
          'This clears your profile and routines so you can run onboarding again.',
          style: TextStyle(color: BrandColors.inkSoft(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset',
                style: TextStyle(color: Color(0xFFFF6B81))),
          ),
        ],
      ),
    );
    if (ok == true) {
      await OnboardingService().reset();
    }
  }

  static const Set<int> _kStreakMilestones = {3, 7, 30, 100, 365};

}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -80,
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.purple.withValues(alpha: 0.30),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              left: -100,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.pink.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Clean two-row header.
/// Row 1: greeting + name on the left, "+" + avatar on the right.
/// Row 2: compact streak chip + freeze badge.
class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.streak,
    required this.profile,
    required this.onLongPressName,
    required this.onOpenSettings,
    required this.onAddTap,
  });

  final String name;
  final int streak;
  final UserProfile? profile;
  final VoidCallback onLongPressName;
  final VoidCallback onOpenSettings;
  final VoidCallback onAddTap;

  String _firstName(String full) {
    final t = full.trim();
    if (t.isEmpty) return 'friend';
    final parts = t.split(RegExp(r'\s+'));
    return parts.first;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: GestureDetector(
                onLongPress: onLongPressName,
                behavior: HitTestBehavior.opaque,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: brandFont(
                        color: BrandColors.ink(context),
                        fontSize: 30,
                        weight: FontWeight.w800,
                        height: 1.05,
                        letterSpacing: -0.6,
                      ),
                      children: [
                        const TextSpan(text: 'Hi '),
                        TextSpan(
                          text: _firstName(name),
                          style: brandFont(
                            fontSize: 30,
                            weight: FontWeight.w800,
                            height: 1.05,
                            letterSpacing: -0.6,
                            foreground: Paint()
                              ..shader = AppColors.primaryGradient
                                  .createShader(const Rect.fromLTWH(
                                      0, 0, 220, 40)),
                          ),
                        ),
                        const TextSpan(text: ' 👋'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _HeaderAddButton(onTap: onAddTap),
            const SizedBox(width: 10),
            ColorAvatar(
              key: TutorialTargets.settingsButton,
              name: name,
              size: 38,
              onTap: onOpenSettings,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppColors.softGradient,
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: AppColors.purple.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🔥', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    '$streak day streak',
                    style: TextStyle(
                      color: BrandColors.inkSoft(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (profile != null) ...[
              const SizedBox(width: 8),
              FreezeBadge(
                count: profile!.freezesAvailable,
                profile: profile,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _HeaderAddButton extends StatelessWidget {
  const _HeaderAddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.buttonGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.pink.withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded,
            color: Colors.white, size: 22),
      ),
    );
  }
}

/// Bottom sheet from the header "+" button.
class _HomeAddSheet extends StatelessWidget {
  const _HomeAddSheet({
    required this.onIntention,
    required this.onGratitude,
  });
  final VoidCallback onIntention;
  final VoidCallback onGratitude;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                BrandColors.bgCard(context),
                BrandColors.bg(context),
              ],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: AppColors.purple.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.purple.withValues(alpha: 0.22),
                blurRadius: 30,
                spreadRadius: -8,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: BrandColors.inkFaint(context),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Add to today',
                style: brandFont(
                  color: BrandColors.ink(context),
                  fontSize: 22,
                  weight: FontWeight.w800,
                  height: 1.05,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 14),
              _AddTile(
                icon: Icons.wb_sunny_rounded,
                title: "Today's intention",
                subtitle:
                    'Set the one thing that would make today great.',
                onTap: onIntention,
                accent: AppColors.pinkLight,
              ),
              const SizedBox(height: 10),
              _AddTile(
                icon: Icons.favorite_rounded,
                title: "Today's gratitude",
                subtitle: 'Log what you’re grateful for today.',
                onTap: onGratitude,
                accent: AppColors.purpleLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.accent,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: BrandColors.bg(context).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accent.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.18),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.45),
                  ),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: BrandColors.ink(context),
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: BrandColors.inkSoft(context),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: BrandColors.inkSoft(context)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact check-in: heading + three sliders. No mood orb, no save
/// button — the parent owns a 2-second debounced auto-save that fires
/// when the user stops touching sliders. [savedFlash] briefly shows a
/// "Saved ✓" stamp in the header after each silent save.
class _MoodHeroCard extends StatelessWidget {
  const _MoodHeroCard({
    required this.mood,
    required this.energy,
    required this.focus,
    required this.onMood,
    required this.onEnergy,
    required this.onFocus,
    required this.savedFlash,
  });

  final double mood;
  final double energy;
  final double focus;
  final ValueChanged<double> onMood;
  final ValueChanged<double> onEnergy;
  final ValueChanged<double> onFocus;
  final bool savedFlash;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'How are you, right now?',
                  style: brandFont(
                    color: BrandColors.ink(context),
                    fontSize: 22,
                    weight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: savedFlash ? 1.0 : 0.0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.pinkLight.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded,
                          color: AppColors.pinkLight, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'Saved',
                        style: TextStyle(
                          color: AppColors.pinkLight,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            key: TutorialTargets.moodSliders,
            children: [
              GlowSlider(
                label: 'Mood',
                icon: Icons.favorite_rounded,
                value: mood,
                onChanged: onMood,
              ),
              const SizedBox(height: 10),
              GlowSlider(
                label: 'Energy',
                icon: Icons.bolt_rounded,
                value: energy,
                onChanged: onEnergy,
              ),
              const SizedBox(height: 10),
              GlowSlider(
                label: 'Focus',
                icon: Icons.center_focus_strong_rounded,
                value: focus,
                onChanged: onFocus,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.streak,
    required this.completedToday,
    required this.totalToday,
    required this.disciplineScore,
    required this.onTapDiscipline,
  });

  final int streak;
  final int completedToday;
  final int totalToday;
  final int disciplineScore;
  final VoidCallback onTapDiscipline;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            label: 'Streak',
            value: '$streak',
            emoji: '🔥',
            accent: AppColors.pinkLight,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            label: 'Today',
            value: '$completedToday / $totalToday',
            emoji: '⚡',
            accent: AppColors.blueAccent,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: onTapDiscipline,
            child: StatCard(
              label: 'Discipline',
              value: disciplineScore == 0 ? '—' : '$disciplineScore',
              emoji: '🏆',
              accent: AppColors.purpleLight,
            ),
          ),
        ),
      ],
    );
  }
}

class _UpNextSection extends StatelessWidget {
  const _UpNextSection({
    required this.routines,
    required this.currentId,
    required this.onToggle,
    required this.onSeeAll,
  });

  final List<RoutineItem> routines;
  final String? currentId;
  final void Function(RoutineItem) onToggle;
  final VoidCallback onSeeAll;

  static final DateFormat _timeFmt = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    final visible = routines.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 14),
          child: Row(
            children: [
              Text(
                'Up next',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              GestureDetector(
                onTap: onSeeAll,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 4),
                  child: Text(
                    'See all',
                    style: TextStyle(
                      color: AppColors.purpleLight,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (visible.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'No routines yet.',
              style: TextStyle(color: BrandColors.inkDim(context), fontSize: 13),
            ),
          )
        else
          for (var i = 0; i < visible.length; i++) ...[
            RoutineCard(
              time: _timeFmt.format(visible[i].time),
              title: visible[i].title,
              subtitle: visible[i].meta,
              icon: visible[i].category.icon,
              isNow: visible[i].id == currentId,
              isCompleted: visible[i].isCompleted,
              onTap: () => onToggle(visible[i]),
            ),
            if (i < visible.length - 1) const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _TodayHabits extends StatelessWidget {
  const _TodayHabits({
    required this.habits,
    required this.repo,
    required this.onSeeAll,
  });

  final List<Habit> habits;
  final HabitRepository repo;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    if (habits.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 12),
          child: Row(
            children: [
              Text(
                "Today's habits",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              GestureDetector(
                onTap: onSeeAll,
                child: Text(
                  'See all',
                  style: TextStyle(
                    color: AppColors.purpleLight,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < habits.length; i++) ...[
          _MiniHabitRow(habit: habits[i], repo: repo),
          if (i < habits.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _MiniHabitRow extends StatelessWidget {
  const _MiniHabitRow({required this.habit, required this.repo});
  final Habit habit;
  final HabitRepository repo;

  @override
  Widget build(BuildContext context) {
    final color = Color(habit.color);
    final todayValue = repo.getLogForDate(habit.id, DateTime.now())?.value ?? 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HabitDetailScreen(habitId: habit.id),
          ),
        ),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          decoration: BoxDecoration(
            color: BrandColors.bgCard(context).withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: color.withValues(alpha: 0.20),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      color.withValues(alpha: 0.55),
                      color.withValues(alpha: 0.12),
                    ],
                  ),
                ),
                child: Text(habit.icon,
                    style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  habit.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: BrandColors.ink(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              HabitLogButton(
                habit: habit,
                value: todayValue,
                compact: true,
                onIncrement: () {
                  final step = habit.targetUnit
                              ?.toLowerCase()
                              .contains('minute') ==
                          true
                      ? 5
                      : 1;
                  repo.incrementLog(habitId: habit.id, by: step);
                },
                onDecrement: () {
                  final step = habit.targetUnit
                              ?.toLowerCase()
                              .contains('minute') ==
                          true
                      ? 5
                      : 1;
                  repo.incrementLog(habitId: habit.id, by: -step);
                },
                onToggle: () => repo.toggleYesNoLog(habitId: habit.id),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReflectionNudge extends StatelessWidget {
  const _ReflectionNudge({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.purple.withValues(alpha: 0.18),
                AppColors.pink.withValues(alpha: 0.10),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.pinkLight.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.orbGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.pink.withValues(alpha: 0.40),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Tonight's reflection is ready",
                      style: TextStyle(
                        color: BrandColors.ink(context),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Mood8 will read your day and write you a note.',
                      style: TextStyle(
                        color: BrandColors.inkDim(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_rounded,
                  color: AppColors.pinkLight, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatternsCarousel extends StatelessWidget {
  const _PatternsCarousel({
    required this.alerts,
    required this.onAction,
    required this.onDismiss,
    required this.onSeeAll,
  });

  final List<PatternAlert> alerts;
  final void Function(PatternAlert) onAction;
  final void Function(PatternAlert) onDismiss;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, right: 4, bottom: 10),
          child: Row(
            children: [
              Text(
                'PATTERNS NOTICED',
                style: TextStyle(
                  color: BrandColors.inkDim(context),
                  fontSize: 10,
                  letterSpacing: 1.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onSeeAll,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  'See all',
                  style: TextStyle(
                    color: AppColors.purpleLight,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < alerts.length; i++) ...[
          PatternAlertCard(
            alert: alerts[i],
            onAction: () => onAction(alerts[i]),
            onDismiss: () => onDismiss(alerts[i]),
          ),
          if (i < alerts.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _GuestNudgeBanner extends StatelessWidget {
  const _GuestNudgeBanner({required this.onTap, required this.onDismiss});
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.blueAccent.withValues(alpha: 0.30),
                AppColors.purple.withValues(alpha: 0.20),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.blueAccent.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.blueAccent.withValues(alpha: 0.28),
                blurRadius: 20,
                spreadRadius: -6,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.blueAccent.withValues(alpha: 0.85),
                      AppColors.purple.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.cloud_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GUEST ACCOUNT',
                      style: TextStyle(
                        color: AppColors.blueAccent,
                        fontSize: 10,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Register to keep your data safe',
                      style: GoogleFonts.bricolageGrotesque(
                        color: BrandColors.ink(context),
                        fontSize: 18,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Without an account, uninstalling Mood8 loses everything.",
                      style: TextStyle(
                        color: BrandColors.inkDim(context),
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.blueAccent,
                size: 18,
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: onDismiss,
                icon: Icon(
                  Icons.close_rounded,
                  color: BrandColors.inkDim(context),
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecapBanner extends StatelessWidget {
  const _RecapBanner({required this.onTap, required this.onDismiss});
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.purple.withValues(alpha: 0.30),
                AppColors.pink.withValues(alpha: 0.18),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.pinkLight.withValues(alpha: 0.50),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.pink.withValues(alpha: 0.30),
                blurRadius: 22,
                spreadRadius: -6,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.pinkLight.withValues(alpha: 0.90),
                      AppColors.purple.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WEEKLY RECAP',
                      style: TextStyle(
                        color: AppColors.pinkLight,
                        fontSize: 10,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Your week is ready',
                      style: GoogleFonts.bricolageGrotesque(
                        color: BrandColors.ink(context),
                        fontSize: 18,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.pinkLight,
                size: 18,
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: onDismiss,
                icon: Icon(
                  Icons.close_rounded,
                  color: BrandColors.inkDim(context),
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _YirBanner extends StatelessWidget {
  const _YirBanner({required this.onTap, required this.onDismiss});
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final year = DateTime.now().year;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.purple.withValues(alpha: 0.45),
                AppColors.pink.withValues(alpha: 0.30),
                AppColors.blueAccent.withValues(alpha: 0.25),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.purpleLight.withValues(alpha: 0.55),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.purple.withValues(alpha: 0.32),
                blurRadius: 26,
                spreadRadius: -6,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.orbGradient,
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'YEAR IN REVIEW',
                      style: TextStyle(
                        color: AppColors.pinkLight,
                        fontSize: 10,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Your $year is ready ✨',
                      style: GoogleFonts.bricolageGrotesque(
                        color: BrandColors.ink(context),
                        fontSize: 18,
                        height: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.pinkLight,
                size: 18,
              ),
              IconButton(
                tooltip: 'Dismiss',
                onPressed: onDismiss,
                icon: Icon(
                  Icons.close_rounded,
                  color: BrandColors.inkDim(context),
                  size: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

