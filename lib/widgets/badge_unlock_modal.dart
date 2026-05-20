import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../models/earned_badge.dart';
import '../models/sfx_type.dart';
import '../services/badge_definitions.dart';
import '../services/haptic_service.dart';
import '../services/sfx_service.dart';
import '../theme/app_theme.dart';

/// Looks up the catalog-side const [IconData] for a stored badge. Using the
/// catalog (not the persisted `iconCode`) keeps Flutter's icon tree-shaker
/// happy — only const IconData literals survive the shake.
IconData _iconForBadge(EarnedBadge badge) {
  final def = BadgeCatalog.byKey(badge.badgeKey);
  return def?.icon ?? Icons.emoji_events_rounded;
}

/// Shows a queue of newly-unlocked badges, one full-screen celebration at
/// a time. Returns once the user has dismissed every modal.
Future<void> showBadgeUnlockQueue(
  BuildContext context,
  List<EarnedBadge> badges,
) async {
  if (badges.isEmpty) return;
  for (final badge in badges) {
    if (!context.mounted) return;
    await _showOne(context, badge);
    // Tiny breath between celebrations so they don't smash together.
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}

Future<void> _showOne(BuildContext context, EarnedBadge badge) {
  HapticService().heavy();
  SfxService().fire(SfxType.streakMilestone);
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => BadgeUnlockModal(badge: badge),
      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class BadgeUnlockModal extends StatefulWidget {
  const BadgeUnlockModal({super.key, required this.badge});
  final EarnedBadge badge;

  @override
  State<BadgeUnlockModal> createState() => _BadgeUnlockModalState();
}

class _BadgeUnlockModalState extends State<BadgeUnlockModal> {
  late final ConfettiController _confetti =
      ConfettiController(duration: const Duration(milliseconds: 1800));
  bool _interactive = false;
  Timer? _enableTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confetti.play();
    });
    // 2-second auto-fade-in lock; user must tap *after* it settles to dismiss.
    _enableTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _interactive = true);
    });
  }

  @override
  void dispose() {
    _enableTimer?.cancel();
    _confetti.dispose();
    super.dispose();
  }

  void _continue() {
    if (!_interactive) return;
    HapticService().light();
    Navigator.of(context).maybePop();
  }

  Future<void> _share() async {
    HapticService().light();
    final text =
        "I just earned the '${widget.badge.title}' badge on Mood8 — "
        "${widget.badge.description} https://mood8.app";
    try {
      await Share.share(text, subject: 'Mood8 milestone');
    } catch (_) {
      // share_plus throws on web in some browser/device combos; the dialog
      // just won't appear — no user-facing error needed.
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Color(widget.badge.colorHex);
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Top-down confetti burst.
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirection: math.pi / 2,
              blastDirectionality: BlastDirectionality.explosive,
              emissionFrequency: 0.05,
              numberOfParticles: 22,
              maxBlastForce: 22,
              minBlastForce: 8,
              gravity: 0.18,
              colors: [
                accent,
                accent.withValues(alpha: 0.8),
                AppColors.pinkLight,
                AppColors.purpleLight,
                AppColors.blueAccent,
                Colors.white,
              ],
            ),
          ),
          Center(
            child: GestureDetector(
              onTap: _continue,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BadgeHero(badge: widget.badge),
                      const SizedBox(height: 32),
                      Text(
                        'BADGE UNLOCKED',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          letterSpacing: 3.2,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 300.ms, duration: 500.ms),
                      const SizedBox(height: 10),
                      Text(
                        widget.badge.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.instrumentSerif(
                          color: AppColors.ink,
                          fontStyle: FontStyle.italic,
                          fontSize: 38,
                          height: 1.1,
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 400.ms, duration: 600.ms)
                          .slideY(
                              begin: 0.06,
                              end: 0,
                              curve: Curves.easeOutCubic),
                      const SizedBox(height: 14),
                      Text(
                        widget.badge.description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.inkSoft,
                          fontSize: 15,
                          height: 1.5,
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 600.ms, duration: 500.ms),
                      const SizedBox(height: 36),
                      AnimatedOpacity(
                        opacity: _interactive ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 400),
                        child: Row(
                          children: [
                            Expanded(
                              child: _SecondaryButton(
                                label: 'Share',
                                icon: Icons.ios_share_rounded,
                                onTap: _interactive ? _share : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _PrimaryButton(
                                label: 'Continue',
                                onTap: _interactive ? _continue : null,
                              ),
                            ),
                          ],
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
}

class _BadgeHero extends StatelessWidget {
  const _BadgeHero({required this.badge});
  final EarnedBadge badge;

  @override
  Widget build(BuildContext context) {
    final accent = Color(badge.colorHex);
    final icon = _iconForBadge(badge);
    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing halo
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accent.withValues(alpha: 0.45),
                  accent.withValues(alpha: 0.10),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(
                begin: 1.0,
                end: 1.12,
                duration: 1600.ms,
                curve: Curves.easeInOut,
              ),
          // Rotating ring
          Container(
            width: 168,
            height: 168,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  accent.withValues(alpha: 0.0),
                  accent.withValues(alpha: 0.65),
                  accent.withValues(alpha: 0.0),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .rotate(duration: 4800.ms, curve: Curves.linear),
          // Inner badge disc
          Container(
            width: 132,
            height: 132,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  accent,
                  accent.withValues(alpha: 0.65),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.75),
                  blurRadius: 40,
                  spreadRadius: -4,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.40),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 64,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: accent.withValues(alpha: 0.95),
                  blurRadius: 18,
                ),
              ],
            ),
          )
              .animate()
              .scaleXY(
                begin: 0.4,
                end: 1.0,
                duration: 700.ms,
                curve: Curves.elasticOut,
              )
              .fadeIn(duration: 350.ms),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppColors.buttonGradient,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.pink.withValues(alpha: 0.40),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.ink, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Public helper: shown on tapping a badge from the gallery.
class BadgeDetailPopup extends StatelessWidget {
  const BadgeDetailPopup({super.key, required this.badge});
  final EarnedBadge badge;

  @override
  Widget build(BuildContext context) {
    final accent = Color(badge.colorHex);
    final icon = _iconForBadge(badge);
    final dateLabel = DateFormat.yMMMd().format(badge.unlockedAt);
    return AlertDialog(
      backgroundColor: AppColors.bgCard,
      contentPadding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 90,
                height: 90,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [accent, accent.withValues(alpha: 0.65)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.55),
                      blurRadius: 24,
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 42),
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                badge.title,
                textAlign: TextAlign.center,
                style: GoogleFonts.instrumentSerif(
                  color: AppColors.ink,
                  fontStyle: FontStyle.italic,
                  fontSize: 26,
                  height: 1.15,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              badge.description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.inkSoft,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            Center(
              child: Text(
                'Unlocked $dateLabel',
                style: TextStyle(
                  color: AppColors.inkDim,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Close',
            style: TextStyle(
              color: AppColors.purpleLight,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
