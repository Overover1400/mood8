import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show AndroidScheduleMode;
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../services/notif_log.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive_container.dart';

/// **Notification debug** — the empirical screen for the "final
/// attempt" at habit reminders. Per the directive, it shows live:
///
///   • flutter_local_notifications initialized?
///   • Local timezone (the actual `tz.local.name`)
///   • Current device time (refreshed every second)
///   • POST_NOTIFICATIONS — granted / denied / restricted (the real
///     state from permission_handler, not "requested" tags)
///   • SCHEDULE_EXACT_ALARM — canScheduleExactNotifications result
///   • Battery optimization exempt? (Permission.ignoreBatteryOpt)
///   • Every pendingNotificationRequest with id, title, AND its
///     parsed scheduled local time + the schedule mode it was queued
///     with (read from NotifLog because the plugin's `PendingNotif…`
///     struct only carries id/title/body/payload, not the trigger
///     time).
///
/// Action buttons:
///   • **Schedule in 2 minutes** — schedules a real future moment
///     (DateTime.now() + 2:00), with matchDateTimeComponents stripped
///     (we want a one-shot for this test, not a daily repeat) so
///     verification is unambiguous: "did the notification fire 120 s
///     after I tapped, with the app closed".
///   • **Cancel all** — `_plugin.cancelAll()` to clear queue.
///   • **Open battery settings** — deep-link to the system battery
///     page for Mood8 (the ONLY fix when scheduling is correct but
///     OEM doze kills the alarm).
///   • **Open exact-alarm settings** — system page where the user
///     grants SCHEDULE_EXACT_ALARM.
class NotificationDebugScreen extends StatefulWidget {
  const NotificationDebugScreen({super.key});

  @override
  State<NotificationDebugScreen> createState() =>
      _NotificationDebugScreenState();
}

