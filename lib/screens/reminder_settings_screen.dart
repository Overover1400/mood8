import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/reminder_settings.dart';
import '../services/haptic_service.dart';
import '../services/notification_service.dart';
import '../services/reminder_service.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_container.dart';
import '../widgets/settings/settings_toggle.dart';

class ReminderSettingsScreen extends StatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  State<ReminderSettingsScreen> createState() =>
      _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends State<ReminderSettingsScreen> {
  final ReminderService _reminders = ReminderService();
  final NotificationService _notif = NotificationService();
  late final ValueListenable<Box<ReminderSettings>> _listenable =
      _reminders.watch();

  bool _testing = false;

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
        title: Text(
          'Smart reminders',
          style: GoogleFonts.instrumentSerif(
            color: AppColors.ink,
            fontStyle: FontStyle.italic,
            fontSize: 22,
          ),
        ),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 560,
          child: ValueListenableBuilder<Box<ReminderSettings>>(
            valueListenable: _listenable,
            builder: (context, box, _) {
              final settings = box.get(ReminderSettings.boxKey) ??
                  ReminderSettings();
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PermissionBanner(notif: _notif, onRequest: _requestPerm),
                    const SizedBox(height: 10),
                    _Card(
                      child: SettingsToggle(
                        icon: Icons.notifications_active_rounded,
                        title: 'Reminders enabled',
                        subtitle:
                            "Mood8 sends gentle check-ins during the day",
                        value: settings.enabled,
                        onChanged: (v) => _setEnabled(settings, v),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SectionLabel(label: 'TIMES'),
                    const SizedBox(height: 8),
                    _TimesList(
                      settings: settings,
                      onChange: _setTimes,
                    ),
                    const SizedBox(height: 18),
                    _SectionLabel(label: 'QUIET HOURS'),
                    const SizedBox(height: 8),
                    _Card(
                      child: SettingsToggle(
                        icon: Icons.bedtime_rounded,
                        title: 'Quiet hours',
                        subtitle: 'Suppress reminders overnight',
                        value: settings.quietHoursEnabled,
                        onChanged: (v) => _setQuietEnabled(settings, v),
                      ),
                    ),
                    if (settings.quietHoursEnabled) ...[
                      const SizedBox(height: 10),
                      _QuietWindow(
                        settings: settings,
                        onStart: _setQuietStart,
                        onEnd: _setQuietEnd,
                      ),
                    ],
                    const SizedBox(height: 18),
                    _SectionLabel(label: 'SMART BEHAVIOR'),
                    const SizedBox(height: 8),
                    _Card(
                      child: SettingsToggle(
                        icon: Icons.auto_awesome_rounded,
                        title: 'Smart skip',
                        subtitle:
                            "Skip if you've already checked in today",
                        value: settings.smartSkip,
                        onChanged: (v) => _setSmartSkip(settings, v),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _TestButton(
                      loading: _testing,
                      onTap: _sendTest,
                    )
                        .animate()
                        .fadeIn(delay: 120.ms, duration: 300.ms),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ─── Mutators ─────────────────────────────────────────────────────────

  Future<void> _requestPerm() async {
    HapticService().light();
    final ok = await _notif.requestPermission();
    if (!mounted) return;
    if (ok) {
      // Re-schedule now that we're permitted.
      await _reminders.scheduleAllReminders();
      setState(() {});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Notifications were not granted. Enable in your browser settings.'),
          backgroundColor: AppColors.bgCard,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }
  }

  Future<void> _setEnabled(ReminderSettings s, bool v) async {
    HapticService().selection();
    if (v && !_notif.isGranted) {
      final ok = await _confirmAndRequestPermission();
      if (!ok) return;
    }
    await _reminders.updateSettings(s.copyWith(enabled: v));
  }

  Future<bool> _confirmAndRequestPermission() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Text(
          'Allow notifications?',
          style: GoogleFonts.instrumentSerif(
            color: AppColors.ink,
            fontStyle: FontStyle.italic,
            fontSize: 22,
          ),
        ),
        content: Text(
          'Mood8 sends gentle check-in reminders. Change anytime in settings.',
          style: TextStyle(
            color: AppColors.inkSoft,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Not now',
              style: TextStyle(color: AppColors.inkDim),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Allow',
              style: TextStyle(
                color: AppColors.purpleLight,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    final granted = await _notif.requestPermission();
    if (!mounted) return granted;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Notifications blocked. Enable in your browser settings.'),
          backgroundColor: AppColors.bgCard,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }
    return granted;
  }

  Future<void> _setTimes(List<int> times) async {
    HapticService().light();
    final s = (await _reminders.getSettings()).copyWith(reminderTimes: times);
    await _reminders.updateSettings(s);
  }

  Future<void> _setQuietEnabled(ReminderSettings s, bool v) async {
    HapticService().selection();
    await _reminders.updateSettings(s.copyWith(quietHoursEnabled: v));
  }

  Future<void> _setSmartSkip(ReminderSettings s, bool v) async {
    HapticService().selection();
    await _reminders.updateSettings(s.copyWith(smartSkip: v));
  }

  Future<void> _setQuietStart(int minutes) async {
    final s = await _reminders.getSettings();
    await _reminders.updateSettings(s.copyWith(quietStart: minutes));
  }

  Future<void> _setQuietEnd(int minutes) async {
    final s = await _reminders.getSettings();
    await _reminders.updateSettings(s.copyWith(quietEnd: minutes));
  }

  Future<void> _sendTest() async {
    if (_testing) return;
    setState(() => _testing = true);
    HapticService().medium();
    try {
      await _reminders.sendTestNotification();
      if (!mounted) return;
      if (!_notif.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Allow notifications first to send a test.'),
            backgroundColor: AppColors.bgCard,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Test sent — check your notifications.'),
            backgroundColor: AppColors.bgCard,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }
}

// ─── Subwidgets ─────────────────────────────────────────────────────────

String _formatMinute(int m) {
  final h = (m ~/ 60).clamp(0, 23);
  final mm = (m % 60).clamp(0, 59);
  return '${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4),
      child: Text(
        label,
        style: TextStyle(
          color: AppColors.inkDim,
          fontSize: 10,
          letterSpacing: 1.8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.22),
        ),
      ),
      child: child,
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.notif, required this.onRequest});
  final NotificationService notif;
  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    if (!notif.isSupported) {
      return _Banner(
        icon: Icons.web_rounded,
        title: 'Web-only for now',
        body:
            'Notifications work in your browser on this device. Mobile reminders ship with the mobile app.',
        accent: AppColors.inkDim,
      );
    }
    if (notif.isGranted) {
      return _Banner(
        icon: Icons.check_circle_rounded,
        title: 'Notifications allowed',
        body: 'You can receive smart reminders.',
        accent: AppColors.blueAccent,
      );
    }
    return _Banner(
      icon: Icons.notifications_off_rounded,
      title: 'Notifications not enabled',
      body: 'Tap to allow browser notifications.',
      accent: AppColors.pinkLight,
      action: TextButton(
        onPressed: onRequest,
        child: Text(
          'Enable',
          style: TextStyle(
            color: AppColors.purpleLight,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
    this.action,
  });
  final IconData icon;
  final String title;
  final String body;
  final Color accent;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: 0.40),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  body,
                  style: TextStyle(
                    color: AppColors.inkDim,
                    fontSize: 12,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          // ignore: use_null_aware_elements
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _TimesList extends StatelessWidget {
  const _TimesList({required this.settings, required this.onChange});
  final ReminderSettings settings;
  final Future<void> Function(List<int>) onChange;

  static const int _maxTimes = 5;
  static const int _minTimes = 1;

  @override
  Widget build(BuildContext context) {
    final times = List<int>.from(settings.reminderTimes)..sort();
    return _Card(
      child: Column(
        children: [
          for (var i = 0; i < times.length; i++)
            _TimeRow(
              minute: times[i],
              canDelete: times.length > _minTimes,
              onEdit: () => _edit(context, times, i),
              onDelete: () => _delete(times, i),
            ),
          if (times.length < _maxTimes)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 10),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _add(context, times),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: AppColors.buttonGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_rounded,
                            color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Add reminder',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, List<int> times, int idx) async {
    final picked = await _pickTime(context, times[idx]);
    if (picked == null) return;
    final next = List<int>.from(times)..[idx] = picked;
    await onChange(next..sort());
  }

  Future<void> _add(BuildContext context, List<int> times) async {
    // Suggest a sensible default ~3 hrs after the latest reminder, wrapping.
    final last = times.isEmpty ? 540 : times.reduce(_maxInt);
    final suggested = (last + 180) % (24 * 60);
    final picked = await _pickTime(context, suggested);
    if (picked == null) return;
    final next = List<int>.from(times)..add(picked);
    await onChange(next..sort());
  }

  Future<void> _delete(List<int> times, int idx) async {
    if (times.length <= _minTimes) return;
    final next = List<int>.from(times)..removeAt(idx);
    await onChange(next);
  }

  Future<int?> _pickTime(BuildContext context, int minute) async {
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
    );
    if (result == null) return null;
    return result.hour * 60 + result.minute;
  }
}

int _maxInt(int a, int b) => a > b ? a : b;

class _TimeRow extends StatelessWidget {
  const _TimeRow({
    required this.minute,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });
  final int minute;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  static const List<String> _preview = <String>[
    'How are you feeling right now?',
    "Take a moment — how's your mood?",
    'Quick mood check?',
    "What's your vibe today?",
    'Pause and notice — how are you?',
  ];

  String _previewCopy() => _preview[(minute % _preview.length).toInt()];

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
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
                      AppColors.purpleLight.withValues(alpha: 0.65),
                      AppColors.purple.withValues(alpha: 0.20),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.access_time_rounded,
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
                      _formatMinute(minute),
                      style: GoogleFonts.instrumentSerif(
                        color: AppColors.ink,
                        fontStyle: FontStyle.italic,
                        fontSize: 20,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _previewCopy(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.inkDim,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: canDelete ? 'Remove' : 'At least one required',
                onPressed: canDelete ? onDelete : null,
                icon: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: canDelete
                      ? AppColors.inkDim
                      : AppColors.inkFaint.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuietWindow extends StatelessWidget {
  const _QuietWindow({
    required this.settings,
    required this.onStart,
    required this.onEnd,
  });
  final ReminderSettings settings;
  final Future<void> Function(int) onStart;
  final Future<void> Function(int) onEnd;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _PickerTile(
                    label: 'From',
                    value: settings.quietStart,
                    onTap: () => _pick(context, settings.quietStart, onStart),
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.arrow_forward_rounded,
                    color: AppColors.inkDim, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: _PickerTile(
                    label: 'To',
                    value: settings.quietEnd,
                    onTap: () => _pick(context, settings.quietEnd, onEnd),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _QuietRing(start: settings.quietStart, end: settings.quietEnd),
          ],
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context, int seed,
      Future<void> Function(int) cb) async {
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: seed ~/ 60, minute: seed % 60),
    );
    if (result == null) return;
    await cb(result.hour * 60 + result.minute);
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final int value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: AppColors.bg.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.purple.withValues(alpha: 0.22),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: AppColors.inkDim,
                  fontSize: 9,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _formatMinute(value),
                style: GoogleFonts.instrumentSerif(
                  color: AppColors.ink,
                  fontStyle: FontStyle.italic,
                  fontSize: 22,
                  height: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Illustration of the quiet window — a 24-hour ring with the silenced
/// arc rendered in dim ink so the user can see exactly when it applies.
class _QuietRing extends StatelessWidget {
  const _QuietRing({required this.start, required this.end});
  final int start;
  final int end;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 96,
      child: Center(
        child: SizedBox(
          width: 96,
          height: 96,
          child: CustomPaint(
            painter: _QuietRingPainter(start: start, end: end),
          ),
        ),
      ),
    );
  }
}

class _QuietRingPainter extends CustomPainter {
  _QuietRingPainter({required this.start, required this.end});
  final int start;
  final int end;

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 6;
    final rect = Rect.fromCircle(center: c, radius: r);

    // Base ring
    final base = Paint()
      ..color = AppColors.purple.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 2 * 3.1415926, false, base);

    // Quiet arc (in minutes → angle)
    final startAngle = _minToAngle(start);
    final sweep = _arcSweep(start, end);
    if (sweep <= 0) return;

    final quiet = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.purpleLight,
          AppColors.pinkLight,
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, sweep, false, quiet);

    // Inner moon glyph
    final moon = Paint()..color = AppColors.inkDim.withValues(alpha: 0.7);
    canvas.drawCircle(c, 4, moon);
  }

  double _minToAngle(int minute) {
    // 12 o'clock = -pi/2; full rotation over 1440 minutes.
    const twoPi = 2 * 3.1415926;
    return -3.1415926 / 2 + (minute / (24 * 60)) * twoPi;
  }

  double _arcSweep(int s, int e) {
    var diff = e - s;
    if (diff <= 0) diff += 24 * 60;
    const twoPi = 2 * 3.1415926;
    return (diff / (24 * 60)) * twoPi;
  }

  @override
  bool shouldRepaint(covariant _QuietRingPainter oldDelegate) =>
      oldDelegate.start != start || oldDelegate.end != end;
}

class _TestButton extends StatelessWidget {
  const _TestButton({required this.loading, required this.onTap});
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppColors.buttonGradient,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppColors.pink.withValues(alpha: 0.40),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: AppColors.purple.withValues(alpha: 0.32),
              blurRadius: 26,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              loading
                  ? Icons.hourglass_top_rounded
                  : Icons.notifications_active_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              loading ? 'Sending…' : 'Send test notification',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
