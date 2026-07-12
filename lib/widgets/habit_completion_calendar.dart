import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/habit_log.dart';
import '../services/habit_repository.dart';
import '../services/haptic_service.dart';
import '../theme/app_theme.dart';

/// Compact-first calendar widget. Default state is a single-line
/// horizontal week strip — 7 day circles for the currently-visible
/// week, each tinted by that day's overall habit completion ratio.
/// Today is highlighted with a ring. Horizontal swipe = navigate to
/// the previous week; the strip clamps at the current week (no
/// future navigation).
///
/// Tap the expand chevron on the right to unfurl the full month grid
/// (the old heatmap, still available). Collapses back with the same
/// chevron. Tap any day (in either mode) opens the small
/// `_DaySummarySheet` with "N of M habits" for that day.
///
/// The aggregation logic (per-day completion count vs. scheduled)
/// hasn't changed — it's just been generalized to work over an
/// arbitrary date range so we can serve either the 7-day strip or
/// the whole month from the same pass.
class HabitCompletionCalendar extends StatefulWidget {
  const HabitCompletionCalendar({super.key, required this.repo});

  final HabitRepository repo;

  @override
  State<HabitCompletionCalendar> createState() =>
      _HabitCompletionCalendarState();
}

class _HabitCompletionCalendarState extends State<HabitCompletionCalendar> {
  /// Sunday of the currently-visible week in the compact strip.
  /// Sunday-first matches the existing app convention.
  late DateTime _weekAnchor;

