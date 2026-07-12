import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/analytics_models.dart';
import '../../theme/app_theme.dart';

/// Clean 7-day vertical bar chart of daily average mood. One bar per
/// day, day-of-week initial below (Sun-first), brand purple→pink
/// gradient fill scaled by mood 0–10. Deliberately minimal — no
/// gridlines, no y-axis ticks, no legend. Reads in one glance.
///
/// [series] is the full N-day series from
/// AnalyticsService.getMoodEnergyFocusOverTime — this widget takes
/// the tail 7 entries so the same source-of-truth used by the old
/// LineChartCard drives the new bars.
class MoodWeekBars extends StatelessWidget {
  const MoodWeekBars({super.key, required this.series});

  final List<DataPoint> series;

  static const _dowInitials = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    // Take the tail 7 days (or fewer if the series is short). The
    // analytics service always returns oldest→newest so the last 7
    // entries are the most recent week.
    final tail = series.length <= 7
        ? series
        : series.sublist(series.length - 7);
    if (tail.isEmpty) {
      return _EmptyHint();
    }
    final anyData = tail.any((p) => p.mood != null);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 128,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < tail.length; i++) ...[
                Expanded(
                  child: _DayBar(
                    point: tail[i],
                    label:
                        _dowInitials[tail[i].date.weekday % 7],
                    isToday: _isToday(tail[i].date),
                  ),
                ),
                if (i < tail.length - 1) const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        if (!anyData) ...[
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Log a mood check-in to see this fill.',
              style: TextStyle(
                color: BrandColors.inkDim(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.point,
    required this.label,
    required this.isToday,
  });
  final DataPoint point;
  final String label;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final v = point.mood ?? 0;
    // Bars scale 0-10 → 0-1 of the available track height. Even the
    // 0-value bars keep a hairline base so the day slot is legible.
    return LayoutBuilder(builder: (context, c) {
      const trackTop = 8.0;
      const dayLabelH = 22.0;
      final trackH = (c.maxHeight - dayLabelH - trackTop).clamp(40.0, 100.0);
      final hasData = point.mood != null;
      final ratio = hasData ? (v / 10).clamp(0.0, 1.0) : 0.0;
      final filledH = hasData ? (ratio * trackH).clamp(4.0, trackH) : 0.0;
      return Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Value indicator on top of the bar (only when data)
          if (hasData)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1),
                style: TextStyle(
                  color: isToday
                      ? AppColors.pinkLight
                      : BrandColors.inkSoft(context),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            )
          else
            const SizedBox(height: 16),
          Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // Track (thin bg pill)
              Container(
                width: double.infinity,
                height: trackH,
                decoration: BoxDecoration(
                  color: BrandColors.bgCard(context).withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              // Fill
              if (hasData)
                Container(
                  width: double.infinity,
                  height: filledH,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.pinkLight.withValues(alpha: 0.90),
                        AppColors.pink.withValues(alpha: 0.85),
                        AppColors.purple.withValues(alpha: 0.80),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.pink.withValues(alpha: 0.28),
                        blurRadius: 10,
                        spreadRadius: -3,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
              // Today ring on top of everything
              if (isToday)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.pinkLight.withValues(alpha: 0.85),
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.bricolageGrotesque(
              color: isToday
                  ? AppColors.pinkLight
                  : BrandColors.inkDim(context),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      );
    });
  }
}

class _EmptyHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 30),
      child: Center(
        child: Text(
          'Log a mood check-in to see this fill.',
          style: TextStyle(
            color: BrandColors.inkDim(context),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
