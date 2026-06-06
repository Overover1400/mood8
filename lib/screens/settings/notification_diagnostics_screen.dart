import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../services/notif_log.dart';
import '../../services/notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive_container.dart';

/// "Why isn't this working?" screen for notification reliability.
/// Six pieces of info + six actions all in one place so a tester can
/// answer every question the v1 reminder bug surfaced:
///
///   • Is the plugin initialized?           (status row)
///   • Is the timezone set + what is it?    (status row)
///   • Is POST_NOTIFICATIONS granted?       (status row + grant button)
///   • Is SCHEDULE_EXACT_ALARM granted?     (status row + grant button)
///   • Is the app exempt from battery opt?  (status row + grant button)
///   • What's queued in the OS right now?   (pending dump + count)
///
///   • "Fire NOW (show)"                    — bypasses scheduler; if this fails,
///                                            it's permission/channel/icon
///   • "Test 5 s (zonedSchedule)"           — exercises the alarm path
///   • Live log tail                         — the [Notif] trail
///   • "Refresh status"                     — re-reads from OS
///   • "Open app settings"                  — system Settings → Mood8
class NotificationDiagnosticsScreen extends StatefulWidget {
  const NotificationDiagnosticsScreen({super.key});

  @override
  State<NotificationDiagnosticsScreen> createState() =>
      _NotificationDiagnosticsScreenState();
}

class _NotificationDiagnosticsScreenState
    extends State<NotificationDiagnosticsScreen>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool _batteryExempt = false;
  List<PendingNotificationRequest> _pending = const [];
  String? _lastTestSummary;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotifLog.revision.addListener(_onLogTick);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotifLog.revision.removeListener(_onLogTick);
    super.dispose();
  }

  void _onLogTick() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // User returned from system Settings (e.g. after granting exact
    // alarm) — re-read state so the status rows reflect reality.
    if (state == AppLifecycleState.resumed) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      await NotificationService().ensureInitialized();
      await NotificationService().refreshPermissionState();
      _batteryExempt =
          await NotificationService().isIgnoringBatteryOptimizations();
      _pending = await NotificationService().pendingRequests();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _grantNotificationPermission() async {
    HapticFeedback.selectionClick();
    final ok = await NotificationService().requestPermission();
    if (!ok) {
      // Likely "permanently denied" — only fix is system Settings.
      final status = await Permission.notification.status;
      if (status.isPermanentlyDenied) {
        await openAppSettings();
      }
    }
    await _refresh();
  }

  Future<void> _grantExactAlarm() async {
    HapticFeedback.selectionClick();
    await NotificationService().requestExactAlarmPermission();
    // Returns immediately — system Settings page is launched. The
    // resume hook picks up the new state when the user comes back.
  }

  Future<void> _exemptBattery() async {
    HapticFeedback.selectionClick();
    await NotificationService().requestIgnoreBatteryOptimizations();
    await _refresh();
  }

  Future<void> _testNow() async {
    HapticFeedback.selectionClick();
    final r = await NotificationService().showNowDiagnostic();
    setState(() {
      _lastTestSummary = _formatTestResult('FIRE NOW (show)', r);
    });
    await _refresh();
  }

  Future<void> _testIn5s() async {
    HapticFeedback.selectionClick();
    final r = await NotificationService()
        .scheduleOneShotIn(delay: const Duration(seconds: 5));
    setState(() {
      _lastTestSummary = _formatTestResult('SCHEDULE 5 s', r);
    });
    await _refresh();
  }

  String _formatTestResult(String label, TestResult r) {
    final b = StringBuffer()..writeln(label);
    b
      ..writeln('  ok: ${r.ok}')
      ..writeln('  mode: ${r.mode}');
    if (r.firesAt != null) b.writeln('  firesAt: ${r.firesAt}');
    if (r.reason != null) b.writeln('  reason: ${r.reason}');
    b.write('  queuedAfter: ${r.pendingCount}');
    return b.toString();
  }

  Future<void> _openAppSettings() async {
    HapticFeedback.selectionClick();
    await openAppSettings();
  }

  Future<void> _cancelAll() async {
    HapticFeedback.selectionClick();
    await NotificationService().cancelAll();
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final notif = NotificationService();
    final logs = NotifLog.snapshot();
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
        title: Text('Reminder diagnostics',
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
          maxWidth: 600,
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
                      label: 'Timezone',
                      ok: notif.timezoneName != 'UTC (fallback)',
                      detail: notif.timezoneName,
                    ),
                    _StatusEntry(
                      label: 'Notification permission',
                      ok: notif.isGranted,
                      action: notif.isGranted ? null : 'Grant',
                      onTap: notif.isGranted ? null : _grantNotificationPermission,
                    ),
                    _StatusEntry(
                      label: 'Exact alarm scheduling',
                      ok: notif.canExactAlarm,
                      action: notif.canExactAlarm ? null : 'Grant',
                      onTap: notif.canExactAlarm ? null : _grantExactAlarm,
                    ),
                    _StatusEntry(
                      label: 'Battery optimization exempt',
                      ok: _batteryExempt,
                      action: _batteryExempt ? null : 'Exempt',
                      onTap: _batteryExempt ? null : _exemptBattery,
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
                    label: 'Run a test', helper: 'Close the app to verify'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _ActionTile(
                        icon: Icons.flash_on_rounded,
                        label: 'Fire NOW',
                        sub: '(bypasses scheduler)',
                        onTap: _busy ? null : _testNow,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ActionTile(
                        icon: Icons.schedule_send_rounded,
                        label: 'Schedule 5 s',
                        sub: '(via zonedSchedule)',
                        onTap: _busy ? null : _testIn5s,
                      ),
                    ),
                  ],
                ),
                if (_lastTestSummary != null) ...[
                  const SizedBox(height: 12),
                  _CodeBlock(text: _lastTestSummary!),
                ],
                const SizedBox(height: 18),
                _SectionLabel(
                    label: 'Queued in the OS',
                    helper: '${_pending.length} entr'
                        '${_pending.length == 1 ? 'y' : 'ies'}'),
                const SizedBox(height: 10),
                if (_pending.isEmpty)
                  _CodeBlock(
                    text:
                        'No scheduled reminders queued.\n\nThis is expected when:\n'
                        '  • the master switch is off\n'
                        '  • permission was never granted\n'
                        '  • the schedule call threw (check log below)',
                  )
                else
                  _CodeBlock(
                    text: _pending
                        .take(20)
                        .map((p) =>
                            'id=${p.id}  ${p.title ?? '(no title)'}\n  ${p.body ?? ''}')
                        .join('\n\n'),
                  ),
                const SizedBox(height: 18),
                _SectionLabel(
                    label: 'Notification log',
                    helper: 'last ${NotifLog.maxEntries} events'),
                const SizedBox(height: 10),
                _CodeBlock(
                  text: logs.isEmpty
                      ? '(no events yet — tap an action above)'
                      : logs.reversed.join('\n'),
                ),
                const SizedBox(height: 18),
                _SectionLabel(label: 'Tools'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ToolPill(
                      label: 'Refresh status',
                      icon: Icons.refresh_rounded,
                      onTap: _busy ? null : _refresh,
                    ),
                    _ToolPill(
                      label: 'Open app settings',
                      icon: Icons.settings_outlined,
                      onTap: _openAppSettings,
                    ),
                    _ToolPill(
                      label: 'Cancel all queued',
                      icon: Icons.cancel_outlined,
                      onTap: _busy ? null : _cancelAll,
                    ),
                  ],
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
            color:
                row.ok ? AppColors.pinkLight : const Color(0xFFFF6B81),
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
                    style: TextStyle(
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
