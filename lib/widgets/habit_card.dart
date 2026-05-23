import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../models/habit_log.dart';
import '../theme/app_theme.dart';
import 'habit_log_button.dart';

class HabitCard extends StatelessWidget {
  const HabitCard({
    super.key,
    required this.habit,
    required this.todayValue,
    required this.last7,
    required this.onTap,
    required this.onIncrement,
    required this.onDecrement,
    required this.onToggle,
  });

  final Habit habit;
  final int todayValue;
  final List<HabitLog> last7;
  final VoidCallback onTap;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final color = Color(habit.color);
    final isAvoid = habit.isAvoid;
    final isReduce = habit.isReduce;
    // Build + Quit habits "lock" once the day's target is met (counter
    // full, or "stayed clean" tapped). Reduce habits NEVER lock — every
    // slip logged is data, not failure.
    final locked = !isReduce && todayValue >= habit.effectiveTarget;
    return AnimatedOpacity(
      opacity: locked ? 0.55 : 1.0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isAvoid
                    ? [
                        // Soft warm tint for avoid cards so they're
                        // visually distinct in the list without feeling
                        // alarming. Same depth as build cards.
                        AppColors.pink.withValues(alpha: 0.16),
                        BrandColors.bg(context).withValues(alpha: 0.85),
                      ]
                    : [
                        BrandColors.bgCard(context).withValues(alpha: 0.92),
                        BrandColors.bg(context).withValues(alpha: 0.85),
                      ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isAvoid
                    ? AppColors.pinkLight.withValues(alpha: 0.32)
                    : color.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _IconBubble(
                      color: isAvoid ? AppColors.pinkLight : color,
                      emoji: habit.icon,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  habit.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: BrandColors.ink(context),
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (isAvoid) ...[
                                const SizedBox(width: 6),
                                const _AvoidPill(),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          _IdentityChip(
                            identity: habit.identity,
                            color: isAvoid ? AppColors.pinkLight : color,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    IgnorePointer(
                      ignoring: locked,
                      child: _LogControl(
                        habit: habit,
                        todayValue: todayValue,
                        onIncrement: onIncrement,
                        onDecrement: onDecrement,
                        onToggle: onToggle,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (isReduce)
                  _ReduceTrend(logs: last7, todayValue: todayValue)
                else if (habit.isQuit)
                  _CleanStrip(logs: last7)
                else
                  _WeekStrip(logs: last7, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dispatches between the stepper (counter / duration / reduce) and
/// the yes/no check (build yesNo / quit). Reduce mode shows a
/// "+ slip" stepper that never disables.
class _LogControl extends StatelessWidget {
  const _LogControl({
    required this.habit,
    required this.todayValue,
    required this.onIncrement,
    required this.onDecrement,
    required this.onToggle,
  });
  final Habit habit;
  final int todayValue;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return HabitLogButton(
      habit: habit,
      value: todayValue,
      onIncrement: onIncrement,
      onDecrement: onDecrement,
      onToggle: onToggle,
      compact: true,
    );
  }
}

class _AvoidPill extends StatelessWidget {
  const _AvoidPill();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.pinkLight.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.pinkLight.withValues(alpha: 0.42),
        ),
      ),
      child: Text(
        'AVOID',
        style: TextStyle(
          color: AppColors.pinkLight,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({required this.color, required this.emoji});
  final Color color;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
        ),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 20)),
    );
  }
}

class _IdentityChip extends StatelessWidget {
  const _IdentityChip({required this.identity, required this.color});
  final String identity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        identity.toUpperCase(),
        style: TextStyle(
          color: BrandColors.inkSoft(context),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.logs, required this.color});
  final List<HabitLog> logs;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final today = DateTime(DateTime.now().year, DateTime.now().month,
        DateTime.now().day);
    final byDay = <DateTime, HabitLog>{
      for (final l in logs)
        DateTime(l.date.year, l.date.month, l.date.day): l,
    };

    return Row(
      children: [
        for (var i = 6; i >= 0; i--) ...[
          Expanded(
            child: _Dot(
              ratio: byDay[today.subtract(Duration(days: i))]
                      ?.completionPercentage ??
                  0,
              color: color,
              isToday: i == 0,
            ),
          ),
          if (i > 0) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.ratio,
    required this.color,
    required this.isToday,
  });

  final double ratio;
  final Color color;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final filled = ratio > 0;
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: filled
            ? color.withValues(alpha: 0.25 + 0.65 * ratio.clamp(0.0, 1.0))
            : BrandColors.bg(context).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isToday
              ? AppColors.pinkLight.withValues(alpha: 0.8)
              : AppColors.purple.withValues(alpha: 0.08),
          width: isToday ? 1.4 : 1,
        ),
      ),
    );
  }
}

