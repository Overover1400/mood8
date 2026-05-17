import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

class AiSummaryCard extends StatelessWidget {
  const AiSummaryCard({
    super.key,
    required this.summary,
    required this.loading,
    required this.onReload,
  });

  final String? summary;
  final bool loading;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.purple.withValues(alpha: 0.20),
            AppColors.pink.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.pinkLight.withValues(alpha: 0.40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✨', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'YOUR WEEK, SUMMARIZED',
                  style: TextStyle(
                    color: AppColors.pinkLight,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              IconButton(
                onPressed: loading ? null : onReload,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: Icon(
                  Icons.refresh_rounded,
                  color: loading
                      ? AppColors.inkDim
                      : AppColors.purpleLight,
                  size: 18,
                ),
                tooltip: 'Regenerate',
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading)
            Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation(AppColors.pinkLight),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Mood8 is reading your week…',
                  style: TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 13,
                  ),
                ),
              ],
            )
          else
            Text(
              summary == null || summary!.isEmpty
                  ? 'Generate your weekly narrative once you have a few patterns.'
                  : summary!,
              style: GoogleFonts.instrumentSerif(
                color: AppColors.ink,
                fontStyle: FontStyle.italic,
                fontSize: 17,
                height: 1.45,
              ),
            ),
        ],
      ),
    );
  }
}