  /// First of the currently-visible month in the expanded grid.
  /// Only used when [_expanded] is true.
  late DateTime _monthAnchor;

  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _weekAnchor = _startOfWeek(today);
    _monthAnchor = DateTime(now.year, now.month, 1);
  }

  DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Sunday-first: DateTime.weekday is Mon=1…Sun=7 so `d.weekday % 7`
  /// is Sun=0, Mon=1, …, Sat=6. Subtracting that many days lands on
  /// the Sunday of that week.
  DateTime _startOfWeek(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday % 7));

  bool get _isCurrentWeek {
    final now = DateTime.now();
    return _startOfWeek(now) == _weekAnchor;
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _monthAnchor.year == now.year &&
        _monthAnchor.month == now.month;
  }

  void _stepWeek(int delta) {
    HapticService().selection();
    setState(() {
      _weekAnchor = _weekAnchor.add(Duration(days: 7 * delta));
    });
  }

  void _stepMonth(int delta) {
    HapticService().selection();
    setState(() {
      _monthAnchor = DateTime(
        _monthAnchor.year, _monthAnchor.month + delta, 1,
      );
    });
  }

  void _toggleExpanded() {
    HapticService().selection();
    setState(() => _expanded = !_expanded);
  }

  // ─── Aggregation ──────────────────────────────────────────────────
  //
  // Same "which habits were scheduled + which got completed" logic
  // that used to live inline; now generalized to accept an inclusive
  // date range so the compact strip + month grid share one pass.

  Map<DateTime, _DayStat> _buildIndex(DateTime from, DateTime toExclusive) {
    final habits = widget.repo.getActiveHabits();
    final logs = widget.repo.allLogs;

    final logByDayHabit = <DateTime, Map<String, HabitLog>>{};
    for (final l in logs) {
      final d = DateTime(l.date.year, l.date.month, l.date.day);
      if (d.isBefore(from) || !d.isBefore(toExclusive)) continue;
      logByDayHabit.putIfAbsent(d, () => {})[l.habitId] = l;
    }

    final result = <DateTime, _DayStat>{};
    var cursor = from;
    while (cursor.isBefore(toExclusive)) {
      final day = _dayKey(cursor);
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
      result[day] =
          _DayStat(completed: completed, scheduled: scheduled.length);
      cursor = cursor.add(const Duration(days: 1));
    }
    return result;
  }

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
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CompactWeekStrip(
            weekAnchor: _weekAnchor,
            index: _buildIndex(
              _weekAnchor,
              _weekAnchor.add(const Duration(days: 7)),
            ),
            isCurrentWeek: _isCurrentWeek,
            expanded: _expanded,
            onToggleExpanded: _toggleExpanded,
            onPrevWeek: () => _stepWeek(-1),
            onNextWeek: _isCurrentWeek ? null : () => _stepWeek(1),
            onTapDay: _onTapDay,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: _MonthGrid(
                      anchor: _monthAnchor,
                      isCurrentMonth: _isCurrentMonth,
                      index: _monthAggregation(),
                      onPrevMonth: () => _stepMonth(-1),
                      onNextMonth:
                          _isCurrentMonth ? null : () => _stepMonth(1),
                      onTapDay: _onTapDay,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Map<DateTime, _DayStat> _monthAggregation() {
    final firstOfMonth = _monthAnchor;
    final firstOfNext =
        DateTime(_monthAnchor.year, _monthAnchor.month + 1, 1);
    return _buildIndex(firstOfMonth, firstOfNext);
  }
}

// ─── Compact one-line week strip ─────────────────────────────────────

class _CompactWeekStrip extends StatelessWidget {
  const _CompactWeekStrip({
    required this.weekAnchor,
    required this.index,
    required this.isCurrentWeek,
    required this.expanded,
    required this.onToggleExpanded,
    required this.onPrevWeek,
    required this.onNextWeek,
    required this.onTapDay,
  });

  final DateTime weekAnchor;
  final Map<DateTime, _DayStat> index;
  final bool isCurrentWeek;
  final bool expanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback onPrevWeek;
  final VoidCallback? onNextWeek;
  final Future<void> Function(DateTime day, _DayStat stat) onTapDay;

  static const _dowLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayKey = DateTime(today.year, today.month, today.day);
    final rangeLabel = _weekRangeLabel(weekAnchor);
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        // Right swipe (positive velocity) → previous week; left
        // swipe → next week when we're not already on the current.
        final v = details.primaryVelocity ?? 0;
        if (v > 250) onPrevWeek();
        if (v < -250 && onNextWeek != null) onNextWeek!();
      },
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          // Tiny header row: week range + expand chevron. Tap the
          // range label to jump back to today's week when we've
          // scrolled into the past.
          Row(
            children: [
              GestureDetector(
                onTap: isCurrentWeek ? null : onPrevWeek,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 2),
                  child: Text(
                    rangeLabel,
                    style: TextStyle(
                      color: BrandColors.inkDim(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              // Small "swipe hint" arrows — only render the prev
              // hint on the current week (there's no next).
              if (isCurrentWeek)
                Icon(
                  Icons.chevron_left_rounded,
                  color: BrandColors.inkFaint(context),
                  size: 16,
                ),
              InkWell(
                onTap: onToggleExpanded,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      Icons.expand_more_rounded,
                      color: BrandColors.inkSoft(context),
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++) ...[
                _DayPip(
                  dow: _dowLabels[(weekAnchor.weekday % 7 + i) % 7],
                  day: weekAnchor.add(Duration(days: i)),
                  stat: index[weekAnchor.add(Duration(days: i))] ??
                      const _DayStat(completed: 0, scheduled: 0),
                  isToday: weekAnchor.add(Duration(days: i)) == todayKey,
                  isFuture:
                      weekAnchor.add(Duration(days: i)).isAfter(todayKey),
                  onTap: () => onTapDay(
                    weekAnchor.add(Duration(days: i)),
                    index[weekAnchor.add(Duration(days: i))] ??
                        const _DayStat(completed: 0, scheduled: 0),
                  ),
                ),
                if (i < 6) const SizedBox(width: 4),
              ],
            ],
          ),
        ],
      ),
    );
  }

  String _weekRangeLabel(DateTime start) {
    final end = start.add(const Duration(days: 6));
    final now = DateTime.now();
    if (start.isBefore(DateTime(now.year, now.month, now.day)) &&
        end.isBefore(DateTime(now.year, now.month, now.day)) == false &&
        start.year == now.year) {
      // Contains today or spans across it. Use "This week · MMM d–d".
      // Kept short so the header stays compact.
    }
    // Format: "Jun 8 – Jun 14" (or "Jun 30 – Jul 6" across months).
    final fmtSame = DateFormat('MMM d');
    if (start.month == end.month) {
      return '${fmtSame.format(start)} – ${DateFormat('d').format(end)}';
    }
    return '${fmtSame.format(start)} – ${fmtSame.format(end)}';
  }
}

/// One day pill inside the compact strip. Fixed max width so a 7-day
/// row stays under ~340 px even with big display scaling.
class _DayPip extends StatelessWidget {
  const _DayPip({
    required this.dow,
    required this.day,
    required this.stat,
    required this.isToday,
    required this.isFuture,
    required this.onTap,
  });

