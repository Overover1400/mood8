import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/pattern_alert.dart';
import '../theme/app_theme.dart';

/// Gradient-bordered card for a [PatternAlert]. Severity drives the
/// border + icon palette: purple/pink for positive, blue for neutral,
/// soft amber for gentle concerns.
class PatternAlertCard extends StatelessWidget {
  const PatternAlertCard({
    super.key,
    required this.alert,
    required this.onAction,
    required this.onDismiss,
    this.compact = false,
  });

  final PatternAlert alert;
  final VoidCallback onAction;
  final VoidCallback onDismiss;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(alert.severity);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.start.withValues(alpha: 0.18),
            palette.end.withValues(alpha: 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: palette.border,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.glow,
            blurRadius: 18,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      palette.icon.withValues(alpha: 0.85),
                      palette.icon.withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Icon(
                  palette.iconData,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  alert.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.bricolageGrotesque(
                    color: BrandColors.ink(context),
                    fontSize: 18,
                    height: 1.2,
                  ),
                ),
              ),
              InkWell(
                onTap: onDismiss,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.close_rounded,
                    color: BrandColors.inkDim(context),
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            alert.body,
            maxLines: compact ? 2 : 4,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: BrandColors.inkSoft(context),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          if ((alert.actionLabel ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: onAction,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: palette.icon.withValues(alpha: 0.20),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: palette.icon.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        alert.actionLabel!,
                        style: TextStyle(
                          color: BrandColors.ink(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: palette.icon,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static _Palette _palette(PatternSeverity s) {
    switch (s) {
      case PatternSeverity.positive:
        return _Palette(
          start: AppColors.purple,
          end: AppColors.pinkLight,
          border: AppColors.pinkLight.withValues(alpha: 0.55),
          glow: AppColors.pink.withValues(alpha: 0.30),
          icon: AppColors.pinkLight,
          iconData: Icons.auto_awesome_rounded,
        );
      case PatternSeverity.neutral:
        return _Palette(
          start: AppColors.blueAccent,
          end: AppColors.purpleLight,
          border: AppColors.blueAccent.withValues(alpha: 0.55),
          glow: AppColors.blueAccent.withValues(alpha: 0.28),
          icon: AppColors.blueAccent,
          iconData: Icons.insights_rounded,
        );
      case PatternSeverity.gentleConcern:
        return _Palette(
          start: const Color(0xFFFCD34D),
          end: const Color(0xFFF59E0B),
          border: const Color(0xFFFCD34D).withValues(alpha: 0.55),
          glow: const Color(0xFFFCD34D).withValues(alpha: 0.20),
          icon: const Color(0xFFF59E0B),
          iconData: Icons.favorite_border_rounded,
        );
    }
  }
}

class _Palette {
  const _Palette({
    required this.start,
    required this.end,
    required this.border,
    required this.glow,
    required this.icon,
    required this.iconData,
  });
  final Color start;
  final Color end;
  final Color border;
  final Color glow;
  final Color icon;
  final IconData iconData;
}
