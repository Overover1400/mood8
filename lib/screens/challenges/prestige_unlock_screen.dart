import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/challenges/user_badge_chip.dart';

/// Full-screen celebration that fires when the server cron promotes
/// the signed-in user past a prestige threshold. Bigger and more
/// special than the rank-up dialog — this is a PERMANENT badge they'll
/// wear forever.
class PrestigeUnlockScreen extends StatefulWidget {
  const PrestigeUnlockScreen({super.key, required this.badge});

  final String badge;

  @override
  State<PrestigeUnlockScreen> createState() => _PrestigeUnlockScreenState();
}

class _PrestigeUnlockScreenState extends State<PrestigeUnlockScreen> {
  late final ConfettiController _confetti = ConfettiController(
    duration: const Duration(milliseconds: 2400),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HapticService().medium();
      _confetti.play();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  String _flavorFor(String badge) {
    switch (badge) {
      case 'Initiate':
        return 'You showed up — once, deliberately. The first badge is the hardest.';
      case 'Challenger':
        return 'Three challenges in. You’re not visiting anymore.';
      case 'Veteran':
        return 'Five complete. Patterns of someone who finishes.';
      case 'Champion':
        return 'Ten. The bar moved — you moved it.';
      case 'Warlord':
        return 'Twenty. You don’t join challenges — challenges happen around you.';
      case 'Mythic':
        return 'Thirty-five. Among the few. The proof is permanent.';
      case 'Immortal':
        return 'Fifty. The summit. Worn forever, by very few.';
      default:
        return 'A permanent mark of who you’ve become.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = prestigeAccentFor(widget.badge);
    return Scaffold(
      backgroundColor: const Color(0xFF0A0612),
      body: Stack(
        children: [
          // Background gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.2,
                  colors: [
                    accent.withValues(alpha: 0.22),
                    const Color(0xFF110821),
                    const Color(0xFF0A0612),
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          // Confetti at the top
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirection: math.pi / 2,
              blastDirectionality: BlastDirectionality.explosive,
              maxBlastForce: 22,
              minBlastForce: 8,
              emissionFrequency: 0.04,
              numberOfParticles: 36,
              gravity: 0.18,
              shouldLoop: false,
              colors: [
                accent,
                AppColors.pink,
                AppColors.purple,
                AppColors.purpleLight,
                Colors.white,
                const Color(0xFFFFE08A),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
              child: Column(
                children: [
                  const Spacer(),
                  Text(
                    'PERMANENT BADGE EARNED',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      letterSpacing: 2.6,
                      fontWeight: FontWeight.w800,
                    ),
                  ).animate().fadeIn(duration: 500.ms),
                  const SizedBox(height: 18),
                  // The badge itself, large.
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              accent.withValues(alpha: 0.55),
                              accent.withValues(alpha: 0.20),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                        ),
                      )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scaleXY(
                            begin: 0.92,
                            end: 1.10,
                            duration: 1800.ms,
                            curve: Curves.easeInOut,
                          ),
                      PrestigeBadgeArt(badge: widget.badge, size: 160)
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 500.ms)
                          .scaleXY(
                            begin: 0.5,
                            end: 1.0,
                            delay: 200.ms,
                            duration: 700.ms,
                            curve: Curves.easeOutBack,
                          ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    widget.badge,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.bricolageGrotesque(
                      color: Colors.white,
                      fontSize: 56,
                      height: 1.0,
                      foreground: Paint()
                        ..shader = LinearGradient(
                          colors: [Colors.white, accent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(
                          const Rect.fromLTWH(0, 0, 400, 80),
                        ),
                    ),
                  )
                      .animate(delay: 500.ms)
                      .fadeIn(duration: 600.ms)
                      .slideY(
                        begin: 0.10,
                        end: 0,
                        curve: Curves.easeOutCubic,
                      ),
                  const SizedBox(height: 14),
                  Text(
                    _flavorFor(widget.badge),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.bricolageGrotesque(
                      color: AppColors.inkSoft,
                      fontSize: 20,
                      height: 1.4,
                    ),
                  ).animate(delay: 900.ms).fadeIn(duration: 700.ms),
                  const Spacer(flex: 2),
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: double.infinity,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: AppColors.buttonGradient,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.45),
                            blurRadius: 28,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Text(
                        'Wear it proudly',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ).animate(delay: 1400.ms).fadeIn(duration: 500.ms),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        color: AppColors.inkDim,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