  final String dow;
  final DateTime day;
  final _DayStat stat;
  final bool isToday;
  final bool isFuture;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasData = stat.scheduled > 0 && !isFuture;
    final ratio = stat.ratio;
    final fillTone = Color.lerp(
      AppColors.purple,
      AppColors.pinkLight,
      ratio,
    )!;
    final alpha = hasData ? 0.30 + 0.60 * ratio : 0.0;

    Decoration circleDeco;
    if (!hasData && !isFuture) {
      // Today or past day with nothing scheduled.
      circleDeco = BoxDecoration(
        color: BrandColors.bg(context).withValues(alpha: 0.55),
        shape: BoxShape.circle,
        border: Border.all(
          color: isToday
              ? AppColors.pinkLight
              : AppColors.purple.withValues(alpha: 0.15),
          width: isToday ? 1.6 : 1,
        ),
      );
    } else if (isFuture) {
      circleDeco = BoxDecoration(
        color: BrandColors.bgDeep(context).withValues(alpha: 0.35),
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.10),
        ),
      );
    } else if (ratio >= 1.0) {
      circleDeco = BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFA855F7),
            Color(0xFFEC4899),
            Color(0xFFF472B6),
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(
          color: isToday
              ? AppColors.pinkLight
              : AppColors.pinkLight.withValues(alpha: 0.55),
          width: isToday ? 1.8 : 1,
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
      circleDeco = BoxDecoration(
        color: fillTone.withValues(alpha: alpha),
        shape: BoxShape.circle,
        border: Border.all(
          color: isToday
              ? AppColors.pinkLight
              : AppColors.purple.withValues(alpha: 0.20),
          width: isToday ? 1.6 : 1,
        ),
      );
    }

    return Expanded(
      child: GestureDetector(
        onTap: (isFuture || !hasData) ? null : onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              dow,
              style: TextStyle(
                color: isToday
                    ? AppColors.pinkLight
                    : BrandColors.inkDim(context),
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: circleDeco,
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: hasData && ratio >= 0.5
                      ? Colors.white
                      : isFuture
                          ? BrandColors.inkFaint(context)
                          : BrandColors.inkSoft(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Expanded month grid (the previous default) ──────────────────────

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.anchor,
    required this.isCurrentMonth,
    required this.index,
    required this.onPrevMonth,
    required this.onNextMonth,
    required this.onTapDay,
  });

  final DateTime anchor;
  final bool isCurrentMonth;
  final Map<DateTime, _DayStat> index;
  final VoidCallback onPrevMonth;
  final VoidCallback? onNextMonth;
  final Future<void> Function(DateTime day, _DayStat stat) onTapDay;

  DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy').format(anchor);
    final leading = anchor.weekday % 7;
    final daysInMonth =
        DateTime(anchor.year, anchor.month + 1, 0).day;
    final today = _dayKey(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                monthLabel,
                style: GoogleFonts.bricolageGrotesque(
                  color: BrandColors.ink(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _NavButton(
              icon: Icons.chevron_left_rounded,
              onTap: onPrevMonth,
            ),
            const SizedBox(width: 6),
            _NavButton(
              icon: Icons.chevron_right_rounded,
              onTap: onNextMonth,
            ),
          ],
        ),
        const SizedBox(height: 10),
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
                stat: index[DateTime(anchor.year, anchor.month, d)] ??
                    const _DayStat(completed: 0, scheduled: 0),
                isToday: today ==
                    DateTime(anchor.year, anchor.month, d),
                isFuture: DateTime(anchor.year, anchor.month, d)
                    .isAfter(today),
                onTap: () => onTapDay(
                  DateTime(anchor.year, anchor.month, d),
                  index[DateTime(anchor.year, anchor.month, d)] ??
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
        const SizedBox(height: 8),
        _LegendBar(),
      ],
    );
  }
}

class _DayStat {
  const _DayStat({required this.completed, required this.scheduled});
  final int completed;
  final int scheduled;

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
            Color(0xFFA855F7),
            Color(0xFFEC4899),
            Color(0xFFF472B6),
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: BrandColors.bgCard(context).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.purple.withValues(alpha: 0.22),
            ),
          ),
          child: Icon(icon,
              color: BrandColors.inkSoft(context), size: 16),
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
