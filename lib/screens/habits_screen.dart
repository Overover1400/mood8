import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/habit_packages.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/sfx_type.dart';
import '../services/badge_service.dart';
import '../services/effects_service.dart';
import '../services/habit_repository.dart';
import '../services/haptic_service.dart';
import '../services/milestone_service.dart';
import '../services/sfx_service.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/add_habit_sheet.dart';
import '../widgets/badge_unlock_modal.dart';
import '../widgets/tutorial_targets.dart';
import '../widgets/empty_state.dart';
import '../widgets/freeze_badge.dart';
import '../widgets/freeze_modal.dart';
import '../widgets/habit_card.dart';
import '../widgets/responsive_container.dart';
import '../widgets/tutorial_overlay.dart';
import 'habit_detail_screen.dart';
import 'habit_packages_screen.dart';

import '../models/user_profile.dart';
import '../services/freeze_service.dart';

const String _kAllFilter = '__all__';
/// Synthetic filter that surfaces only avoid-type habits. Sits next
/// to the identity chips in [_IdentityFilter].
const String _kAvoidFilter = '__avoid__';
/// Surfaces only Coach-designed (aiManaged=true) habits. Appears
/// between the avoid chip and the per-package chips when the user
/// has at least one AI-managed habit. Build 1 of 3 — future builds
/// will hang failure-recovery + program-progress UI off this filter.
const String _kAiManagedFilter = '__ai_managed__';
/// Prefix used by per-package filter chips. The remainder of the
/// string is the package id (e.g. "__pkg__pkg.morning_calm").
const String _kPackagePrefix = '__pkg__';

class HabitsScreen extends StatefulWidget {
  const HabitsScreen({super.key});

  @override
  State<HabitsScreen> createState() => _HabitsScreenState();
}

/// Habit list sort modes — persisted in SharedPreferences via
/// [_kSortPrefKey]. Manual mode flips the list into a
/// ReorderableListView with drag handles; the manual order itself
/// rides on the existing `sortOrder` field (already synced).
enum HabitSortMode { dateAdded, az, za, manual }

const String _kHabitSortPrefKey = 'mood8.habitSortMode';

class _HabitsScreenState extends State<HabitsScreen> {
  final HabitRepository _repo = HabitRepository();
  final UserRepository _userRepo = UserRepository();
  late final ValueListenable<Box<Habit>> _habitListenable =
      _repo.watchHabits();
  late final ValueListenable<Box<HabitLog>> _logListenable =
      _repo.watchLogs();

  String _filter = _kAllFilter;
  HabitSortMode _sortMode = HabitSortMode.dateAdded;
  /// When Manual sort is selected, drag-to-reorder is OFF by default
  /// (handles hidden, list locked). The user explicitly taps
  /// "Reorder" to enable handles, then "Done" to lock them again.
  /// Stops accidental drags when the user just wants to interact
  /// with habit cards.
  bool _manualReorderActive = false;

  @override
  void initState() {
    super.initState();
    _loadSortPref();
  }

