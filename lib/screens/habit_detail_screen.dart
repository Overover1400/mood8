import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/frequency.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/habit_type.dart';
import '../models/routine_category.dart';
import '../services/habit_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/add_habit_sheet.dart';
import '../widgets/habit_log_button.dart';
import '../widgets/streak_calendar.dart';

class HabitDetailScreen extends StatefulWidget {
  const HabitDetailScreen({super.key, required this.habitId});
  final String habitId;

  @override
  State<HabitDetailScreen> createState() => _HabitDetailScreenState();
}

class _HabitDetailScreenState extends State<HabitDetailScreen> {
  final HabitRepository _repo = HabitRepository();
  late final ValueListenable<Box<Habit>> _habitListenable =
      _repo.watchHabits();
  late final ValueListenable<Box<HabitLog>> _logListenable =
      _repo.watchLogs();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: ValueListenableBuilder<Box<Habit>>(
          valueListenable: _habitListenable,
          builder: (context, _, _) => ValueListenableBuilder<Box<HabitLog>>(
            valueListenable: _logListenable,
            builder: (context, _, _) {
              final habit = _repo
                  .getAllHabits()
                  .firstWhere(
                    (h) => h.id == widget.habitId,
                    orElse: () => _missing(),
                  );
              if (habit.id == 'missing') {
                return const Center(
                  child: Text(
                    'This habit no longer exists.',
                    style: TextStyle(color: AppColors.inkDim),
                  ),
                );
              }
              final color = Color(habit.color);
              final logs = _repo.getLast30Days(habit.id);
              final todayLog =
                  _repo.getLogForDate(habit.id, DateTime.now());
              final streak = _repo.getStreakForHabit(habit.id);
              final best = _repo.getBestStreak(habit.id);
              final completion = _repo.getCompletionRate(habit.id, 30);

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _TopBar(
                      onEdit: () => showAddHabitSheet(context, editing: habit),
                      onDelete: () => _confirmDelete(habit),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _Header(habit: habit, color: color),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: _LogRow(
                        habit: habit,
                        todayValue: todayLog?.value ?? 0,
                        repo: _repo,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: _StatsRow(
                        streak: streak,
                        best: best,
                        completion: completion,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 24, 20, 12),
                      child: _SectionHeader(label: '30-Day Heatmap'),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                      child: StreakCalendar(
                        logs: logs,
                        color: color,
                        frozenDates: habit.frozenDates,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 24, 20, 12),
                      child: _SectionHeader(label: 'Recent activity'),
                    ),
                  ),
                  if (logs.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: Text(
                          'No entries yet. Log the first one above.',
                          style: TextStyle(
                            color: AppColors.inkDim,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  else
                    SliverList.builder(
                      itemCount: logs.length.clamp(0, 10),
                      itemBuilder: (context, i) => Padding(
                        padding: EdgeInsets.fromLTRB(
                            20, 0, 20, i == logs.length - 1 ? 24 : 10),
                        child: _LogTile(log: logs[i], color: color),
                      ),
                    ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 40),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Habit _missing() => Habit(
        id: 'missing',
        title: '',
        icon: '',
        habitType: HabitType.yesNo,
        identity: '',
        category: RoutineCategory.work,
        frequency: Frequency.daily,
        color: 0,
        createdAt: DateTime.now(),
      );

  Future<void> _confirmDelete(Habit habit) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text(
          'Delete habit?',
          style: TextStyle(color: AppColors.ink),
        ),
        content: const Text(
          'This removes the habit and all logs for it.',
          style: TextStyle(color: AppColors.inkSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Color(0xFFFF6B81)),
            ),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _repo.deleteHabit(habit.id);
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop();
    }
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onEdit, required this.onDelete});
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppColors.inkSoft, size: 18),
          ),
          const Spacer(),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined,
                color: AppColors.inkSoft, size: 20),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded,
                color: Color(0xFFFF6B81), size: 20),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.habit, required this.color});
  final Habit habit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  color.withValues(alpha: 0.65),
                  color.withValues(alpha: 0.12),
                ],
              ),
              border: Border.all(
                color: color.withValues(alpha: 0.45),
              ),
            ),
            child: Text(habit.icon, style: const TextStyle(fontSize: 26)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.title,
                  style:
                      Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontSize: 24,
                          ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${habit.identity} · ${habit.frequency.label}',
                  style: TextStyle(
                    color: AppColors.inkDim,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms)
        .slideY(begin: 0.04, end: 0, curve: Curves.easeOut);
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({
    required this.habit,
    required this.todayValue,
    required this.repo,
  });

  final Habit habit;
  final int todayValue;
  final HabitRepository repo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TODAY',
                  style: TextStyle(
                    color: AppColors.inkDim,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  todayValue >= habit.effectiveTarget
                      ? 'Done — nice.'
                      : 'Log this rep.',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          HabitLogButton(
            habit: habit,
            value: todayValue,
            onIncrement: () {
              HapticFeedback.selectionClick();
              final step = habit.targetUnit?.toLowerCase().contains('minute') == true
                  ? 5
                  : 1;
              repo.incrementLog(habitId: habit.id, by: step);
            },
            onDecrement: () {
              HapticFeedback.selectionClick();
              final step = habit.targetUnit?.toLowerCase().contains('minute') == true
                  ? 5
                  : 1;
              repo.incrementLog(habitId: habit.id, by: -step);
            },
            onToggle: () {
              HapticFeedback.mediumImpact();
              repo.toggleYesNoLog(habitId: habit.id);
            },
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({
    required this.streak,
    required this.best,
    required this.completion,
  });

  final int streak;
  final int best;
  final double completion;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            emoji: '🔥',
            label: 'Streak',
            value: '$streak',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            emoji: '📊',
            label: '30 days',
            value: '${(completion * 100).round()}%',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            emoji: '🏆',
            label: 'Best',
            value: '$best',
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.emoji,
    required this.label,
    required this.value,
  });

  final String emoji;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.instrumentSerif(
              color: AppColors.ink,
              fontStyle: FontStyle.italic,
              fontSize: 22,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: AppColors.inkDim,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Text(
        label.toUpperCase(),
        style: TextStyle(
          color: AppColors.inkDim,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
        ),
      );
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log, required this.color});
  final HabitLog log;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEE, MMM d').format(log.date);
    final time = DateFormat('HH:mm').format(log.timestamp);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.16),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.20),
            ),
            alignment: Alignment.center,
            child: Icon(
              log.isCompleted
                  ? Icons.check_rounded
                  : Icons.access_time_rounded,
              size: 14,
              color: log.isCompleted ? color : AppColors.inkDim,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              date,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '${log.value} / ${log.targetValue}',
            style: GoogleFonts.instrumentSerif(
              color: AppColors.ink,
              fontStyle: FontStyle.italic,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: TextStyle(
              color: AppColors.inkDim,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
