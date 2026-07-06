import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/paywall_screen.dart';
import '../services/haptic_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';

/// Slim, dismissible upgrade prompt shown on the main screens
/// (Today, Habits, Progress) for free users. Explicitly NOT
/// shown on:
///   • Onboarding (never mounts here)
///   • The paywall itself (would be recursive)
///   • Coach mid-conversation (mount only if free + top-level tab)
///   • Modal / bottom-sheet stacks (host stays on the main screens
///     underneath, but the sheet occupies the front-most surface —
///     mounting is fine, but the bar auto-hides while dismissed).
///
/// Behaviour rules:
///   • Hidden if the user is premium (any tier).
///   • Hidden if dismissed within the last [_kDismissWindow].
///   • Dismiss action closes it with a friendly fade — no
///     re-nagging on every screen change or tab switch.
///   • Tap opens the paywall.
///
/// Uses SharedPreferences under `mood8.upgradePrompt.dismissedAtIso`
/// so the dismissal survives app restarts and syncs across tabs.
class UpgradePromptBar extends StatefulWidget {
  const UpgradePromptBar({super.key});

  /// Ceiling for the "hide after dismissal" cool-off. Deliberately
  /// generous so the bar doesn't feel naggy — a user who dismissed
  /// today shouldn't see it again for the rest of the week.
  static const Duration _kDismissWindow = Duration(days: 5);

  static const String _kDismissedAtKey =
      'mood8.upgradePrompt.dismissedAtIso';

  @override
  State<UpgradePromptBar> createState() => _UpgradePromptBarState();
}

class _UpgradePromptBarState extends State<UpgradePromptBar> {
  /// Tri-state: null = unresolved (loading pref), true = show,
  /// false = hide.
  bool? _shouldShow;

  @override
  void initState() {
    super.initState();
    SubscriptionService().addListener(_onSubChange);
    _refresh();
  }

  @override
  void dispose() {
    SubscriptionService().removeListener(_onSubChange);
    super.dispose();
  }

  void _onSubChange() {
    // If the user upgrades in another screen, hide immediately.
    if (SubscriptionService().isPremium && _shouldShow == true) {
      if (mounted) setState(() => _shouldShow = false);
    } else {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    if (SubscriptionService().isPremium) {
      if (mounted) setState(() => _shouldShow = false);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(UpgradePromptBar._kDismissedAtKey);
      if (raw == null) {
        if (mounted) setState(() => _shouldShow = true);
        return;
      }
      final dismissedAt = DateTime.tryParse(raw);
      if (dismissedAt == null) {
        if (mounted) setState(() => _shouldShow = true);
        return;
      }
      final expired = DateTime.now().difference(dismissedAt) >=
          UpgradePromptBar._kDismissWindow;
      if (mounted) setState(() => _shouldShow = expired);
    } catch (_) {
      if (mounted) setState(() => _shouldShow = true);
    }
  }

  Future<void> _onDismiss() async {
    HapticService().selection();
    setState(() => _shouldShow = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        UpgradePromptBar._kDismissedAtKey,
        DateTime.now().toIso8601String(),
      );
    } catch (_) {}
  }

  void _onTap() {
    HapticService().light();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PaywallScreen(
          highlightPlus: true,
          contextNote: null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldShow != true) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.purple.withValues(alpha: 0.16),
                  AppColors.pink.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.purple.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.buttonGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.pink.withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.diamond_outlined,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Unlock AI Habit Packages',
                        style: TextStyle(
                          color: BrandColors.ink(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Premium Plus — everything AI, no limits.',
                        style: TextStyle(
                          color: BrandColors.inkSoft(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _onDismiss,
                  icon: Icon(
                    Icons.close_rounded,
                    color: BrandColors.inkSoft(context),
                    size: 18,
                  ),
                  tooltip: 'Dismiss',
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
