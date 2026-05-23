import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../main.dart' show AuthGate;
import '../models/auth_user.dart';
import '../models/effects_intensity.dart';
import '../models/sfx_type.dart';
import '../models/user_profile.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../services/badge_service.dart';
import '../services/effects_service.dart';
import '../services/feedback_service.dart';
import '../services/haptic_service.dart';
import '../services/notification_service.dart';
import '../services/onboarding_service.dart';
import '../services/preferences_service.dart';
import '../services/sfx_service.dart';
import '../services/subscription_service.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/feedback_dialog.dart';
import '../widgets/premium_badge.dart';
import '../widgets/responsive_container.dart';
import '../widgets/settings/color_avatar.dart';
import '../widgets/settings/settings_dropdown.dart';
import '../widgets/settings/settings_section.dart';
import '../widgets/settings/settings_tile.dart';
import 'badges_screen.dart';
import 'past_recaps_screen.dart';
import 'patterns_screen.dart';
import 'paywall_screen.dart';
import 'premium_screen.dart';
import 'share_progress_screen.dart';
import 'year_in_review_screen.dart';
import 'challenges/challenges_list_screen.dart';
import 'challenges/my_challenges_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'reminder_settings_screen.dart';
import '../services/sync_service.dart';
import 'auth/register_screen.dart';
import '../widgets/tutorial_overlay.dart';
import '../models/reminder_settings.dart';
import '../services/reminder_service.dart';
import '../services/weekly_recap_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../widgets/settings/settings_toggle.dart';
import 'settings/about_screen.dart';
import 'settings/data_privacy_screen.dart';
import '../services/badge_definitions.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final UserRepository _users = UserRepository();
  final PreferencesService _prefs = PreferencesService.instance;

  late final ValueListenable<Box<UserProfile>> _userListenable =
      _users.watchUser();

  int _versionTaps = 0;
  bool _devUnlocked = false;
  DateTime _lastVersionTap = DateTime.fromMillisecondsSinceEpoch(0);

  final SfxService _sfx = SfxService();
  final HapticService _haptic = HapticService();
  final EffectsService _effects = EffectsService();

  @override
  void initState() {
    super.initState();
    _prefs.addListener(_onPrefs);
    _sfx.addListener(_onPrefs);
    _haptic.addListener(_onPrefs);
    _effects.addListener(_onPrefs);
    _prefs.load();
  }

  @override
  void dispose() {
    _prefs.removeListener(_onPrefs);
    _sfx.removeListener(_onPrefs);
    _haptic.removeListener(_onPrefs);
    _effects.removeListener(_onPrefs);
    super.dispose();
  }

  void _onPrefs() {
    if (mounted) setState(() {});
  }

  bool? _weeklyRecapEnabled; // null = unknown / not loaded yet
  bool _weeklyRecapToggleInFlight = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadWeeklyRecapPref();
  }

  bool _weeklyRecapLoadAttempted = false;

  Future<void> _loadWeeklyRecapPref() async {
    // didChangeDependencies fires more than once; only attempt the load
    // once per screen instance to avoid duplicate network calls.
    if (_weeklyRecapLoadAttempted) return;
    _weeklyRecapLoadAttempted = true;

    final token = AuthService().token;
    if (token == null) {
      // Bypass-auth user — no backend pref to sync. Default to enabled
      // locally so the toggle becomes interactive immediately.
      if (mounted) setState(() => _weeklyRecapEnabled = true);
      return;
    }
    try {
      final res = await http.get(
        Uri.parse('https://mood8.app/api/auth/me'),
        headers: {'authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            _weeklyRecapEnabled =
                body['weekly_recap_enabled'] as bool? ?? true;
          });
        }
        return;
      }
    } catch (_) {/* fall through */}
    // Failure path: default to enabled optimistically so the toggle is
    // never stuck on "Loading…". The first successful save will sync to
    // the server.
    if (mounted) setState(() => _weeklyRecapEnabled = true);
  }

  Future<void> _setWeeklyRecapEnabled(bool value) async {
    if (_weeklyRecapToggleInFlight) return;
    // Optimistic UI: flip locally first, sync after.
    setState(() {
      _weeklyRecapToggleInFlight = true;
      _weeklyRecapEnabled = value;
    });
    final token = AuthService().token;
    if (token == null) {
      // Bypass-auth user — no backend to sync to. Local-only state.
      if (mounted) setState(() => _weeklyRecapToggleInFlight = false);
      return;
    }
    try {
      final res = await http.post(
        Uri.parse('https://mood8.app/api/user/preferences'),
        headers: {
          'authorization': 'Bearer $token',
          'content-type': 'application/json',
        },
        body: jsonEncode({'weekly_recap_enabled': value}),
      ).timeout(const Duration(seconds: 10));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        if (mounted) setState(() => _weeklyRecapEnabled = !value);
        _showRecapToggleError();
      }
    } catch (_) {
      if (mounted) setState(() => _weeklyRecapEnabled = !value);
      _showRecapToggleError();
    } finally {
      if (mounted) {
        setState(() => _weeklyRecapToggleInFlight = false);
      }
    }
  }

  void _showRecapToggleError() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Couldn't save that — check your connection."),
      ),
    );
  }

  Future<void> _confirmRestoreFromCloud() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrandColors.bgCard(context),
        title: Text(
          'Restore from cloud?',
          style: TextStyle(color: BrandColors.ink(context)),
        ),
        content: Text(
          'This re-downloads all your data from the server. Anything on '
          'this device that hasn\'t synced yet will be lost. '
          "It's safe to use if your data ever looks wrong.",
          style: TextStyle(color: BrandColors.inkSoft(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Restore',
              style: TextStyle(color: AppColors.pinkLight),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    // Show progress via a tiny modal sheet.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: SizedBox(
          width: 36,
          height: 36,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      ),
    );
    try {
      final applied = await SyncService().fullRestore();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restored $applied records from cloud.')),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Restore failed: $e')),
      );
    }
  }

  Future<void> _openBillingPortal() async {
    final url = await SubscriptionService().openBillingPortal();
    if (!mounted) return;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Couldn't open billing portal. Try again.")),
      );
      return;
    }
    await launchUrl(Uri.parse(url),
        mode: LaunchMode.platformDefault, webOnlyWindowName: '_self');
  }

  Future<void> _playAllSounds() async {
    for (final t in SfxType.values) {
      _sfx.fire(t);
      await Future<void>.delayed(const Duration(milliseconds: 750));
    }
  }

  void _bumpVersionTaps() {
    final now = DateTime.now();
    if (now.difference(_lastVersionTap) > const Duration(seconds: 3)) {
      _versionTaps = 0;
    }
    _lastVersionTap = now;
    _versionTaps += 1;
    if (_versionTaps >= 7 && !_devUnlocked) {
      HapticFeedback.heavyImpact();
      setState(() => _devUnlocked = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Developer tools unlocked.'),
          backgroundColor: BrandColors.bgCard(context),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: BrandColors.inkSoft(context), size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Settings',
            style: Theme.of(context).textTheme.headlineSmall),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 560,
          child: ValueListenableBuilder<Box<UserProfile>>(
            valueListenable: _userListenable,
            builder: (context, userBox, _) {
              final user = userBox.get(UserRepository.userKey);
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProfileCard(user: user, onEditName: _editName),
                    SettingsSection(
                      title: 'App preferences',
                      children: [
                        SettingsDropdown<AppThemeMode>(
                          icon: Icons.brightness_6_rounded,
                          title: 'Theme',
                          value: _prefs.themeMode,
                          options: const [
                            DropdownOption(
                              value: AppThemeMode.dark,
                              label: 'Dark',
                              subtitle: 'The Mood8 default',
                            ),
                            DropdownOption(
                              value: AppThemeMode.light,
                              label: 'Light',
                              subtitle: 'Creamy lavender · early preview',
                            ),
                            DropdownOption(
                              value: AppThemeMode.system,
                              label: 'Auto',
                              subtitle: 'Follow device setting',
                            ),
                          ],
                          onChanged: (v) => _prefs.setThemeMode(v),
                        ),
                        SettingsTile(
                          icon: Icons.language_rounded,
                          title: 'Language',
                          trailing: const Text('English'),
                          onTap: () => _comingSoon('Languages'),
                        ),
                        SettingsDropdown<TimeFormat>(
                          icon: Icons.schedule_rounded,
                          title: 'Time format',
                          value: _prefs.timeFormat,
                          options: const [
                            DropdownOption(
                              value: TimeFormat.twentyFourHour,
                              label: '24-hour',
                            ),
                            DropdownOption(
                              value: TimeFormat.twelveHour,
                              label: '12-hour',
                            ),
                          ],
                          onChanged: (v) => _prefs.setTimeFormat(v),
                        ),
                        SettingsDropdown<WeekStart>(
                          icon: Icons.calendar_view_week_rounded,
                          title: 'Week starts on',
                          value: _prefs.weekStart,
                          options: const [
                            DropdownOption(
                              value: WeekStart.monday,
                              label: 'Monday',
                            ),
                            DropdownOption(
                              value: WeekStart.sunday,
                              label: 'Sunday',
                            ),
                          ],
                          onChanged: (v) => _prefs.setWeekStart(v),
                        ),
                        SettingsTile(
                          icon: Icons.alarm_rounded,
                          title: 'Default check-in time',
                          trailing: Text(
                              _prefs.checkinTime.format(_prefs.timeFormat)),
                          onTap: _editCheckinTime,
                        ),
                        SettingsToggle(
                          icon: Icons.wb_sunny_rounded,
                          title: 'Morning intention prompt',
                          subtitle:
                              'Ask once each morning what would make today great',
                          value: _prefs.showMorningIntention,
                          onChanged: (v) =>
                              _prefs.setShowMorningIntention(v),
                        ),
                        SettingsToggle(
                          icon: Icons.favorite_rounded,
                          title: 'Gratitude card on home',
                          subtitle:
                              'Quick access to log three things each day',
                          value: _prefs.showGratitudeCard,
                          onChanged: (v) =>
                              _prefs.setShowGratitudeCard(v),
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: 'Notifications',
                      subtitle: NotificationService().isSupported
                          ? (NotificationService().isGranted
                              ? 'enabled'
                              : 'tap to allow')
                          : 'web only',
                      children: [
                        ValueListenableBuilder<Box<ReminderSettings>>(
                          valueListenable: ReminderService().watch(),
                          builder: (context, box, _) {
                            final s = box.get(ReminderSettings.boxKey);
                            final subtitle = s == null || !s.enabled
                                ? 'Off'
                                : '${s.reminderTimes.length} reminder${s.reminderTimes.length == 1 ? '' : 's'} daily';
                            return SettingsTile(
                              icon: Icons.notifications_active_rounded,
                              title: 'Smart reminders',
                              subtitle: subtitle,
                              onTap: () =>
                                  Navigator.of(context).push(MaterialPageRoute(
                                builder: (_) =>
                                    const ReminderSettingsScreen(),
                              )),
                            );
                          },
                        ),
                        SettingsTile(
                          icon: Icons.notifications_active_rounded,
                          title: NotificationService().isGranted
                              ? 'Send a test notification'
                              : 'Enable notifications',
                          subtitle: NotificationService().isSupported
                              ? 'Browser permission · web'
                              : 'Coming to mobile soon',
                          onTap: NotificationService().isSupported
                              ? _onTestNotification
                              : null,
                        ),
                        SettingsToggle(
                          icon: Icons.mail_outline_rounded,
                          title: 'Weekly recap email',
                          subtitle: _weeklyRecapEnabled == null
                              ? 'Loading…'
                              : (_weeklyRecapEnabled!
                                  ? 'Sundays · AI-generated summary'
                                  : 'Off'),
                          value: _weeklyRecapEnabled ?? true,
                          onChanged: _weeklyRecapEnabled == null
                              ? (_) {}
                              : (v) => _setWeeklyRecapEnabled(v),
                        ),
                        SettingsTile(
                          icon: Icons.menu_book_rounded,
                          title: 'Past recaps',
                          subtitle:
                              '${WeeklyRecapService().getAll().length} saved',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PastRecapsScreen(),
                            ),
                          ),
                        ),
                        SettingsTile(
                          icon: Icons.wb_twilight_rounded,
                          title: 'Schedule morning check-in',
                          subtitle: NotificationService().isGranted
                              ? 'Tap to schedule for 09:00'
                              : 'Allow notifications first',
                          onTap: NotificationService().isGranted
                              ? _scheduleMorning
                              : null,
                        ),
                        SettingsTile(
                          icon: Icons.nightlight_round,
                          title: 'Schedule evening reflection',
                          subtitle: NotificationService().isGranted
                              ? 'Tap to schedule for 21:00'
                              : 'Allow notifications first',
                          onTap: NotificationService().isGranted
                              ? _scheduleEvening
                              : null,
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: 'Pattern alerts',
                      subtitle: 'gentle, opt-in observations',
                      children: [
                        SettingsToggle(
                          icon: Icons.insights_rounded,
                          title: 'Pattern alerts',
                          subtitle:
                              'Mood8 notices things and gently surfaces them',
                          value: _prefs.patternAlertsEnabled,
                          onChanged: (v) =>
                              _prefs.setPatternAlertsEnabled(v),
                        ),
                        SettingsToggle(
                          icon: Icons.local_fire_department_rounded,
                          title: 'Streaks',
                          value: _prefs.patternStreaksEnabled,
                          onChanged: (v) => _prefs
                              .setPatternCategoryEnabled(_prefs.streaksKey, v),
                        ),
                        SettingsToggle(
                          icon: Icons.favorite_rounded,
                          title: 'Mood correlations',
                          value: _prefs.patternMoodEnabled,
                          onChanged: (v) => _prefs
                              .setPatternCategoryEnabled(_prefs.moodKey, v),
                        ),
                        SettingsToggle(
                          icon: Icons.calendar_view_week_rounded,
                          title: 'Day-of-week patterns',
                          value: _prefs.patternDayOfWeekEnabled,
                          onChanged: (v) => _prefs
                              .setPatternCategoryEnabled(_prefs.dayOfWeekKey, v),
                        ),
                        SettingsToggle(
                          icon: Icons.trending_up_rounded,
                          title: 'Growth observations',
                          value: _prefs.patternGrowthEnabled,
                          onChanged: (v) => _prefs
                              .setPatternCategoryEnabled(_prefs.growthKey, v),
                        ),
                        SettingsToggle(
                          icon: Icons.favorite_border_rounded,
                          title: 'Gentle check-ins',
                          subtitle:
                              'Soft nudges when things look off (opt-out anytime)',
                          value: _prefs.patternCheckInsEnabled,
                          onChanged: (v) => _prefs
                              .setPatternCategoryEnabled(_prefs.checkInsKey, v),
                        ),
                        SettingsToggle(
                          icon: Icons.notifications_active_rounded,
                          title: 'Pattern notifications',
                          subtitle:
                              'Push high-relevance patterns (≤ 1 per week)',
                          value: _prefs.patternNotificationsEnabled,
                          onChanged: (v) => _prefs
                              .setPatternCategoryEnabled(
                                  _prefs.notificationsKey, v),
                        ),
                        SettingsTile(
                          icon: Icons.menu_open_rounded,
                          title: 'View patterns history',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PatternsScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: 'AI Coach',
                      children: [
                        SettingsDropdown<CoachPersonality>(
                          icon: Icons.auto_awesome_rounded,
                          title: 'Coach personality',
                          value: _prefs.coachPersonality,
                          options: const [
                            DropdownOption(
                              value: CoachPersonality.warm,
                              label: 'Warm',
                              subtitle: 'Encouraging and personal',
                            ),
                            DropdownOption(
                              value: CoachPersonality.direct,
                              label: 'Direct',
                              subtitle: 'Short and honest',
                            ),
                            DropdownOption(
                              value: CoachPersonality.analytical,
                              label: 'Analytical',
                              subtitle: 'Focused on numbers and patterns',
                            ),
                          ],
                          onChanged: (v) => _prefs.setCoachPersonality(v),
                        ),
                        SettingsTile(
                          icon: Icons.bedtime_rounded,
                          title: 'Reflection time',
                          trailing: Text(
                              _prefs.reflectionTime.format(_prefs.timeFormat)),
                          onTap: _editReflectionTime,
                        ),
                        SettingsToggle(
                          icon: Icons.lightbulb_outline_rounded,
                          title: 'AI insights',
                          subtitle: 'Use the coach to explain patterns',
                          value: _prefs.aiInsightsEnabled,
                          onChanged: (v) =>
                              _prefs.setAiInsightsEnabled(v),
                        ),
                        SettingsTile(
                          icon: Icons.info_outline_rounded,
                          title: 'AI privacy',
                          subtitle:
                              'Reflections, chat, and insights are sent to the Mood8 coach API.',
                          onTap: () => _comingSoon('Privacy details'),
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: 'Sound & haptics',
                      children: [
                        SettingsToggle(
                          icon: Icons.volume_up_rounded,
                          title: 'Sound effects',
                          subtitle: 'Calming chimes for key moments',
                          value: _sfx.isEnabled,
                          onChanged: (v) => _sfx.setEnabled(v),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(14, 4, 14, 8),
                          child: Row(
                            children: [
                              Icon(Icons.volume_down_rounded,
                                  color: BrandColors.inkDim(context), size: 16),
                              Expanded(
                                child: Slider(
                                  value: _sfx.volume,
                                  onChanged: _sfx.isEnabled
                                      ? (v) => _sfx.setVolume(v)
                                      : null,
                                  activeColor: AppColors.pinkLight,
                                  inactiveColor: BrandColors.bg(context),
                                ),
                              ),
                              SizedBox(
                                width: 40,
                                child: Text(
                                  '${(_sfx.volume * 100).round()}%',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: BrandColors.inkSoft(context),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SettingsToggle(
                          icon: Icons.vibration_rounded,
                          title: 'Haptic feedback',
                          subtitle: 'Gentle taps on important actions',
                          value: _haptic.isEnabled,
                          onChanged: (v) => _haptic.setEnabled(v),
                        ),
                        SettingsTile(
                          icon: Icons.music_note_rounded,
                          title: 'Test sound',
                          subtitle: 'Play check-in chime',
                          onTap: () => _sfx.fire(SfxType.checkInSuccess),
                        ),
                        SettingsTile(
                          icon: Icons.queue_music_rounded,
                          title: 'Test all sounds',
                          subtitle:
                              'Play every effect (≈8 s) — confirms autoplay unlocked',
                          onTap: _playAllSounds,
                        ),
                        SettingsTile(
                          icon: Icons.touch_app_rounded,
                          title: 'Test haptic',
                          subtitle: 'Trigger medium impact',
                          onTap: () => _haptic.medium(),
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: 'Effects & animations',
                      children: [
                        SettingsDropdown<EffectsIntensity>(
                          icon: Icons.auto_awesome_motion_rounded,
                          title: 'Effects intensity',
                          value: _effects.intensity,
                          options: [
                            for (final i in EffectsIntensity.values)
                              DropdownOption(
                                value: i,
                                label: i.label,
                                subtitle: i.description,
                              ),
                          ],
                          onChanged: (v) => _effects.setIntensity(v),
                        ),
                        SettingsToggle(
                          icon: Icons.celebration_rounded,
                          title: 'Celebrate milestones',
                          subtitle: '7, 30, 100, 365 days · identity unlocks',
                          value: _effects.celebrateMilestones,
                          onChanged: (v) =>
                              _effects.setCelebrateMilestones(v),
                        ),
                        SettingsToggle(
                          icon: Icons.battery_saver_rounded,
                          title: 'Quiet on battery saver',
                          subtitle: 'Reduce effects when battery is low',
                          value: _effects.batterySaverAware,
                          onChanged: (v) =>
                              _effects.setBatterySaverAware(v),
                        ),
                        SettingsTile(
                          icon: Icons.auto_awesome_rounded,
                          title: 'Test effects',
                          subtitle: 'Subtle · notable · milestone',
                          onTap: _testEffects,
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: 'Challenges',
                      children: [
                        SettingsTile(
                          icon: Icons.flag_rounded,
                          title: 'Browse challenges',
                          subtitle: 'Discover or create a group challenge',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ChallengesListScreen(),
                            ),
                          ),
                        ),
                        SettingsTile(
                          icon: Icons.bookmark_rounded,
                          title: 'My challenges',
                          subtitle:
                              'Ones you’ve created or joined',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const MyChallengesScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: 'Data & privacy',
                      children: [
                        SettingsTile(
                          icon: Icons.auto_stories_rounded,
                          title: 'Your Year in Review',
                          subtitle:
                              'A swipeable look back at your year on Mood8',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const YearInReviewScreen(),
                            ),
                          ),
                        ),
                        SettingsTile(
                          icon: Icons.ios_share_rounded,
                          title: 'Share my progress',
                          subtitle:
                              'A beautiful card for your story or feed',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ShareProgressScreen(),
                            ),
                          ),
                        ),
                        SettingsTile(
                          icon: Icons.shield_outlined,
                          title: 'Data & privacy',
                          subtitle:
                              'Export, snapshot, and danger zone',
                          onTap: () =>
                              Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const DataPrivacyScreen(),
                          )),
                        ),
                        SettingsTile(
                          icon: Icons.cloud_download_rounded,
                          title: 'Restore from cloud',
                          subtitle:
                              'Re-download all your data from the server',
                          onTap: _confirmRestoreFromCloud,
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: 'Account',
                      children: [
                        ValueListenableBuilder<AuthUser?>(
                          valueListenable:
                              AuthService().currentUserNotifier,
                          builder: (context, authUser, _) {
                            if (authUser != null && authUser.isGuest) {
                              return SettingsTile(
                                icon: Icons.cloud_outlined,
                                title: 'Register your account',
                                subtitle:
                                    "You're using Mood8 as a guest — "
                                    'register to keep your data safe across devices',
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const RegisterScreen(),
                                  ),
                                ),
                              );
                            }
                            if (authUser != null) {
                              return SettingsTile(
                                icon: Icons.verified_user_outlined,
                                title: authUser.name.isEmpty
                                    ? authUser.email
                                    : authUser.name,
                                subtitle: 'Signed in · ${authUser.email}',
                                onTap: _confirmSignOut,
                              );
                            }
                            return SettingsTile(
                              icon: Icons.login_rounded,
                              title: 'Sign in',
                              subtitle:
                                  'Or create an account to sync later',
                              onTap: _goToWelcome,
                            );
                          },
                        ),
                        SettingsTile(
                          icon: Icons.sync_rounded,
                          title: 'Sync across devices',
                          subtitle: 'Coming soon',
                          onTap: () => _comingSoon('Sync'),
                        ),
                        SettingsTile(
                          icon: Icons.no_accounts_rounded,
                          title: 'Delete account',
                          subtitle:
                              'Removes all local data (account sync not enabled yet)',
                          destructive: true,
                          onTap: _confirmDeleteAccount,
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: 'Achievements',
                      children: [
                        SettingsTile(
                          icon: Icons.emoji_events_rounded,
                          title: 'Badges',
                          subtitle: 'See what you have earned',
                          trailing: Text(
                            '${BadgeService().earnedCount} / ${BadgeCatalog.count}',
                            style: TextStyle(
                              color: AppColors.pinkLight,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const BadgesScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: 'Membership',
                      children: [
                        if (SubscriptionService().isPremium)
                          SettingsTile(
                            icon: Icons.workspace_premium_rounded,
                            title: 'Mood8 Premium',
                            subtitle: 'Active',
                            trailing: PremiumBadge(
                              tier: SubscriptionService().tier,
                              compact: true,
                            ),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PremiumScreen(),
                              ),
                            ),
                          )
                        else
                          SettingsTile(
                            icon: Icons.workspace_premium_rounded,
                            title: 'Unlock Mood8 Premium',
                            subtitle:
                                'Unlimited habits, AI Coach, advanced insights',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PaywallScreen(),
                              ),
                            ),
                          ),
                        if (SubscriptionService().isPremium)
                          SettingsTile(
                            icon: Icons.credit_card_rounded,
                            title: 'Manage subscription',
                            subtitle: 'Cancel anytime via Stripe',
                            onTap: _openBillingPortal,
                          ),
                      ],
                    ),
                    SettingsSection(
                      title: 'Beta tester',
                      subtitle: 'we read every word',
                      children: [
                        SettingsTile(
                          icon: Icons.bug_report_outlined,
                          title: 'Report a bug',
                          onTap: () => showFeedbackDialog(
                            context,
                            initialKind: FeedbackKind.bug,
                          ),
                        ),
                        SettingsTile(
                          icon: Icons.lightbulb_outline_rounded,
                          title: 'Suggest a feature',
                          onTap: () => showFeedbackDialog(
                            context,
                            initialKind: FeedbackKind.feature,
                          ),
                        ),
                        SettingsTile(
                          icon: Icons.send_rounded,
                          title: 'Send general feedback',
                          subtitle: 'hello@mood8.app',
                          onTap: () => showFeedbackDialog(
                            context,
                            initialKind: FeedbackKind.general,
                          ),
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: 'About',
                      children: [
                        SettingsTile(
                          icon: Icons.info_outline_rounded,
                          title: 'About Mood8',
                          subtitle: 'Version, legal, contact',
                          onTap: () =>
                              Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const AboutScreen(),
                          )),
                        ),
                        SettingsTile(
                          icon: Icons.school_outlined,
                          title: 'Replay tutorial',
                          subtitle: 'Walk through the app again',
                          onTap: () async {
                            await resetTutorial();
                            if (!context.mounted) return;
                            showTutorial(context);
                          },
                        ),
                        SettingsTile(
                          icon: Icons.tag_rounded,
                          title: 'Version',
                          trailing: const Text('0.1.0'),
                          onTap: _bumpVersionTaps,
                        ),
                      ],
                    ),
                    if (_devUnlocked)
                      SettingsSection(
                        title: 'Developer',
                        subtitle: 'unlocked',
                        children: [
                          SettingsTile(
                            icon: Icons.restart_alt_rounded,
                            title: 'Reset onboarding',
                            subtitle: 'Clears profile/routines/habits',
                            onTap: _confirmResetOnboarding,
                          ),
                          SettingsTile(
                            icon: Icons.cleaning_services_rounded,
                            title: 'Clear analytics cache',
                            subtitle: 'Forces insights/progress to recompute',
                            onTap: () {
                              AnalyticsService().invalidate();
                              HapticFeedback.lightImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Analytics cache cleared.'),
                                  backgroundColor: BrandColors.bgCard(context),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                          SettingsTile(
                            icon: Icons.bug_report_outlined,
                            title: 'Show debug info',
                            onTap: () => _showDebugInfo(context, user),
                          ),
                          SettingsTile(
                            icon: Icons.error_outline_rounded,
                            title: 'Trigger test crash',
                            destructive: true,
                            onTap: () {
                              throw StateError('Mood8 test crash');
                            },
                          ),
                        ],
                      ),
                    const SizedBox(height: 28),
                    Center(
                      child: Text(
                        'Made with 💜 for people becoming.',
                        style: TextStyle(
                          color: BrandColors.inkDim(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _editName() async {
    final user = _users.getCurrentUser();
    final ctrl = TextEditingController(text: user?.name ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrandColors.bgCard(context),
        title: Text('Your name',
            style: TextStyle(color: BrandColors.ink(context))),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          cursorColor: AppColors.pinkLight,
          textCapitalization: TextCapitalization.words,
          style: TextStyle(color: BrandColors.ink(context)),
          decoration: InputDecoration(
            hintText: 'Your name',
            hintStyle: TextStyle(color: BrandColors.inkDim(context)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || user == null) return;
    user.name = newName;
    await _users.saveUser(user);
    HapticFeedback.lightImpact();
  }

  Future<void> _editCheckinTime() async {
    final v = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _prefs.checkinTime.hour,
        minute: _prefs.checkinTime.minute,
      ),
    );
    if (v == null) return;
    await _prefs.setCheckinTime(v.hour, v.minute);
  }

  Future<void> _editReflectionTime() async {
    final v = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _prefs.reflectionTime.hour,
        minute: _prefs.reflectionTime.minute,
      ),
    );
    if (v == null) return;
    await _prefs.setReflectionTime(v.hour, v.minute);
  }

  Future<void> _testEffects() async {
    _haptic.light();
    final user = _users.getCurrentUser();
    final size = MediaQuery.sizeOf(context);
    final origin = Offset(size.width / 2, size.height * 0.45);

    // 1. PremiumBloom — habit complete
    await _effects.celebrateHabitComplete(context: context, origin: origin);
    await Future<void>.delayed(
        _effects.intensity.durationScale > 0.9
            ? const Duration(milliseconds: 2400)
            : const Duration(milliseconds: 1400));
    if (!mounted) return;

    // 2. PhoenixRise — streak milestone
    await _effects.celebrateStreakMilestone(
      context: context,
      days: 7,
      flameOrigin: Offset(size.width / 2, size.height * 0.35),
    );
    await Future<void>.delayed(
        _effects.intensity.durationScale > 0.9
            ? const Duration(milliseconds: 3000)
            : const Duration(milliseconds: 1800));
    if (!mounted) return;

    // 3. IdentityConstellation — identity level-up
    await _effects.celebrateIdentityLevelUp(
      context: context,
      identity: 'Athlete',
      progress: 0.5,
    );
    await Future<void>.delayed(
        _effects.intensity.durationScale > 0.9
            ? const Duration(milliseconds: 3400)
            : const Duration(milliseconds: 2000));
    if (!mounted) return;

    // 4. CosmicBloom — perfect day finale
    await _effects.celebrateAllRoutinesComplete(
      context: context,
      userName: user?.name,
    );
  }

  void _comingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label is coming soon.'),
        backgroundColor: BrandColors.bgCard(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Future<void> _onTestNotification() async {
    final ok = await NotificationService().requestPermission();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Notification permission denied. Enable it in browser settings.'),
          backgroundColor: BrandColors.bgCard(context),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
      return;
    }
    await NotificationService().testNotification();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _scheduleMorning() async {
    final user = _users.getCurrentUser();
    await NotificationService().scheduleMorningCheckIn(
      name: user?.name ?? 'friend',
      hour: 9,
      minute: 0,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Morning reminder scheduled for 09:00.'),
        backgroundColor: BrandColors.bgCard(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Future<void> _scheduleEvening() async {
    await NotificationService().scheduleEveningReflection(
      hour: 21,
      minute: 0,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Evening reflection scheduled for 21:00.'),
        backgroundColor: BrandColors.bgCard(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Future<void> _goToWelcome() async {
    HapticService().selection();
    await AuthGate.resetAuth();
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _confirmSignOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrandColors.bgCard(context),
        title: Text('Sign out?',
            style: TextStyle(color: BrandColors.ink(context))),
        content: Text(
          "Your local data stays on this device.",
          style: TextStyle(color: BrandColors.inkSoft(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AuthGate.resetAuth();
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _confirmDeleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrandColors.bgCard(context),
        title: Text('Delete account?',
            style: TextStyle(color: BrandColors.ink(context))),
        content: Text(
          'Sync isn\'t enabled yet — this erases everything stored on this device. '
          'You can re-onboard right after.',
          style: TextStyle(color: BrandColors.inkSoft(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Continue',
                style: TextStyle(color: Color(0xFFFF6B81))),
          ),
        ],
      ),
    );
    if (ok != true) return;
    if (!mounted) return;
    final ok2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrandColors.bgCard(context),
        title: Text('Are you sure?',
            style: TextStyle(color: BrandColors.ink(context))),
        content: Text(
          'This cannot be undone.',
          style: TextStyle(color: BrandColors.inkSoft(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Yes, delete',
                style: TextStyle(color: Color(0xFFFF6B81))),
          ),
        ],
      ),
    );
    if (ok2 != true) return;
    await OnboardingService().reset();
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _confirmResetOnboarding() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrandColors.bgCard(context),
        title: Text('Reset onboarding?',
            style: TextStyle(color: BrandColors.ink(context))),
        content: Text(
          'Clears profile, routines, and habits.',
          style: TextStyle(color: BrandColors.inkSoft(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await OnboardingService().reset();
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _showDebugInfo(BuildContext context, UserProfile? user) {
    final info = StringBuffer()
      ..writeln('User: ${user?.name ?? '—'}')
      ..writeln('Identities: ${user?.identities.join(', ') ?? '—'}')
      ..writeln('Chronotype: ${user?.chronotype.name ?? '—'}')
      ..writeln('Theme: ${_prefs.themeMode.name}')
      ..writeln('TimeFormat: ${_prefs.timeFormat.name}')
      ..writeln('CoachPersonality: ${_prefs.coachPersonality.name}');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrandColors.bgCard(context),
        title: Text('Debug',
            style: TextStyle(color: BrandColors.ink(context))),
        content: SingleChildScrollView(
          child: Text(
            info.toString(),
            style: TextStyle(color: BrandColors.inkSoft(context), fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user, required this.onEditName});
  final UserProfile? user;
  final VoidCallback onEditName;

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? 'friend';
    final memberSince = user == null
        ? '—'
        : DateFormat.yMMMd().format(user!.createdAt);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.purple.withValues(alpha: 0.22),
            AppColors.pink.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.pinkLight.withValues(alpha: 0.40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ColorAvatar(name: name, size: 52, onTap: onEditName),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: onEditName,
                      child: Text(
                        name,
                        style: GoogleFonts.bricolageGrotesque(
                          color: BrandColors.ink(context),
                          fontSize: 24,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Member since $memberSince',
                      style: TextStyle(
                        color: BrandColors.inkDim(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEditName,
                tooltip: 'Edit name',
                icon: Icon(Icons.edit_outlined,
                    color: AppColors.purpleLight, size: 18),
              ),
            ],
          ),
          if (user != null && user!.identities.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final id in user!.identities)
                  _IdentityPill(label: id),
                _IdentityPill(label: 'Chronotype: ${user!.chronotype.label}'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _IdentityPill extends StatelessWidget {
  const _IdentityPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.purpleLight.withValues(alpha: 0.40),
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.bricolageGrotesque(
          color: BrandColors.ink(context),
          fontSize: 13,
        ),
      ),
    );
  }
}