  Future<void> _loadSortPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kHabitSortPrefKey);
      if (raw == null) return;
      final mode = HabitSortMode.values.firstWhere(
        (m) => m.name == raw,
        orElse: () => HabitSortMode.dateAdded,
      );
      if (mounted) setState(() => _sortMode = mode);
    } catch (_) {/* fallback to default */}
  }

  Future<void> _setSortMode(HabitSortMode mode) async {
    if (mode == _sortMode) return;
    HapticService().selection();
    setState(() {
      _sortMode = mode;
      // Entering Manual mode opens reorder so the user can immediately
      // arrange. Switching AWAY from Manual locks again.
      _manualReorderActive = mode == HabitSortMode.manual;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kHabitSortPrefKey, mode.name);
    } catch (_) {}
  }

  List<Habit> _applySort(List<Habit> list) {
    final out = [...list];
    switch (_sortMode) {
      case HabitSortMode.dateAdded:
        out.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case HabitSortMode.az:
        out.sort((a, b) =>
            a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case HabitSortMode.za:
        out.sort((a, b) =>
            b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case HabitSortMode.manual:
        out.sort((a, b) {
          final c = a.sortOrder.compareTo(b.sortOrder);
          if (c != 0) return c;
          return a.createdAt.compareTo(b.createdAt);
        });
        break;
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      body: Stack(
        children: [
          const _BackgroundGlow(),
          SafeArea(
            child: ResponsiveContainer(
              maxWidth: 560,
              child: ValueListenableBuilder<Box<Habit>>(
                  valueListenable: _habitListenable,
                  builder: (context, habitBox, _) =>
                      ValueListenableBuilder<Box<HabitLog>>(
                    valueListenable: _logListenable,
                    builder: (context, logBox, _) {
                      final today = DateTime.now();
                      final all = _repo.getActiveHabits();
                      final user = _userRepo.getCurrentUser();
                      final identities = <String>{
                        for (final h in all) h.identity,
                        ...?user?.identities,
                      }.toList();

                      final scheduled =
                          all.where((h) => h.isScheduledFor(today)).toList();
                      var visible = switch (_filter) {
                        _kAllFilter => all,
                        _kAvoidFilter =>
                          all.where((h) => h.isAvoid).toList(),
                        _kAiManagedFilter =>
                          all.where((h) => h.aiManaged).toList(),
                        final f when f.startsWith(_kPackagePrefix) =>
                          all.where((h) =>
                              h.packageId ==
                              f.substring(_kPackagePrefix.length)).toList(),
                        _ => all
                            .where((h) => h.identity == _filter)
                            .toList(),
                      };
                      visible = _applySort(visible);

                      // Distinct package ids on the user's active habits
                      // — each becomes a fancy filter chip after All /
                      // Bad habits, before the identity chips.
                      final activePackageIds = <String>[];
                      for (final h in all) {
                        final pid = h.packageId;
                        if (pid != null &&
                            !activePackageIds.contains(pid)) {
                          activePackageIds.add(pid);
                        }
                      }
                      final hasAiManaged =
                          all.any((h) => h.aiManaged);

                      final completedToday = scheduled.where((h) {
                        final l = _repo.getLogForDate(h.id, today);
                        return l != null && l.isCompleted;
                      }).length;

                      final grouped = _groupByIdentity(visible);
                      final best = _bestStreak(all);

                      debugPrint(
                          '==> HabitsScreen build (habits=${all.length}, scheduled=${scheduled.length}, completed=$completedToday, filter=$_filter)');

                      // Detect a missed scheduled habit from yesterday and
                      // offer a freeze (once per session per habit per date).
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _maybePromptFreeze(all, user);
                      });

                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding:
                            const EdgeInsets.fromLTRB(20, 16, 20, 180),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Header(
                              profile: user,
                              sortMode: _sortMode,
                              onSortChanged: _setSortMode,
                            ),
                            const SizedBox(height: 16),
                            _IdentityFilter(
                              identities: identities,
                              packageIds: activePackageIds,
                              showAiManaged: hasAiManaged,
                              value: _filter,
                              onChanged: (v) =>
                                  setState(() => _filter = v),
                            ),
                            const SizedBox(height: 16),
                            _ProgressCard(
                              completed: completedToday,
                              total: scheduled.length,
                              bestStreak: best,
                            ),
                            const SizedBox(height: 22),
                            if (all.isEmpty)
                              EmptyState(
                                icon: Icons.check_circle_outline_rounded,
                                title: 'No habits yet',
                                subtitle:
                                    'Each habit is a vote for who you are becoming.',
                                ctaLabel: 'Build the first one',
                                onCta: () => _openSheet(),
                              )
                            else if (visible.isEmpty)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 24),
                                child: Center(
                                  child: Text(
                                    'No habits for this identity yet.',
                                    style: TextStyle(
                                      color: BrandColors.inkDim(context),
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              )
                            else if (_sortMode == HabitSortMode.manual) ...[
                              _ManualLockBar(
                                active: _manualReorderActive,
                                onToggle: () {
                                  HapticService().selection();
                                  setState(() => _manualReorderActive =
                                      !_manualReorderActive);
                                },
                              ),
                              const SizedBox(height: 10),
                              _ManualList(
                                habits: visible,
                                active: _manualReorderActive,
                                todayValueFor: _todayValue,
                                last7For: _last7,
                                onTap: _openDetail,
                                onIncrement: _increment,
                                onDecrement: _decrement,
                                onToggle: _toggle,
                                onReorder: (oldIdx, newIdx) async {
                                  // Map the in-list reorder back to the
                                  // global active-habit index expected by
                                  // HabitRepository.reorderHabits.
                                  final active = _repo.getActiveHabits();
                                  final moving = visible[oldIdx];
                                  final destNeighbor = newIdx >= visible.length
                                      ? null
                                      : visible[newIdx];
                                  final globalOld =
                                      active.indexWhere((h) => h.id == moving.id);
                                  final globalNew = destNeighbor == null
                                      ? active.length
                                      : active.indexWhere(
                                          (h) => h.id == destNeighbor.id);
                                  if (globalOld < 0 || globalNew < 0) return;
                                  await _repo.reorderHabits(
                                      globalOld, globalNew);
                                  HapticService().selection();
                                },
                              ),
                            ]
                            else
                              for (final entry in grouped.entries) ...[
                                _GroupHeader(label: entry.key),
                                const SizedBox(height: 8),
                                for (var i = 0; i < entry.value.length; i++) ...[
                                  HabitCard(
                                    habit: entry.value[i],
                                    todayValue: _todayValue(entry.value[i]),
                                    last7: _last7(entry.value[i]),
                                    onTap: () => _openDetail(entry.value[i]),
                                    onIncrement: () =>
                                        _increment(entry.value[i]),
                                    onDecrement: () =>
                                        _decrement(entry.value[i]),
                                    onToggle: () =>
                                        _toggle(entry.value[i]),
                                  )
                                      .animate(delay: (40 * i).ms)
                                      .fadeIn(duration: 320.ms)
                                      .slideY(
                                          begin: 0.04,
                                          end: 0,
                                          curve: Curves.easeOut),
                                  if (i < entry.value.length - 1)
                                    const SizedBox(height: 10),
                                ],
                                const SizedBox(height: 18),
                              ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          Positioned(
            right: 24,
            bottom: 110,
            child: _Fab(
              key: TutorialTargets.addHabit,
              onTap: _openSheet,
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 350.ms)
                .scaleXY(begin: 0.7, end: 1.0, curve: Curves.easeOutBack),
          ),
        ],
      ),
    );
  }

  int _todayValue(Habit h) =>
      _repo.getLogForDate(h.id, DateTime.now())?.value ?? 0;

  List<HabitLog> _last7(Habit h) {
    final today = DateTime.now();
    return _repo.getLogsForHabit(
      h.id,
      from: today.subtract(const Duration(days: 6)),
      to: today,
    );
  }

  int _bestStreak(List<Habit> all) {
    var best = 0;
    for (final h in all) {
      final s = _repo.getStreakForHabit(h.id);
      if (s > best) best = s;
    }
    return best;
  }

  Map<String, List<Habit>> _groupByIdentity(List<Habit> habits) {
    final map = <String, List<Habit>>{};
    for (final h in habits) {
      map.putIfAbsent(h.identity, () => []).add(h);
    }
    return map;
  }

  Future<void> _openSheet({Habit? editing}) async {
    HapticService().light();
    await showAddHabitSheet(context, editing: editing);
  }

  Future<void> _openDetail(Habit habit) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HabitDetailScreen(habitId: habit.id),
      ),
    );
  }

  Future<void> _toggle(Habit h) async {
    final currentValue =
        _repo.getLogForDate(h.id, DateTime.now())?.value ?? 0;
    final willComplete = currentValue == 0;
    HapticService().light();
    if (willComplete) {
      SfxService().fire(SfxType.habitComplete);
    }
    await _repo.toggleYesNoLog(habitId: h.id);
    if (willComplete) {
      _celebrateHabit(h);
    }
  }

  Future<void> _increment(Habit h) async {
    HapticService().light();
    final step = h.targetUnit?.toLowerCase().contains('minute') == true ? 5 : 1;
    await _repo.incrementLog(habitId: h.id, by: step);
    final after = _repo.getLogForDate(h.id, DateTime.now());
    if (after != null && after.isCompleted && after.value - step < after.targetValue) {
      SfxService().fire(SfxType.habitComplete);
      _celebrateHabit(h);
    }
  }

  void _celebrateHabit(Habit h) {
    if (!mounted) return;
    EffectsService().celebrateHabitComplete(context: context);
    // Streak milestone follow-up — Phoenix Rise for thresholds.
    final streak = _repo.getStreakForHabit(h.id);
    MilestoneService().checkStreak(streak).then((milestone) {
      if (milestone == null || !mounted) return;
      EffectsService().celebrateStreakMilestone(
        context: context,
        days: streak,
      );
    });
    // Badge check after the cinematic effects so the unlock celebration
    // doesn't clash with PremiumBloom / PhoenixRise.
    Future<void>.delayed(const Duration(milliseconds: 1200), () async {
      final awarded = await BadgeService().checkAndAwardBadges();
      if (awarded.isNotEmpty && mounted) {
        await showBadgeUnlockQueue(context, awarded);
      }
    });
  }

  Future<void> _decrement(Habit h) async {
    HapticService().light();
    final step = h.targetUnit?.toLowerCase().contains('minute') == true ? 5 : 1;
    await _repo.incrementLog(habitId: h.id, by: -step);
  }

  bool _freezePromptInFlight = false;

  Future<void> _maybePromptFreeze(
    List<Habit> habits,
    UserProfile? profile,
  ) async {
    if (_freezePromptInFlight || !mounted) return;
    // First-run sequencing: do not race the tutorial.
    if (!tutorialCompletedNotifier.value) return;
    if (profile == null || profile.freezesAvailable <= 0) return;

    final yesterday =
        DateTime.now().subtract(const Duration(days: 1));
    final y = DateTime(yesterday.year, yesterday.month, yesterday.day);

    // First habit that was scheduled yesterday, has an existing streak
    // worth protecting, wasn't completed, isn't already frozen, and that
    // we haven't already prompted about this session.
    final freezeSvc = FreezeService();
    Habit? target;
    for (final h in habits) {
      if (!h.isScheduledFor(y)) continue;
      if (h.isFrozenOn(y)) continue;
      final log = _repo.getLogForDate(h.id, y);
      if (log != null && log.isCompleted) continue;
      // Only suggest a freeze when there was a streak to lose (>= 2 days).
      final streak = _repo.getStreakForHabit(h.id);
      if (streak < 2) continue;
      if (freezeSvc.wasPrompted(kind: 'habit', id: h.id, date: y)) continue;
      target = h;
      break;
    }
    if (target == null) return;

    _freezePromptInFlight = true;
    freezeSvc.markPrompted(kind: 'habit', id: target.id, date: y);
    final habit = target;
    try {
      await showFreezeModal(
        context,
        itemType: 'habit',
        itemName: habit.title,
        date: y,
        profile: profile,
        onConfirm: () async {
          await freezeSvc.freezeHabit(habit, profile, y);
        },
      );
    } finally {
      if (mounted) _freezePromptInFlight = false;
    }
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
              top: -80,
              left: -80,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.purple.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              right: -100,
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

class _Header extends StatelessWidget {
  const _Header({
    this.profile,
    required this.sortMode,
    required this.onSortChanged,
  });
  final UserProfile? profile;
  final HabitSortMode sortMode;
  final ValueChanged<HabitSortMode> onSortChanged;

  @override
  Widget build(BuildContext context) {
    // Title gets its own row with the freeze badge (single small chip),
    // controls (Packages + sort) sit on a row below. This guarantees the
    // serif italic "Habits" always renders on one line regardless of
    // device width or future font swaps.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Habits',
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontSize: 32,
                    ),
              ),
            ),
            if (profile != null)
              FreezeBadge(
                count: profile!.freezesAvailable,
                profile: profile,
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          "Who you're becoming",
          style: TextStyle(
            color: BrandColors.inkDim(context),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _PackagesButton(),
            const SizedBox(width: 8),
            _SortButton(current: sortMode, onSelect: onSortChanged),
          ],
        ),
      ],
    );
  }
}

