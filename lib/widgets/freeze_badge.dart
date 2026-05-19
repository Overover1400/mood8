import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/user_profile.dart';
import '../services/haptic_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';

/// Pill badge showing how many streak freezes the user has banked. Tapping it
/// opens an info modal that explains how freezes work.
class FreezeBadge extends StatelessWidget {
  const FreezeBadge({
    super.key,
    required this.count,
    this.profile,
    this.onTap,
  });

  /// Number of freezes currently available.
  final int count;

  /// Optional — passed to the info modal so it can show "total used".
  final UserProfile? profile;

  /// Override the default tap behavior (info modal). Used when this badge
  /// sits inside a screen that wants different routing.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final empty = count <= 0;
    return GestureDetector(
      onTap: () {
        HapticService().light();
        if (onTap != null) {
          onTap!();
          return;
        }
        if (profile != null) {
          showFreezeInfoSheet(context, profile: profile!);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: empty
                ? [
                    AppColors.bgCard.withValues(alpha: 0.85),
                    AppColors.bg.withValues(alpha: 0.75),
                  ]
                : [
                    AppColors.blueAccent.withValues(alpha: 0.28),
                    AppColors.purple.withValues(alpha: 0.20),
                  ],
          ),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(
            color: empty
                ? AppColors.inkFaint.withValues(alpha: 0.40)
                : AppColors.blueAccent.withValues(alpha: 0.55),
          ),
          boxShadow: empty
              ? null
              : [
                  BoxShadow(
                    color: AppColors.blueAccent.withValues(alpha: 0.35),
                    blurRadius: 14,
                    spreadRadius: -2,
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Snowflake(active: !empty, size: 14),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                color: empty ? AppColors.inkDim : AppColors.ink,
                fontSize: 12,
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

/// Animated snowflake glyph. The glow pulses softly when [active].
class _Snowflake extends StatelessWidget {
  const _Snowflake({required this.active, this.size = 16});
  final bool active;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(
      Icons.ac_unit_rounded,
      size: size,
      color: active
          ? AppColors.blueAccent
          : AppColors.inkFaint.withValues(alpha: 0.7),
      shadows: active
          ? [
              Shadow(
                color: AppColors.blueAccent.withValues(alpha: 0.85),
                blurRadius: 10,
              ),
            ]
          : null,
    );
    if (!active) return icon;
    return icon
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(
          begin: 1.0,
          end: 1.12,
          duration: 1400.ms,
          curve: Curves.easeInOut,
        )
        .fadeIn(duration: 400.ms);
  }
}

// ─── Info sheet ─────────────────────────────────────────────────────────────

Future<void> showFreezeInfoSheet(
  BuildContext context, {
  required UserProfile profile,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => _FreezeInfoSheet(profile: profile),
  );
}

class _FreezeInfoSheet extends StatelessWidget {
  const _FreezeInfoSheet({required this.profile});
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final isPremium = SubscriptionService().isPremium;
    final maxStored = isPremium ? 3 : 1;
    final perWeek = isPremium ? 2 : 1;

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
                AppColors.bgCard,
                AppColors.bg,
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.blueAccent.withValues(alpha: 0.30),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.blueAccent.withValues(alpha: 0.18),
                blurRadius: 40,
                spreadRadius: -8,
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.inkFaint.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Center(
                child: _BigSnowflake(),
              ),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  'Streak Freeze',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Protect your streak when you miss a day.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _StatRow(
                label: 'Available',
                value: '${profile.freezesAvailable} / $maxStored',
              ),
              const SizedBox(height: 10),
              _StatRow(
                label: 'Earned each Sunday',
                value: '$perWeek',
              ),
              const SizedBox(height: 10),
              _StatRow(
                label: 'Lifetime used',
                value: '${profile.totalFreezesUsed}',
              ),
              const SizedBox(height: 20),
              if (!isPremium)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.purple.withValues(alpha: 0.18),
                        AppColors.pink.withValues(alpha: 0.10),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.pinkLight.withValues(alpha: 0.30),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Text('✨', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Premium: 2 per Sunday, hold up to 3.',
                          style: TextStyle(
                            color: AppColors.inkSoft,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: Text(
                  'Got it',
                  style: TextStyle(
                    color: AppColors.purpleLight,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.inkDim,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppColors.ink,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _BigSnowflake extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.blueAccent.withValues(alpha: 0.55),
            AppColors.purple.withValues(alpha: 0.20),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.blueAccent.withValues(alpha: 0.55),
            blurRadius: 28,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Icon(
        Icons.ac_unit_rounded,
        size: 36,
        color: Colors.white.withValues(alpha: 0.95),
        shadows: [
          Shadow(
            color: AppColors.blueAccent.withValues(alpha: 0.9),
            blurRadius: 14,
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(
          begin: 1.0,
          end: 1.08,
          duration: 1600.ms,
          curve: Curves.easeInOut,
        );
  }
}