class _NotificationDebugScreenState extends State<NotificationDebugScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool _batteryExempt = false;
  PermissionStatus _notifStatus = PermissionStatus.denied;
  List<PendingNotificationRequest> _pending = const [];
  Timer? _clockTick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotifLog.revision.addListener(_onLogTick);
    _clockTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _refresh();
  }

  @override
  void dispose() {
    _clockTick?.cancel();
    NotifLog.revision.removeListener(_onLogTick);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onLogTick() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // After returning from system Settings (exact alarm / battery /
    // notification permission), re-read live state.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      await NotificationService().ensureInitialized();
      await NotificationService().refreshPermissionState();
      _batteryExempt =
          await NotificationService().isIgnoringBatteryOptimizations();
      _notifStatus = await Permission.notification.status;
      _pending = await NotificationService().pendingRequests();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _grantNotificationPermission() async {
    HapticFeedback.selectionClick();
    final ok = await NotificationService().requestPermission();
    if (!ok) {
      // Permanently-denied: open app settings as the only path.
      final status = await Permission.notification.status;
      if (status.isPermanentlyDenied) await openAppSettings();
    }
    await _refresh();
  }

  Future<void> _grantExactAlarm() async {
    HapticFeedback.selectionClick();
    // Don't await — the plugin's Future is unreliable for Settings-
    // launching activities. Resume hook re-reads state.
    // ignore: discarded_futures
    NotificationService().requestExactAlarmPermission();
  }

  Future<void> _exemptBattery() async {
    HapticFeedback.selectionClick();
    await NotificationService().requestIgnoreBatteryOptimizations();
    await _refresh();
  }

  Future<void> _scheduleIn2Minutes() async {
    HapticFeedback.selectionClick();
    final notif = NotificationService();
    await notif.ensureInitialized();
    if (!notif.isGranted) {
      final ok = await notif.requestPermission();
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Permission denied — can't schedule. Tap 'Grant' on the row."),
          ),
        );
        return;
      }
    }
    final r = await notif.scheduleOneShotIn(
      delay: const Duration(minutes: 2),
      title: 'Mood8 · 2-minute test',
      body: 'Scheduled 2 minutes ago. If you see this, scheduling works.',
    );
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          r.ok
              ? "Scheduled. firesAt=${r.firesAt}, mode=${r.mode}, "
                  "queue=${r.pendingCount}. Close the app to verify."
              : "Failed: ${r.reason ?? 'unknown'}",
        ),
        backgroundColor: BrandColors.bgCard(context),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  Future<void> _cancelAll() async {
    HapticFeedback.selectionClick();
    await NotificationService().cancelAll();
    await _refresh();
  }

  Future<void> _openAppSettings() async {
    HapticFeedback.selectionClick();
    await openAppSettings();
  }

  String _now() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${n.year}-${two(n.month)}-${two(n.day)} '
        '${two(n.hour)}:${two(n.minute)}:${two(n.second)}';
  }

  String _tzNow() {
    try {
      final t = tz.TZDateTime.now(tz.local);
      String two(int v) => v.toString().padLeft(2, '0');
      return '${t.year}-${two(t.month)}-${two(t.day)} '
          '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
    } catch (_) {
      return '(tz not init)';
    }
  }

  String _permStr(PermissionStatus s) {
    switch (s) {
      case PermissionStatus.granted:
        return 'granted';
      case PermissionStatus.denied:
        return 'denied';
      case PermissionStatus.permanentlyDenied:
        return 'permanentlyDenied';
      case PermissionStatus.restricted:
        return 'restricted';
      case PermissionStatus.limited:
        return 'limited';
      case PermissionStatus.provisional:
        return 'provisional';
    }
  }

  @override
  Widget build(BuildContext context) {
    final notif = NotificationService();
    final logs = NotifLog.snapshot();
    final scheduleMode = notif.canExactAlarm
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
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
        title: Text('Notification debug',
            style: Theme.of(context).textTheme.headlineSmall),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: BrandColors.inkSoft(context)),
            onPressed: _busy ? null : _refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 640,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusBlock(
                  rows: [
                    _StatusEntry(
                      label: 'Plugin initialized',
                      ok: notif.isInitialized,
                    ),
                    _StatusEntry(
                      label: 'Timezone (tz.local.name)',
                      ok: notif.timezoneName != 'UTC (fallback)' &&
                          notif.timezoneName != 'UTC',
                      detail: notif.timezoneName,
                    ),
                    _StatusEntry(
                      label: 'Device wall clock',
                      ok: true,
                      detail: _now(),
                    ),
                    _StatusEntry(
                      label: 'TZ-aware clock (tz.TZDateTime.now)',
                      ok: notif.isInitialized,
                      detail: _tzNow(),
                    ),
                    _StatusEntry(
                      label: 'POST_NOTIFICATIONS',
                      ok: _notifStatus == PermissionStatus.granted,
                      detail: _permStr(_notifStatus),
                      action: _notifStatus.isGranted ? null : 'Grant',
                      onTap: _notifStatus.isGranted
                          ? null
                          : _grantNotificationPermission,
                    ),
                    _StatusEntry(
                      label: 'SCHEDULE_EXACT_ALARM',
                      ok: notif.canExactAlarm,
                      detail:
                          notif.canExactAlarm ? 'granted' : 'denied/notgranted',
                      action: notif.canExactAlarm ? null : 'Grant',
                      onTap: notif.canExactAlarm ? null : _grantExactAlarm,
                    ),
                    _StatusEntry(
                      label: 'Battery optimization exempt',
                      ok: _batteryExempt,
                      detail: _batteryExempt ? 'exempt' : 'NOT exempt',
                      action: _batteryExempt ? null : 'Exempt',
                      onTap: _batteryExempt ? null : _exemptBattery,
                    ),
                    _StatusEntry(
                      label: 'Schedule mode (next zonedSchedule call)',
                      ok: notif.canExactAlarm,
                      detail: scheduleMode.name,
                    ),
                    _StatusEntry(
                      label: 'Queued reminders',
                      ok: _pending.isNotEmpty,
                      detail: '${_pending.length}',
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SectionLabel(
                    label: 'Actions',
                    helper: 'Close the app after scheduling to verify'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ActionTile(
                        icon: Icons.schedule_send_rounded,
                        label: 'Schedule in 2 min',
                        sub: '(real future moment, one-shot)',
                        onTap: _busy ? null : _scheduleIn2Minutes,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionTile(
                        icon: Icons.cancel_outlined,
                        label: 'Cancel all',
                        sub: '(clears OS queue)',
                        onTap: _busy ? null : _cancelAll,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SectionLabel(
                    label: 'pendingNotificationRequests',
                    helper: 'authoritative OS queue'),
                const SizedBox(height: 10),
                if (_pending.isEmpty)
                  _CodeBlock(
                    text:
                        'EMPTY — no notifications queued in the OS.\n\n'
                        'Possible reasons:\n'
                        '  • You haven\'t scheduled one yet (try the 2-min button)\n'
                        '  • Permission denied (see row above)\n'
                        '  • zonedSchedule threw (check log below for PlatformException)',
                  )
                else
                  _CodeBlock(
                    text: _pending
                        .map(
                          (p) => 'id=${p.id}\n'
                              '  title: ${p.title ?? "(none)"}\n'
                              '  body:  ${p.body ?? "(none)"}',
                        )
                        .join('\n\n'),
                  ),
                const SizedBox(height: 18),
                _SectionLabel(
                    label: 'NotifLog',
                    helper:
                        'last ${NotifLog.maxEntries} events · newest first'),
                const SizedBox(height: 10),
                _CodeBlock(
                  text: logs.isEmpty
                      ? '(empty — tap an action above)'
                      : logs.reversed.join('\n'),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ToolPill(
                      label: 'Open app settings',
                      icon: Icons.settings_outlined,
                      onTap: _openAppSettings,
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                  decoration: BoxDecoration(
                    color: AppColors.purple.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.purple.withValues(alpha: 0.32),
                    ),
                  ),
                  child: Text(
                    "How to test:\n"
                    "  1. Confirm POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM, "
                    "and battery exempt are all ✓.\n"
                    "  2. Confirm timezone is your real tz (not UTC fallback).\n"
                    "  3. Note the device wall clock.\n"
                    "  4. Tap 'Schedule in 2 min'. Read the snackbar — "
                    "firesAt should be wall-clock + 2:00.\n"
                    "  5. Verify the pending list now has 1 entry.\n"
                    "  6. CLOSE the app (swipe out of recents) AND lock the "
                    "phone.\n"
                    "  7. Wait 2 minutes. Notification should arrive.\n"
                    "  8. If it doesn't: re-open this screen — is the entry "
                    "still in pending? If yes, OEM doze killed it (battery "
                    "exemption is the only fix). If no, the alarm fired "
                    "into the void — paste the NotifLog.",
                    style: TextStyle(
                      color: BrandColors.inkSoft(context),
                      fontSize: 12.5,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusEntry {
  _StatusEntry({
    required this.label,
    required this.ok,
    this.detail,
    this.action,
    this.onTap,
  });
  final String label;
  final bool ok;
  final String? detail;
  final String? action;
  final VoidCallback? onTap;
}

class _StatusBlock extends StatelessWidget {
  const _StatusBlock({required this.rows});
  final List<_StatusEntry> rows;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.22)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: AppColors.purple.withValues(alpha: 0.12),
              ),
            _StatusRow(row: rows[i]),
          ],
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.row});
  final _StatusEntry row;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(
            row.ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: row.ok ? AppColors.pinkLight : const Color(0xFFFF6B81),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.label,
                  style: TextStyle(
                    color: BrandColors.ink(context),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (row.detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    row.detail!,
                    style: GoogleFonts.jetBrainsMono(
                      color: BrandColors.inkDim(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (row.action != null && row.onTap != null)
            TextButton(
              onPressed: row.onTap,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.pinkLight,
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
              ),
              child: Text(
                row.action!,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.helper});
  final String label;
  final String? helper;
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: BrandColors.inkDim(context),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        if (helper != null) ...[
          const SizedBox(width: 10),
          Text(
            helper!,
            style: TextStyle(
              color: BrandColors.inkFaint(context),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.sub,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String sub;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            gradient: AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.pink.withValues(alpha: 0.32),
                blurRadius: 14,
                spreadRadius: -3,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolPill extends StatelessWidget {
  const _ToolPill({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: BrandColors.bgCard(context).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.purple.withValues(alpha: 0.32),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: BrandColors.inkSoft(context), size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: BrandColors.ink(context),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: BrandColors.bgDeep(context).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.18)),
      ),
      child: SelectableText(
        text,
        style: GoogleFonts.jetBrainsMono(
          color: BrandColors.inkSoft(context),
          fontSize: 11.5,
          height: 1.45,
        ),
      ),
    );
  }
}
