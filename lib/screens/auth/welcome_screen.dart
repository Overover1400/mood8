import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth/auth_button.dart';
import '../../widgets/auth/google_sign_in_button.dart';
import '../../widgets/mood_orb.dart';
import '../../widgets/responsive_container.dart';
import 'register_screen.dart';
import 'sign_in_screen.dart';

const String kSkipAuthPrefKey = 'mood8.skipAuth';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, this.onBypass});

  /// Optional override for the "Try without account" flow. The default
  /// implementation sets the bypass pref and returns; the AuthGate rebuild
  /// then routes to the existing OnboardingFlow / MainNavigation.
  final VoidCallback? onBypass;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      body: Stack(
        children: [
          const _BackgroundGlow(),
          SafeArea(
            child: ResponsiveContainer(
              maxWidth: 480,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.primaryGradient,
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.pink.withValues(alpha: 0.45),
                                blurRadius: 14,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Mood8',
                          style: GoogleFonts.bricolageGrotesque(
                            color: BrandColors.ink(context),
                            fontSize: 22,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Center(
                      child: const MoodOrb(size: 140)
                          .animate()
                          .fadeIn(duration: 700.ms)
                          .scaleXY(
                              begin: 0.9, end: 1.0, curve: Curves.easeOut),
                    ),
                    const SizedBox(height: 32),
                    Center(
                      child: Text(
                        'Become more\nof yourself.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .displayLarge
                            ?.copyWith(fontSize: 44, height: 1.05),
                      )
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 600.ms)
                          .slideY(
                              begin: 0.05,
                              end: 0,
                              curve: Curves.easeOut),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'AI-powered personal operating system.\nLearn what actually makes you better.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: BrandColors.inkDim(context),
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ).animate().fadeIn(delay: 400.ms, duration: 500.ms),
                    const Spacer(flex: 2),
                    GoogleSignInButton(
                      onResultMessage: (msg) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(msg)),
                        );
                      },
                    )
                        .animate()
                        .fadeIn(delay: 500.ms, duration: 500.ms)
                        .slideY(
                            begin: 0.1, end: 0, curve: Curves.easeOut),
                    const SizedBox(height: 12),
                    AuthButton(
                      label: 'Create account',
                      icon: Icons.arrow_forward_rounded,
                      onTap: () {
                        HapticService().light();
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const RegisterScreen(),
                        ));
                      },
                    )
                        .animate()
                        .fadeIn(delay: 600.ms, duration: 500.ms)
                        .slideY(
                            begin: 0.1, end: 0, curve: Curves.easeOut),
                    const SizedBox(height: 12),
                    AuthButton(
                      label: 'Sign in',
                      outlined: true,
                      onTap: () {
                        HapticService().light();
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const SignInScreen(),
                        ));
                      },
                    )
                        .animate()
                        .fadeIn(delay: 700.ms, duration: 500.ms)
                        .slideY(
                            begin: 0.1, end: 0, curve: Curves.easeOut),
                    const SizedBox(height: 18),
                    Center(
                      child: TextButton(
                        onPressed: () => _bypass(context),
                        child: Text(
                          'Try without account →',
                          style: TextStyle(
                            color: AppColors.purpleLight,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: 750.ms, duration: 500.ms),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _bypass(BuildContext context) async {
    HapticService().selection();
    if (onBypass != null) {
      onBypass!();
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(kSkipAuthPrefKey, true);
    } catch (_) {}
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -120,
              left: -100,
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.purple.withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              right: -100,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.pink.withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
