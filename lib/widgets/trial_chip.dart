import 'package:flutter/material.dart';

import '../screens/premium_screen.dart';
import '../services/haptic_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';

/// "Premium trial: N days left" — a compact chip shown on Home while the
/// server reports `plan_class == premium_trial`. Renders nothing for any
/// other plan. Tapping it opens Membership, which has the end date.
class TrialChip extends StatelessWidget {
  const TrialChip({super.key});

  /// Chip copy for [days] left; null when there is nothing to show.
  static String? labelFor(int? days) {
    if (days == null) return null;
    if (days <= 0) return 'Premium trial: ends today';
    if (days == 1) return 'Premium trial: 1 day left';
    return 'Premium trial: $days days left';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SubscriptionService(),
      builder: (context, _) {
        final label = labelFor(SubscriptionService().trialDaysLeft);
        if (label == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  HapticService().light();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const PremiumScreen()),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.purple.withValues(alpha: 0.16),
                        AppColors.pink.withValues(alpha: 0.10),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.pinkLight.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.workspace_premium_rounded,
                          color: Color(0xFFF472B6), size: 15),
                      const SizedBox(width: 7),
                      Text(
                        label,
                        style: TextStyle(
                          color: BrandColors.ink(context),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
