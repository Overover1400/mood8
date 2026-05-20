import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/weekly_recap.dart';
import '../services/haptic_service.dart';
import '../services/weekly_recap_service.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_container.dart';
import 'weekly_recap_screen.dart';

class PastRecapsScreen extends StatelessWidget {
  const PastRecapsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = WeeklyRecapService();
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: BrandColors.inkSoft(context), size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Past recaps',
          style: GoogleFonts.instrumentSerif(
            color: BrandColors.ink(context),
            fontStyle: FontStyle.italic,
            fontSize: 22,
          ),
        ),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 560,
          child: ValueListenableBuilder<Box<WeeklyRecap>>(
            valueListenable: service.watch(),
            builder: (context, _, _) {
              final recaps = service.getAll();
              if (recaps.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.purpleLight.withValues(alpha: 0.40),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No recaps yet',
                          style: GoogleFonts.instrumentSerif(
                            color: BrandColors.ink(context),
                            fontStyle: FontStyle.italic,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Your first weekly recap will appear here.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: BrandColors.inkDim(context),
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                itemCount: recaps.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final r = recaps[i];
                  return _RecapRow(recap: r)
                      .animate(delay: (40 * i).ms)
                      .fadeIn(duration: 320.ms)
                      .slideY(
                          begin: 0.04, end: 0, curve: Curves.easeOut);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RecapRow extends StatelessWidget {
  const _RecapRow({required this.recap});
  final WeeklyRecap recap;

  @override
  Widget build(BuildContext context) {
    final label =
        '${DateFormat('MMM d').format(recap.weekStart)} – ${DateFormat('MMM d').format(recap.weekEnd)}';
    final preview = recap.narrative;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticService().light();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => WeeklyRecapScreen(
                existing: recap,
                autoGenerate: false,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            color: BrandColors.bgCard(context).withValues(alpha: 0.80),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.purple.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.pinkLight.withValues(alpha: 0.85),
                      AppColors.purple.withValues(alpha: 0.20),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: BrandColors.inkDim(context),
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.instrumentSerif(
                        color: BrandColors.ink(context),
                        fontStyle: FontStyle.italic,
                        fontSize: 15,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                color: AppColors.purpleLight,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
