import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/habit_log.dart';
import '../services/habit_repository.dart';
import '../services/haptic_service.dart';
import '../theme/app_theme.dart';

/// Month-grid heatmap shown on Home. For each day in the current
/// month it computes how many of the user's scheduled habits were
/// completed and shades the cell from a faint floor to a full
/// brand-purple→pink gradient at 100%. Tap a day to see a quick
/// "X / Y habits" summary.
///
/// Pulls from the same `HabitLog` rows the streak + per-habit
/// heatmaps read, via `HabitRepository.allLogs`, so the colour
/// scale matches what the rest of the app shows. Computed in a
/// single O(N) pass per build so we don't pay box-read cost per
/// cell.
class HabitCompletionCalendar extends StatefulWidget {
  const HabitCompletionCalendar({super.key, required this.repo});

  final HabitRepository repo;

  @override
  State<HabitCompletionCalendar> createState() =>
      _HabitCompletionCalendarState();
}

class _HabitCompletionCalendarState extends State<HabitCompletionCalendar> {
  /// Currently-displayed month, anchored to the 1st. Defaults to the
  /// current month; the < / > buttons step ±1 month.
  late DateTime _anchor;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _anchor = DateTime(now.year, now.month, 1);
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _anchor.year == now.year && _anchor.month == now.month;
  }

  void _stepMonth(int delta) {
    HapticService().selection();
    setState(() {
      _anchor = DateTime(_anchor.year, _anchor.month + delta, 1);
    });
  }

  // ─── Aggregation ──────────────────────────────────────────────────

  /// (completed, scheduled) per day, indexed by `DateTime(y, m, d)`
  /// (the "day key"). Days that aren't in the visible month are
  /// missing from the map. A day with zero scheduled habits is
  /// included with (0, 0) so the cell still renders as "no data".
  Map<DateTime, _DayStat> _buildIndex() {
    final habits = widget.repo.getActiveHabits();
    final logs = widget.repo.allLogs;
    final firstOfMonth = _anchor;
    final firstOfNext =
        DateTime(_anchor.year, _anchor.month + 1, 1);

    // Index logs by (day, habitId) → log so we can decide
    // "completed?" per habit cheaply per day.
    final logByDayHabit = <DateTime, Map<String, HabitLog>>{};
    for (final l in logs) {
      final d = DateTime(l.date.year, l.date.month, l.date.day);
      if (d.isBefore(firstOfMonth) || !d.isBefore(firstOfNext)) continue;
      logByDayHabit.putIfAbsent(d, () => {})[l.habitId] = l;
    }

    final result = <DateTime, _DayStat>{};
    final daysInMonth = firstOfNext.subtract(const Duration(days: 1)).day;
    for (var i = 0; i < daysInMonth; i++) {
      final day = DateTime(firstOfMonth.year, firstOfMonth.month, i + 1);
      // Scheduled = active habits whose cadence covers this day AND
      // which existed on/before that date. We don't count a habit
      // created today against last Tuesday's grid cell.
      final scheduled = habits
          .where((h) =>
              !day.isBefore(_dayKey(h.createdAt)) &&
              h.isScheduledFor(day))
          .toList();
      final dayLogs = logByDayHabit[day] ?? const {};
      var completed = 0;
      for (final h in scheduled) {
        final log = dayLogs[h.id];
        if (log != null && log.isCompleted) completed++;
      }
      result[day] = _DayStat(completed: completed, scheduled: scheduled.length);
    }
    return result;
  }

  DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _onTapDay(DateTime day, _DayStat stat) async {
    if (stat.scheduled == 0) return;
    HapticService().selection();
    final fmt = DateFormat('EEEE, MMM d');
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DaySummarySheet(
        title: fmt.format(day),
        stat: stat,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final index = _buildIndex();
    final monthLabel = DateFormat('MMMM yyyy').format(_anchor);
    // First-of-month weekday — DateTime.weekday is Mon=1…Sun=7. We
    // render Sun-first columns to match the existing app convention,
    // so the leading-blank count is (weekday % 7).
    final leading = _anchor.weekday % 7;
    final daysInMonth =
        DateTime(_anchor.year, _anchor.month + 1, 0).day;
    final today = _dayKey(DateTime.now());

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.12),
            blurRadius: 24,
            spreadRadius: -8,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Habit calendar',
                      style: GoogleFonts.bricolageGrotesque(
                        color: BrandColors.ink(context),
                        fontSize: 19,
                        height: 1.05,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      monthLabel,
                      style: TextStyle(
                        color: BrandColors.inkDim(context),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              _NavButton(
                icon: Icons.chevron_left_rounded,
                onTap: () => _stepMonth(-1),
              ),
              const SizedBox(width: 6),
              _NavButton(
                icon: Icons.chevron_right_rounded,
                onTap: _isCurrentMonth ? null : () => _stepMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _WeekdayHeader(),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, c) {
            const cols = 7;
            const spacing = 6.0;
            final side = (c.maxWidth - spacing * (cols - 1)) / cols;
            final cells = <Widget>[
              for (var i = 0; i < leading; i++)
                SizedBox(width: side, height: side),
              for (var d = 1; d <= daysInMonth; d++)
                _DayCell(
                  size: side,
                  dayNumber: d,
                  stat: index[DateTime(_anchor.year, _anchor.month, d)] ??
                      const _DayStat(completed: 0, scheduled: 0),
                  isToday: today ==
                      DateTime(_anchor.year, _anchor.month, d),
                  isFuture: DateTime(_anchor.year, _anchor.month, d)
                      .isAfter(today),
                  onTap: () => _onTapDay(
                    DateTime(_anchor.year, _anchor.month, d),
                    index[DateTime(_anchor.year, _anchor.month, d)] ??
                        const _DayStat(completed: 0, scheduled: 0),
                  ),
                ),
            ];
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: cells,
            );
          }),
          const SizedBox(height: 10),
          _LegendBar(),
        ],
      ),
    );
  }
}