/// Small gradient button in the Habits header — opens the AI Habit
/// Packages browse screen. Visible to ALL users (free / Premium /
/// Plus) so non-Plus testers can see what they'd unlock; gating
/// happens on the start button inside the detail screen.
class _PackagesButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticService().selection();
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const HabitPackagesScreen(),
          ),
        );
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          gradient: AppColors.buttonGradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.pink.withValues(alpha: 0.30),
              blurRadius: 12,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 13),
            SizedBox(width: 5),
            Text(
              'Packages',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.current, required this.onSelect});
  final HabitSortMode current;
  final ValueChanged<HabitSortMode> onSelect;

  static const Map<HabitSortMode, String> _labels = {
    HabitSortMode.dateAdded: 'Date added',
    HabitSortMode.az: 'A–Z',
    HabitSortMode.za: 'Z–A',
    HabitSortMode.manual: 'Manual',
  };

  static const Map<HabitSortMode, IconData> _icons = {
    HabitSortMode.dateAdded: Icons.schedule_rounded,
    HabitSortMode.az: Icons.sort_by_alpha_rounded,
    HabitSortMode.za: Icons.sort_by_alpha_rounded,
    HabitSortMode.manual: Icons.drag_handle_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final activeIcon = _icons[current] ?? Icons.sort_rounded;
    return PopupMenuButton<HabitSortMode>(
      tooltip: 'Sort',
      color: BrandColors.bgCard(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: AppColors.purple.withValues(alpha: 0.30),
        ),
      ),
      onSelected: onSelect,
      itemBuilder: (_) => [
        for (final m in HabitSortMode.values)
          PopupMenuItem<HabitSortMode>(
            value: m,
            child: Row(
              children: [
                Icon(_icons[m],
                    color: m == current
                        ? AppColors.pinkLight
                        : BrandColors.inkSoft(context),
                    size: 16),
                const SizedBox(width: 10),
                Text(
                  _labels[m]!,
                  style: TextStyle(
                    color: m == current
                        ? AppColors.pinkLight
                        : BrandColors.ink(context),
                    fontWeight: m == current
                        ? FontWeight.w800
                        : FontWeight.w600,
                  ),
                ),
                if (m == current) ...[
                  const Spacer(),
                  Icon(Icons.check_rounded,
                      color: AppColors.pinkLight, size: 16),
                ],
              ],
            ),
          ),
      ],
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: BrandColors.bgCard(context).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.purple.withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(activeIcon,
                color: BrandColors.inkSoft(context), size: 14),
            const SizedBox(width: 6),
            Text(
              _labels[current]!,
              style: TextStyle(
                color: BrandColors.inkSoft(context),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Drag-to-reorder list for Manual sort mode. Each tile carries a
/// drag handle on the trailing edge; release commits the new order
/// via [onReorder] which the parent maps to
/// [HabitRepository.reorderHabits].
class _ManualList extends StatelessWidget {
  const _ManualList({
    required this.habits,
    required this.active,
    required this.todayValueFor,
    required this.last7For,
    required this.onTap,
    required this.onIncrement,
    required this.onDecrement,
    required this.onToggle,
    required this.onReorder,
  });

  final List<Habit> habits;
  /// When `false` the list renders as plain cards with a lock icon —
  /// the user must tap "Reorder" to enable drag handles. Stops
  /// accidental reorders while interacting with habits.
  final bool active;
  final int Function(Habit) todayValueFor;
  final List<HabitLog> Function(Habit) last7For;
  final void Function(Habit) onTap;
  final void Function(Habit) onIncrement;
  final void Function(Habit) onDecrement;
  final void Function(Habit) onToggle;
  final void Function(int oldIndex, int newIndex) onReorder;

  @override
  Widget build(BuildContext context) {
    if (!active) {
      // Locked — render as a plain list, no reorder.
      return Column(
        children: [
          for (final h in habits)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: HabitCard(
                      habit: h,
                      todayValue: todayValueFor(h),
                      last7: last7For(h),
                      onTap: () => onTap(h),
                      onIncrement: () => onIncrement(h),
                      onDecrement: () => onDecrement(h),
                      onToggle: () => onToggle(h),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: BrandColors.bgCard(context)
                          .withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: BrandColors.inkFaint(context)
                            .withValues(alpha: 0.45),
                      ),
                    ),
                    child: Icon(Icons.lock_outline_rounded,
                        color: BrandColors.inkDim(context), size: 16),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: habits.length,
      onReorder: onReorder,
      itemBuilder: (_, i) {
        final h = habits[i];
        return Padding(
          key: ValueKey('habit-manual-${h.id}'),
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: HabitCard(
                  habit: h,
                  todayValue: todayValueFor(h),
                  last7: last7For(h),
                  onTap: () => onTap(h),
                  onIncrement: () => onIncrement(h),
                  onDecrement: () => onDecrement(h),
                  onToggle: () => onToggle(h),
                ),
              ),
              ReorderableDragStartListener(
                index: i,
                child: Container(
                  margin: const EdgeInsets.only(left: 8),
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.purple.withValues(alpha: 0.45),
                        AppColors.pink.withValues(alpha: 0.35),
                      ],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.pink.withValues(alpha: 0.35),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.drag_indicator_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Top pill in the Habits list when sort mode is Manual — toggles
/// between "Reorder" (locked, drag disabled) and "Done" (unlocked,
/// drag handles visible). Persists the active state in screen scope
/// only; the underlying habit order itself is always synced via
/// `sortOrder`.
class _ManualLockBar extends StatelessWidget {
  const _ManualLockBar({required this.active, required this.onToggle});
  final bool active;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        gradient: active
            ? LinearGradient(
                colors: [
                  AppColors.purple.withValues(alpha: 0.32),
                  AppColors.pink.withValues(alpha: 0.20),
                ],
              )
            : null,
        color: active
            ? null
            : BrandColors.bgCard(context).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active
              ? AppColors.pinkLight.withValues(alpha: 0.55)
              : AppColors.purple.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          Icon(
            active
                ? Icons.drag_indicator_rounded
                : Icons.lock_outline_rounded,
            color: active
                ? AppColors.pinkLight
                : BrandColors.inkSoft(context),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active
                      ? 'Reordering — drag handles to move habits'
                      : 'Manual order — tap Reorder to rearrange',
                  style: TextStyle(
                    color: BrandColors.inkSoft(context),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onToggle,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: active
                    ? AppColors.buttonGradient
                    : LinearGradient(
                        colors: [
                          BrandColors.bgCard(context),
                          BrandColors.bgCard(context),
                        ],
                      ),
                borderRadius: BorderRadius.circular(20),
                border: active
                    ? null
                    : Border.all(
                        color: AppColors.pinkLight.withValues(alpha: 0.55),
                      ),
                boxShadow: active
                    ? [
                        BoxShadow(
                          color: AppColors.pink.withValues(alpha: 0.45),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                active ? 'Done' : 'Reorder',
                style: TextStyle(
                  color: active ? Colors.white : AppColors.pinkLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityFilter extends StatelessWidget {
  const _IdentityFilter({
    required this.identities,
    required this.packageIds,
    required this.showAiManaged,
    required this.value,
    required this.onChanged,
  });

  final List<String> identities;
  /// Distinct package ids currently active on the user's habits. Each
  /// one becomes a fancy gradient chip (emoji + package name) between
  /// "Bad habits" and the identity chips.
  final List<String> packageIds;
  /// True when the user has at least one AI-managed habit — surfaces
  /// the gradient "Mood8 AI Habits" chip. Hidden otherwise so the
  /// filter row doesn't have a tab the user can't fill.
  final bool showAiManaged;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // Order: All → Bad habits → Mood8 AI Habits (if any) → 1 chip per
    // running package → identity chips. The Coach-designed tab sits
    // ahead of the package tabs because it's the most "alive" group
    // the user actively curated through conversation.
    final all = <String>[
      _kAllFilter,
      _kAvoidFilter,
      if (showAiManaged) _kAiManagedFilter,
      for (final pid in packageIds) '$_kPackagePrefix$pid',
      ...identities,
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: all.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final id = all[i];
          final selected = id == value;
          final isAvoid = id == _kAvoidFilter;
          final isAi = id == _kAiManagedFilter;
          final isPackage = id.startsWith(_kPackagePrefix);
          final pkg = isPackage
              ? habitPackageById(id.substring(_kPackagePrefix.length))
              : null;
          final label = id == _kAllFilter
              ? 'All'
              : id == _kAvoidFilter
                  ? 'Bad habits'
                  : isAi
                      ? 'Mood8 AI Habits'
                      : pkg?.name ?? id;
          // The AI chip gets the brand purple→pink→blue gradient
          // (same vocabulary as the Premium hero card) so it reads
          // as the "this is the AI-shaped surface" affordance.
          final selectedGradient = isAvoid
              ? const LinearGradient(
                  colors: [Color(0xFFEC4899), Color(0xFFFB7185)],
                )
              : isAi
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFA855F7),
                        Color(0xFFEC4899),
                        Color(0xFF818CF8),
                      ],
                    )
                  : isPackage && pkg != null
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            pkg.accent,
                            AppColors.pink,
                          ],
                        )
                      : AppColors.buttonGradient;
          final selectedShadow = isAvoid
              ? AppColors.pinkLight.withValues(alpha: 0.40)
              : isAi
                  ? AppColors.purple.withValues(alpha: 0.55)
                  : isPackage && pkg != null
                      ? pkg.accent.withValues(alpha: 0.50)
                      : AppColors.pink.withValues(alpha: 0.35);
          return GestureDetector(
            onTap: () {
              HapticService().selection();
              onChanged(id);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: selected ? selectedGradient : null,
                // Idle package chips get a faint tinted background so
                // they read as premium-program affordances at rest too
                // — not just when selected.
                color: selected
                    ? null
                    : isPackage && pkg != null
                        ? pkg.accent.withValues(alpha: 0.12)
                        : isAi
                            ? AppColors.purple.withValues(alpha: 0.16)
                            : BrandColors.bgCard(context).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : (isAvoid
                          ? AppColors.pinkLight.withValues(alpha: 0.30)
                          : isAi
                              ? AppColors.purpleLight
                                  .withValues(alpha: 0.50)
                              : isPackage && pkg != null
                                  ? pkg.accent.withValues(alpha: 0.42)
                                  : AppColors.purple
                                      .withValues(alpha: 0.20)),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: selectedShadow,
                          blurRadius: 14,
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAvoid) ...[
                    Icon(
                      Icons.do_not_disturb_alt_rounded,
                      size: 12,
                      color: selected
                          ? Colors.white
                          : AppColors.pinkLight,
                    ),
                    const SizedBox(width: 5),
                  ] else if (isAi) ...[
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 13,
                      color: selected
                          ? Colors.white
                          : AppColors.purpleLight,
                    ),
                    const SizedBox(width: 5),
                  ] else if (isPackage && pkg != null) ...[
                    Text(pkg.emoji,
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? Colors.white
                          : BrandColors.inkSoft(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.completed,
    required this.total,
    required this.bestStreak,
  });

  final int completed;
  final int total;
  final int bestStreak;

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0.0 : completed / total;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.85),
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
                  total == 0
                      ? 'No habits scheduled today'
                      : '$completed of $total habits done today',
                  style: TextStyle(
                    color: BrandColors.ink(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                '${(percent * 100).round()}%',
                style: TextStyle(
                  color: AppColors.pinkLight,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
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
                  color: BrandColors.bg(context).withValues(alpha: 0.7),
                ),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  widthFactor: percent.clamp(0, 1),
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
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                bestStreak == 0
                    ? 'No streaks yet — start today.'
                    : 'Top streak: $bestStreak day${bestStreak == 1 ? '' : 's'}',
                style: TextStyle(
                  color: BrandColors.inkDim(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
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
      padding: const EdgeInsets.only(left: 2, top: 4),
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
              color: BrandColors.inkDim(context),
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
  const _Fab({super.key, required this.onTap});
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
