import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/choose_habits_screen.dart';
import '../services/haptic_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';

/// In-app banner for the free-mode wind-down. Two states, both server-
/// driven and PLAY-SAFE (informational only — never a price or checkout):
///
///  • In grace (Premium starting soon): a DISMISSIBLE warning with the
///    days remaining, the user's habit count vs the free limit, and a
///    "Choose habits" action. Reassures that nothing is deleted.
///  • Restrictions active (grace passed, still over limit): a NON-
///    dismissible prompt to choose which habits stay active.
///
/// Renders nothing for premium / free-mode / under-limit users.
class GraceBanner extends StatefulWidget {
  const GraceBanner({super.key});

  @override
  State<GraceBanner> createState() => _GraceBannerState();
}

class _GraceBannerState extends State<GraceBanner> {
  static const String _kDismissKey = 'mood8.graceBanner.dismissedFor';
  String? _dismissedFor; // grace-window signature we dismissed

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  void initState() {
    super.initState();
    SubscriptionService().addListener(_onChange);
    _loadDismissed();
  }

  @override
  void dispose() {
    SubscriptionService().removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _loadDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() => _dismissedFor = prefs.getString(_kDismissKey));
      }
    } catch (_) {}
  }

  Future<void> _dismiss(String signature) async {
    HapticService().selection();
    setState(() => _dismissedFor = signature);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDismissKey, signature);
    } catch (_) {}
  }

  void _openChoose() {
    HapticService().light();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ChooseHabitsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = SubscriptionService();
    // Restrictions active — highest priority, never dismissible.
    if (svc.restrictionsActive) {
      return _Banner(
        icon: Icons.lock_outline_rounded,
        title: 'Premium has started',
        body: '${svc.habitsOverLimit} of your habits are paused. Pick the '
            '${svc.habitLimit ?? 3} to keep active — nothing was deleted.',
        actionLabel: 'Choose habits',
        onAction: _openChoose,
        onDismiss: null,
      );
    }
    // In grace — dismissible warning.
    if (svc.inGrace) {
      final ends = svc.graceEndsAt!;
      final signature = ends.toIso8601String();
      if (_dismissedFor == signature) return const SizedBox.shrink();
      final days = svc.graceDaysRemaining ?? 0;
      final when = days <= 1 ? 'tomorrow' : 'in $days days';
      return _Banner(
        icon: Icons.auto_awesome_rounded,
        title: 'Premium starts $when',
        body: 'You have ${svc.habitsOverLimit + (svc.habitLimit ?? 3)} '
            'habits and the free plan includes ${svc.habitLimit ?? 3}. '
            'Choose which to keep active by '
            '${_months[ends.month - 1]} ${ends.day} — nothing is ever '
            'deleted.',
        actionLabel: 'Choose habits',
        onAction: _openChoose,
        onDismiss: () => _dismiss(signature),
      );
    }
    return const SizedBox.shrink();
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
    required this.onDismiss,
  });
  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.purple.withValues(alpha: 0.20),
            AppColors.pink.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.pinkLight.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: const Color(0xFFF472B6), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: BrandColors.ink(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (onDismiss != null)
                GestureDetector(
                  onTap: onDismiss,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(Icons.close_rounded,
                        color: BrandColors.inkDim(context), size: 18),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              color: BrandColors.inkSoft(context),
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: AppColors.buttonGradient,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