class _DayStat {
  const _DayStat({required this.completed, required this.scheduled});
  final int completed;
  final int scheduled;

  /// 0..1 completion ratio. 0 if nothing was scheduled (so the cell
  /// renders as "no data" rather than "0% complete").
  double get ratio {
    if (scheduled == 0) return 0;
    return (completed / scheduled).clamp(0.0, 1.0);
  }
}

class _WeekdayHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final l in labels)
          Expanded(
            child: Center(
              child: Text(
                l,
                style: TextStyle(
                  color: BrandColors.inkDim(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.size,
    required this.dayNumber,
    required this.stat,
    required this.isToday,
    required this.isFuture,
    required this.onTap,
  });

  final double size;
  final int dayNumber;
  final _DayStat stat;
  final bool isToday;
  final bool isFuture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasData = stat.scheduled > 0;
    final ratio = stat.ratio;
    // Brand gradient is purple→pink→pink-light at 100%; faded at low
    // completion. We use a solid fill (interpolated between purple
    // and pinkLight) for clarity at small sizes; the full gradient
    // only on a perfect day.
    final fillTone = Color.lerp(
      AppColors.purple,
      AppColors.pinkLight,
      ratio,
    )!;
    final alpha = hasData ? 0.30 + 0.60 * ratio : 0.0;
    Decoration deco;
    if (!hasData) {
      deco = BoxDecoration(
        color: BrandColors.bg(context).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: isToday ? 0.55 : 0.12),
          width: isToday ? 1.5 : 1,
        ),
      );
    } else if (ratio >= 1.0) {
      deco = BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFA855F7), // purple
            Color(0xFFEC4899), // pink
            Color(0xFFF472B6), // pink-light
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isToday
              ? AppColors.pinkLight.withValues(alpha: 0.95)
              : AppColors.pinkLight.withValues(alpha: 0.55),
          width: isToday ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.pink.withValues(alpha: 0.35),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      );
    } else {
      deco = BoxDecoration(
        color: fillTone.withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isToday
              ? AppColors.pinkLight.withValues(alpha: 0.85)
              : AppColors.purple.withValues(alpha: 0.18),
          width: isToday ? 1.5 : 1,
        ),
      );
    }

    // Future days are rendered very dim so the grid reads as
    // "month-to-date" naturally.
    final futureOverlay = isFuture
        ? Container(
            decoration: BoxDecoration(
              color: BrandColors.bgDeep(context).withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(8),
            ),
          )
        : null;

    return GestureDetector(
      onTap: (isFuture || !hasData) ? null : onTap,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: deco,
            child: Text(
              '$dayNumber',
              style: TextStyle(
                color: hasData && !isFuture
                    ? Colors.white.withValues(alpha: 0.90)
                    : BrandColors.inkDim(context).withValues(alpha: 0.65),
                fontSize: size < 22 ? 10 : 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (futureOverlay != null)
            SizedBox(width: size, height: size, child: futureOverlay),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.35 : 1.0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: BrandColors.bgCard(context).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.purple.withValues(alpha: 0.25),
            ),
          ),
          child: Icon(icon,
              color: BrandColors.inkSoft(context), size: 18),
        ),
      ),
    );
  }
}

class _LegendBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final swatches = [0.0, 0.25, 0.50, 0.75, 1.0];
    return Row(
      children: [
        Text(
          'Less',
          style: TextStyle(
            color: BrandColors.inkDim(context),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(width: 8),
        for (final r in swatches) ...[
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: r == 0
                  ? BrandColors.bg(context).withValues(alpha: 0.55)
                  : Color.lerp(AppColors.purple, AppColors.pinkLight, r)!
                      .withValues(alpha: 0.30 + 0.60 * r),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: AppColors.purple.withValues(alpha: 0.18),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
        const SizedBox(width: 4),
        Text(
          'More',
          style: TextStyle(
            color: BrandColors.inkDim(context),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

/// Tap-day summary sheet. Surfaces "N of M habits" + a one-line
/// fraction visual; deliberately simple so the calendar reads as
/// glanceable, not as another data screen the user has to manage.
class _DaySummarySheet extends StatelessWidget {
  const _DaySummarySheet({required this.title, required this.stat});
  final String title;
  final _DayStat stat;

  @override
  Widget build(BuildContext context) {
    final ratio = stat.ratio;
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
      decoration: BoxDecoration(
        color: BrandColors.bgDeep(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: BrandColors.inkFaint(context).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Text(
            title,
            style: GoogleFonts.bricolageGrotesque(
              color: BrandColors.ink(context),
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${stat.completed} of ${stat.scheduled} '
            'habit${stat.scheduled == 1 ? '' : 's'} completed',
            style: TextStyle(
              color: BrandColors.inkSoft(context),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(
                  height: 12,
                  color: BrandColors.bgCard(context),
                ),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      gradient: AppColors.buttonGradient,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