/// For QUIT habits: 7-day strip of clean-day dots in pink so each "stayed
/// clean" tap reads as a gentle win. Missing days are neutral (not red).
class _CleanStrip extends StatelessWidget {
  const _CleanStrip({required this.logs});
  final List<HabitLog> logs;

  @override
  Widget build(BuildContext context) {
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final clean = <DateTime>{
      for (final l in logs)
        if (l.value > 0) DateTime(l.date.year, l.date.month, l.date.day),
    };
    return Row(
      children: [
        for (var i = 6; i >= 0; i--) ...[
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: clean.contains(today.subtract(Duration(days: i)))
                    ? AppColors.pinkLight.withValues(alpha: 0.65)
                    : BrandColors.bg(context).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: i == 0
                      ? AppColors.pinkLight.withValues(alpha: 0.85)
                      : AppColors.pink.withValues(alpha: 0.10),
                  width: i == 0 ? 1.4 : 1,
                ),
              ),
            ),
          ),
          if (i > 0) const SizedBox(width: 4),
        ],
      ],
    );
  }
}

/// For REDUCE habits: an inline sparkline of the last 7 days' counts
/// plus a directional phrase. Frames downward movement positively; if
/// today is up from yesterday it just stays neutral.
class _ReduceTrend extends StatelessWidget {
  const _ReduceTrend({required this.logs, required this.todayValue});
  final List<HabitLog> logs;
  final int todayValue;

  @override
  Widget build(BuildContext context) {
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final byDay = <DateTime, HabitLog>{
      for (final l in logs)
        DateTime(l.date.year, l.date.month, l.date.day): l,
    };
    final series = <int>[
      for (var i = 6; i >= 0; i--)
        byDay[today.subtract(Duration(days: i))]?.value ?? 0,
    ];
    final yesterday = series.length >= 2 ? series[series.length - 2] : 0;
    final phrase = _phrase(today: todayValue, yesterday: yesterday);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 28,
          child: CustomPaint(
            painter: _SparklinePainter(values: series),
            size: const Size.fromHeight(28),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              phrase.icon,
              size: 12,
              color: phrase.color,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                phrase.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: phrase.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            Text(
              '$todayValue today',
              style: TextStyle(
                color: BrandColors.inkSoft(context),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }

  _ReducePhrase _phrase({required int today, required int yesterday}) {
    if (today == 0 && yesterday == 0) {
      return _ReducePhrase(
        text: 'Clean run — keep going',
        color: AppColors.purpleLight,
        icon: Icons.spa_rounded,
      );
    }
    if (today == 0 && yesterday > 0) {
      return _ReducePhrase(
        text: 'Zero today — beautiful',
        color: AppColors.pinkLight,
        icon: Icons.south_rounded,
      );
    }
    if (today < yesterday) {
      return _ReducePhrase(
        text: 'Down from yesterday — good direction',
        color: AppColors.pinkLight,
        icon: Icons.south_rounded,
      );
    }
    if (today == yesterday) {
      return _ReducePhrase(
        text: 'Holding steady',
        color: AppColors.purpleLight,
        icon: Icons.east_rounded,
      );
    }
    return _ReducePhrase(
      text: 'Tomorrow is a fresh chance',
      color: AppColors.purpleLight,
      icon: Icons.refresh_rounded,
    );
  }
}

class _ReducePhrase {
  const _ReducePhrase({
    required this.text,
    required this.color,
    required this.icon,
  });
  final String text;
  final Color color;
  final IconData icon;
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.values});
  final List<int> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxVal =
        values.fold<int>(0, (m, v) => v > m ? v : m).clamp(1, 1 << 20);
    final stepX = values.length <= 1 ? size.width : size.width / (values.length - 1);
    final pts = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          i * stepX,
          size.height - (values[i] / maxVal) * (size.height - 4) - 2,
        ),
    ];
    final line = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.purple.withValues(alpha: 0.85),
          AppColors.pinkLight.withValues(alpha: 0.95),
        ],
      ).createShader(Offset.zero & size)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 2;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, line);
    final dot = Paint()..color = AppColors.pinkLight;
    canvas.drawCircle(pts.last, 3, dot);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values.length != values.length ||
      !_listEq(old.values, values);

  bool _listEq(List<int> a, List<int> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
