import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/reflection.dart';
import '../theme/app_theme.dart';

class ReflectionCard extends StatelessWidget {
  const ReflectionCard({
    super.key,
    required this.reflection,
    this.compact = false,
    this.onTap,
  });

  static final DateFormat _kDateFmt = DateFormat('EEEE, MMM d');
  static final DateFormat _kTimeFmt = DateFormat('h:mm a');

  final Reflection reflection;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dateLabel = _kDateFmt.format(reflection.date).toUpperCase();
    final timeLabel = _kTimeFmt.format(reflection.generatedAt);
    final body = compact
        ? _shorten(reflection.reflection)
        : reflection.reflection;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.purple.withValues(alpha: 0.22),
                AppColors.pink.withValues(alpha: 0.14),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppColors.pinkLight.withValues(alpha: 0.40),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.purple.withValues(alpha: 0.25),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('💫', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Tonight's reflection",
                      style: TextStyle(
                        color: AppColors.pinkLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.6,
                      ),
                    ),
                  ),
                  Text(
                    dateLabel,
                    style: TextStyle(
                      color: AppColors.inkDim,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                body,
                maxLines: compact ? 4 : null,
                overflow: compact ? TextOverflow.ellipsis : null,
                style: GoogleFonts.instrumentSerif(
                  color: AppColors.ink,
                  fontStyle: FontStyle.italic,
                  fontSize: compact ? 17 : 19,
                  height: 1.35,
                ),
              ),
              if (!compact && reflection.suggestion != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  decoration: BoxDecoration(
                    color: AppColors.bg.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.purple.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.auto_awesome_rounded,
                          color: AppColors.purpleLight, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reflection.suggestion!,
                          style: const TextStyle(
                            color: AppColors.inkSoft,
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    timeLabel,
                    style: TextStyle(
                      color: AppColors.inkDim,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Mood8 AI',
                    style: TextStyle(
                      color: AppColors.purpleLight,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _shorten(String s) {
    if (s.length <= 220) return s;
    return '${s.substring(0, 217)}…';
  }
}
