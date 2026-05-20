import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/premium_screen.dart';
import '../theme/app_theme.dart';

/// Wraps any widget with a premium upsell overlay when [isLocked] is true.
/// The child stays visible but dimmed so users see what they're getting.
class PremiumGate extends StatelessWidget {
  const PremiumGate({
    super.key,
    required this.isLocked,
    required this.child,
    this.title = 'Premium feature',
    this.description,
    this.ctaLabel = 'Upgrade',
  });

  final bool isLocked;
  final Widget child;
  final String title;
  final String? description;
  final String ctaLabel;

  @override
  Widget build(BuildContext context) {
    if (!isLocked) return child;

    return Stack(
      children: [
        IgnorePointer(child: Opacity(opacity: 0.35, child: child)),
        Positioned.fill(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    BrandColors.bgDeep(context).withValues(alpha: 0.88),
                  ],
                ),
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.buttonGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.pink.withValues(alpha: 0.45),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.workspace_premium_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: GoogleFonts.instrumentSerif(
                      color: BrandColors.ink(context),
                      fontStyle: FontStyle.italic,
                      fontSize: 22,
                    ),
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      description!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: BrandColors.inkDim(context),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PremiumScreen(),
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: AppColors.buttonGradient,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.pink.withValues(alpha: 0.40),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Text(
                        ctaLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
