import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../models/user_profile.dart';
import '../screens/premium_screen.dart';
import '../services/haptic_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';

/// Bottom sheet that asks the user whether to spend a streak freeze to
/// protect a missed habit or routine.
Future<bool> showFreezeModal(
  BuildContext context, {
  required String itemType,
  required String itemName,
  required DateTime date,
  required UserProfile profile,
  required VoidCallback onConfirm,
}) async {
  HapticService().light();
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => FreezeModal(
      itemType: itemType,
      itemName: itemName,
      date: date,
      profile: profile,
      onConfirm: onConfirm,
    ),
  );
  return result ?? false;
}

class FreezeModal extends StatelessWidget {
  const FreezeModal({
    super.key,
    required this.itemType,
    required this.itemName,
    required this.date,
    required this.profile,
    required this.onConfirm,
  });

  final String itemType;
  final String itemName;
  final DateTime date;
  final UserProfile profile;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final empty = profile.freezesAvailable <= 0;
    final dayLabel = _dayLabel(date);

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                BrandColors.bgCard(context),
                BrandColors.bg(context),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.blueAccent.withValues(alpha: 0.32),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.blueAccent.withValues(alpha: 0.20),
                blurRadius: 44,
                spreadRadius: -8,
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: BrandColors.inkFaint(context).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(child: const _HeroSnowflake()),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'Freeze your streak?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text.rich(
                    TextSpan(
                      style: TextStyle(
                        color: BrandColors.inkSoft(context),
                        fontSize: 14,
                        height: 1.55,
                      ),
                      children: [
                        const TextSpan(text: 'Use a freeze to protect your '),
                        TextSpan(
                          text: itemType,
                          style: TextStyle(
                            color: BrandColors.ink(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(text: ' streak for '),
                        TextSpan(
                          text: dayLabel,
                          style: TextStyle(
                            color: BrandColors.ink(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const TextSpan(
                            text: ". You won't lose your progress."),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: BrandColors.bg(context).withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.purple.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.ac_unit_rounded,
                      size: 18,
                      color: empty
                          ? BrandColors.inkDim(context)
                          : AppColors.blueAccent,
                      shadows: empty
                          ? null
                          : [
                              Shadow(
                                color: AppColors.blueAccent
                                    .withValues(alpha: 0.7),
                                blurRadius: 10,
                              ),
                            ],
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        empty
                            ? 'You have 0 freezes available'
                            : '${profile.freezesAvailable} freeze${profile.freezesAvailable == 1 ? '' : 's'} available',
                        style: TextStyle(
                          color: BrandColors.inkSoft(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      itemName,
                      style: TextStyle(
                        color: BrandColors.inkDim(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (empty) ...[
                const SizedBox(height: 16),
                _PremiumUpsell(
                  onUpgrade: () {
                    Navigator.of(context).pop(false);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PremiumScreen(),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 22),
              if (!empty)
                _GradientButton(
                  label: 'Use freeze',
                  onTap: () {
                    HapticService().medium();
                    onConfirm();
                    Navigator.of(context).pop(true);
                  },
                ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(
                  'No thanks',
                  style: TextStyle(
                    color: BrandColors.inkDim(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _dayLabel(DateTime date) {
    final today = DateTime.now();
    final t = DateTime(today.year, today.month, today.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = t.difference(d).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'yesterday';
    return DateFormat('EEE, MMM d').format(date);
  }
}

class _HeroSnowflake extends StatelessWidget {
  const _HeroSnowflake();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.blueAccent.withValues(alpha: 0.55),
            AppColors.purple.withValues(alpha: 0.22),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.blueAccent.withValues(alpha: 0.55),
            blurRadius: 32,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Icon(
        Icons.ac_unit_rounded,
        size: 42,
        color: Colors.white,
        shadows: [
          Shadow(
            color: AppColors.blueAccent.withValues(alpha: 0.95),
            blurRadius: 18,
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(
          begin: 1.0,
          end: 1.10,
          duration: 1500.ms,
          curve: Curves.easeInOut,
        );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
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
              color: AppColors.purple.withValues(alpha: 0.35),
              blurRadius: 26,
              spreadRadius: -4,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.ac_unit_rounded,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
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

class _PremiumUpsell extends StatelessWidget {
  const _PremiumUpsell({required this.onUpgrade});
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    final isPremium = SubscriptionService().isPremium;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.purple.withValues(alpha: 0.22),
            AppColors.pink.withValues(alpha: 0.14),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.pinkLight.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Text('✨', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Out of freezes',
                  style: TextStyle(
                    color: BrandColors.ink(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPremium
                      ? 'Next freeze arrives Sunday.'
                      : 'Upgrade for 2 freezes per Sunday, stored up to 3.',
                  style: TextStyle(
                    color: BrandColors.inkDim(context),
                    fontSize: 11.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (!isPremium) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onUpgrade,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Upgrade',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
