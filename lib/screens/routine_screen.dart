import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/routine_item.dart';
import '../services/routine_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/add_routine_sheet.dart';
import '../widgets/empty_state.dart';
import '../widgets/routine_card_v2.dart';

enum _DayTab { today, tomorrow }

class RoutineScreen extends StatefulWidget {
  const RoutineScreen({super.key});

  @override
  State<RoutineScreen> createState() => _RoutineScreenState();
}

class _RoutineScreenState extends State<RoutineScreen> {
  final RoutineRepository _repo = RoutineRepository();
  late final ValueListenable<Box<RoutineItem>> _listenable =
      _repo.watchRoutines();
  _DayTab _tab = _DayTab.today;

  DateTime get _targetDate {
    final now = DateTime.now();
    return _tab == _DayTab.today
        ? now
        : now.add(const Duration(days: 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          const _BackgroundGlow(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: ValueListenableBuilder<Box<RoutineItem>>(
                  valueListenable: _listenable,
                  builder: (context, box, _) {
                    final items = _repo.getRoutinesForDate(_targetDate);
                    final percent =
                        _repo.getCompletionPercentage(_targetDate);
                    final currentId =
                        _tab == _DayTab.today ? _repo.getCurrentRoutine()?.id : null;
                    assert(() {
                      debugPrint(
                          'RoutineScreen: box=${box.length} visible=${items.length} tab=$_tab');
                      return true;
                    }());
                    return CustomScrollView(
                      key: const PageStorageKey('routine_scroll'),
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20, 16, 20, 0),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const _HeaderBar()
                                    .animate()
                                    .fadeIn(duration: 400.ms)
                                    .slideY(
                                        begin: -0.1,
                                        end: 0,
                                        curve: Curves.easeOut),
                                const SizedBox(height: 20),
                                _TabToggle(
                                  value: _tab,
                                  onChanged: (t) =>
                                      setState(() => _tab = t),
                                )
                                    .animate()
                                    .fadeIn(delay: 60.ms, duration: 400.ms),
                                const SizedBox(height: 18),
                                _ProgressCard(
                                  completed: items
                                      .where((r) => r.isCompleted)
                                      .length,
                                  total: items.length,
                                  percent: percent,
                                  isFuture: _tab == _DayTab.tomorrow,
                                )
                                    .animate()
                                    .fadeIn(
                                        delay: 120.ms, duration: 450.ms)
                                    .slideY(
                                        begin: 0.06,
                                        end: 0,
                                        curve: Curves.easeOut),
                                const SizedBox(height: 22),
                              ],
                            ),
                          ),
                        ),
                        if (items.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: EmptyState(
                              icon: Icons.event_note_rounded,
                              title: 'No routines yet',
                              subtitle:
                                  'Tap the + button to add your first one.',
                              ctaLabel: 'Add routine',
                              onCta: () => _openSheet(context),
                            ),
                          )
                        else
                          _Timeline(
                            items: items,
                            currentId: currentId,
                            completable: _tab == _DayTab.today,
                            onTapItem: (it) =>
                                _openSheet(context, editing: it),
                            onToggle: (it) async {
                              if (it.isCompleted) {
                                it.isCompleted = false;
                                it.completedAt = null;
                                await _repo.updateRoutine(it);
                              } else {
                                await _repo.markComplete(it.id);
                              }
                            },
                            onReorder: (oldIndex, newIndex) =>
                                _repo.reorder(oldIndex, newIndex),
                            onDelete: (it) async {
                              HapticFeedback.mediumImpact();
                              await _repo.deleteRoutine(it.id);
                            },
                          ),
                        const SliverToBoxAdapter(
                          child: SizedBox(height: 180),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          Positioned(
            right: 24,
            bottom: 110,
            child: _Fab(onTap: () => _openSheet(context))
                .animate()
                .fadeIn(delay: 250.ms, duration: 400.ms)
                .scaleXY(begin: 0.7, end: 1.0, curve: Curves.easeOutBack),
          ),
        ],
      ),
    );
  }

  Future<void> _openSheet(BuildContext context, {RoutineItem? editing}) {
    HapticFeedback.selectionClick();
    return showAddRoutineSheet(context, editing: editing);
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -100,
              left: -60,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.purple.withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              right: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.pink.withValues(alpha: 0.20),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderBar extends StatelessWidget {
  const _HeaderBar();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Routine',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontSize: 32,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          'Your daily flow',
          style: TextStyle(
            color: AppColors.inkDim,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _TabToggle extends StatelessWidget {
  const _TabToggle({required this.value, required this.onChanged});
  final _DayTab value;
  final ValueChanged<_DayTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          for (final t in _DayTab.values)
            Expanded(
              child: _TabButton(
                label: t == _DayTab.today ? 'Today' : 'Tomorrow',
                selected: t == value,
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(t);
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.buttonGradient : null,
          borderRadius: BorderRadius.circular(22),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.pink.withValues(alpha: 0.40),
                    blurRadius: 18,
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 220),
          style: TextStyle(
            color: selected ? Colors.white : AppColors.inkDim,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            letterSpacing: 0.3,
          ),
          child: Text(label),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.completed,
    required this.total,
    required this.percent,
    required this.isFuture,
  });

  final int completed;
  final int total;
  final double percent;
  final bool isFuture;

  @override
  Widget build(BuildContext context) {
    final pctLabel = isFuture
        ? 'Planned'
        : '${(percent * 100).round()}%';
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isFuture
                      ? '$total scheduled'
                      : '$completed of $total complete',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                pctLabel,
                style: TextStyle(
                  color: isFuture
                      ? AppColors.purpleLight
                      : AppColors.pinkLight,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Container(
                  height: 10,
                  color: AppColors.bg.withValues(alpha: 0.7),
                ),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  widthFactor: isFuture ? 0 : percent.clamp(0, 1),
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: AppColors.buttonGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.pink.withValues(alpha: 0.45),
                          blurRadius: 12,
                        ),
                      ],
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

class _TimeOfDay {
  const _TimeOfDay(this.label, this.fromHour, this.toHour);
  final String label;
  final int fromHour;
  final int toHour;

  bool contains(int hour) {
    if (fromHour <= toHour) {
      return hour >= fromHour && hour <= toHour;
    }
    return hour >= fromHour || hour <= toHour;
  }
}

const List<_TimeOfDay> _kGroups = [
  _TimeOfDay('Morning', 5, 11),
  _TimeOfDay('Afternoon', 12, 17),
  _TimeOfDay('Evening', 18, 23),
  _TimeOfDay('Night', 0, 4),
];

_TimeOfDay _groupFor(DateTime t) {
  for (final g in _kGroups) {
    if (g.contains(t.hour)) return g;
  }
  return _kGroups.first;
}

class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.items,
    required this.currentId,
    required this.completable,
    required this.onTapItem,
    required this.onToggle,
    required this.onReorder,
    required this.onDelete,
  });

  final List<RoutineItem> items;
  final String? currentId;
  final bool completable;
  final void Function(RoutineItem) onTapItem;
  final Future<void> Function(RoutineItem) onToggle;
  final Future<void> Function(int, int) onReorder;
  final Future<void> Function(RoutineItem) onDelete;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverReorderableList(
        itemCount: items.length,
        onReorder: (oldIndex, newIndex) async {
          HapticFeedback.lightImpact();
          await onReorder(oldIndex, newIndex);
        },
        itemBuilder: (context, index) {
          final item = items[index];
          final showHeader = index == 0 ||
              _groupFor(items[index - 1].time).label !=
                  _groupFor(item.time).label;
          return Padding(
            key: ValueKey(item.id),
            padding: EdgeInsets.only(top: showHeader ? 6 : 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showHeader) ...[
                  _GroupHeader(label: _groupFor(item.time).label),
                  const SizedBox(height: 10),
                ],
                ReorderableDelayedDragStartListener(
                  index: index,
                  child: Dismissible(
                    key: ValueKey('dis-${item.id}'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B81)
                            .withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.delete_outline_rounded,
                              color: Color(0xFFFF6B81)),
                          SizedBox(width: 8),
                          Text(
                            'Delete',
                            style: TextStyle(
                              color: Color(0xFFFF6B81),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    confirmDismiss: (_) async {
                      await onDelete(item);
                      return false;
                    },
                    child: RoutineCardV2(
                      item: item,
                      isCurrent: item.id == currentId,
                      completable: completable,
                      onTap: () => onTapItem(item),
                      onToggleComplete: () => onToggle(item),
                    ),
                  ),
                ),
              ],
            ),
          )
              .animate(delay: (40 * index).ms)
              .fadeIn(duration: 350.ms)
              .slideY(begin: 0.06, end: 0, curve: Curves.easeOut);
        },
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.buttonGradient,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: AppColors.inkDim,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _Fab extends StatelessWidget {
  const _Fab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.buttonGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.pink.withValues(alpha: 0.55),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
            BoxShadow(
              color: AppColors.purple.withValues(alpha: 0.45),
              blurRadius: 30,
              spreadRadius: -4,
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}
