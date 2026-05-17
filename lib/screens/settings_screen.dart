import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/sfx_type.dart';
import '../models/user_profile.dart';
import '../services/analytics_service.dart';
import '../services/haptic_service.dart';
import '../services/onboarding_service.dart';
import '../services/preferences_service.dart';
import '../services/sfx_service.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_container.dart';
import '../widgets/settings/color_avatar.dart';
import '../widgets/settings/settings_dropdown.dart';
import '../widgets/settings/settings_section.dart';
import '../widgets/settings/settings_tile.dart';
import '../widgets/settings/settings_toggle.dart';
import 'settings/about_screen.dart';
import 'settings/data_privacy_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _prefs.addListener(_onPrefs);
    _sfx.addListener(_onPrefs);
    _haptic.addListener(_onPrefs);
    _prefs.load();
  }

  @override
  void dispose() {
    _prefs.removeListener(_onPrefs);
    _sfx.removeListener(_onPrefs);
    _haptic.removeListener(_onPrefs);
    super.dispose();
  }

  void _onPrefs() {
    if (mounted) setState(() {});
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
          backgroundColor: AppColors.bgCard,
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
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.inkSoft, size: 18),
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
                              subtitle: 'Coming soon',
                              disabled: true,
                            ),
                            DropdownOption(
                              value: AppThemeMode.system,
                              label: 'Auto',
                              subtitle: 'Match system',
                              disabled: true,
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
                      ],
                    ),
                    SettingsSection(
                      title: 'Notifications',
                      subtitle: 'coming soon',
                      children: [
                        SettingsToggle(
                          icon: Icons.wb_twilight_rounded,
                          title: 'Morning check-in reminder',
                          value: false,
                          disabled: true,
                          onChanged: null,
                        ),
                        SettingsToggle(
                          icon: Icons.nightlight_round,
                          title: 'Evening reflection reminder',
                          value: false,
                          disabled: true,
                          onChanged: null,
                        ),
                        SettingsToggle(
                          icon: Icons.local_fire_department_rounded,
                          title: 'Streak warnings',
                          value: false,
                          disabled: true,
                          onChanged: null,
                        ),
                        SettingsToggle(
                          icon: Icons.emoji_events_rounded,
                          title: 'Achievement notifications',
                          value: false,
                          disabled: true,
                          onChanged: null,
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
                                  color: AppColors.inkDim, size: 16),
                              Expanded(
                                child: Slider(
                                  value: _sfx.volume,
                                  onChanged: _sfx.isEnabled
                                      ? (v) => _sfx.setVolume(v)
                                      : null,
                                  activeColor: AppColors.pinkLight,
                                  inactiveColor: AppColors.bg,
                                ),
                              ),
                              SizedBox(
                                width: 40,
                                child: Text(
                                  '${(_sfx.volume * 100).round()}%',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    color: AppColors.inkSoft,
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
                          icon: Icons.touch_app_rounded,
                          title: 'Test haptic',
                          subtitle: 'Trigger medium impact',
                          onTap: () => _haptic.medium(),
                        ),
                      ],
                    ),
                    SettingsSection(
                      title: 'Data & privacy',
                      children: [
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
                      ],
                    ),
                    SettingsSection(
                      title: 'Account',
                      children: [
                        SettingsTile(
                          icon: Icons.login_rounded,
                          title: 'Sign in',
                          subtitle: 'Coming soon',
                          onTap: () => _comingSoon('Sign in'),
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
                                const SnackBar(
                                  content: Text('Analytics cache cleared.'),
                                  backgroundColor: AppColors.bgCard,
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
                          color: AppColors.inkDim,
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
        backgroundColor: AppColors.bgCard,
        title: const Text('Your name',
            style: TextStyle(color: AppColors.ink)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          cursorColor: AppColors.pinkLight,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: AppColors.ink),
          decoration: const InputDecoration(
            hintText: 'Your name',
            hintStyle: TextStyle(color: AppColors.inkDim),
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

  void _comingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label is coming soon.'),
        backgroundColor: AppColors.bgCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Delete account?',
            style: TextStyle(color: AppColors.ink)),
        content: const Text(
          'Sync isn\'t enabled yet — this erases everything stored on this device. '
          'You can re-onboard right after.',
          style: TextStyle(color: AppColors.inkSoft),
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
        backgroundColor: AppColors.bgCard,
        title: const Text('Are you sure?',
            style: TextStyle(color: AppColors.ink)),
        content: const Text(
          'This cannot be undone.',
          style: TextStyle(color: AppColors.inkSoft),
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
        backgroundColor: AppColors.bgCard,
        title: const Text('Reset onboarding?',
            style: TextStyle(color: AppColors.ink)),
        content: const Text(
          'Clears profile, routines, and habits.',
          style: TextStyle(color: AppColors.inkSoft),
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
        backgroundColor: AppColors.bgCard,
        title: const Text('Debug',
            style: TextStyle(color: AppColors.ink)),
        content: SingleChildScrollView(
          child: Text(
            info.toString(),
            style: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
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
                        style: GoogleFonts.instrumentSerif(
                          color: AppColors.ink,
                          fontStyle: FontStyle.italic,
                          fontSize: 24,
                          height: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Member since $memberSince',
                      style: TextStyle(
                        color: AppColors.inkDim,
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
        style: GoogleFonts.instrumentSerif(
          color: AppColors.ink,
          fontStyle: FontStyle.italic,
          fontSize: 13,
        ),
      ),
    );
  }
}
