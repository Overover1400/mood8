import 'package:flutter/material.dart';

import '../../models/habit.dart';
import '../../services/challenge_service.dart';
import '../../services/habit_repository.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';

/// One habit a fellow member chose to show: icon, title, today's status.
class SharedHabit {
  const SharedHabit({
    required this.icon,
    required this.title,
    required this.status,
  });

  final String icon;
  final String title;

  /// done · pending · off (not scheduled today) · null (quit/reduce).
  final String? status;

  factory SharedHabit.fromJson(Map<String, dynamic> j) => SharedHabit(
        icon: (j['icon'] as String?) ?? '',
        title: (j['title'] as String?) ?? '',
        status: j['status'] as String?,
      );
}

class SharedHabitsMember {
  const SharedHabitsMember({
    required this.userId,
    required this.name,
    required this.habits,
  });

  final int userId;
  final String name;
  final List<SharedHabit> habits;

  factory SharedHabitsMember.fromJson(Map<String, dynamic> j) =>
      SharedHabitsMember(
        userId: (j['user_id'] as num).toInt(),
        name: (j['name'] as String?) ?? 'Member',
        habits: ((j['habits'] as List?) ?? const [])
            .map((h) => SharedHabit.fromJson(h as Map<String, dynamic>))
            .toList(),
      );
}

/// "Members' habits" block on the challenge screen.
///
/// Habit sharing exists only here: a habit stays private unless its
/// owner switches on "Show in my challenges", and then only fellow
/// members of their challenges see its name and today's status.
class SharedHabitsSection extends StatefulWidget {
  const SharedHabitsSection({super.key, required this.challengeId});

  final int challengeId;

  @override
  State<SharedHabitsSection> createState() => _SharedHabitsSectionState();
}

class _SharedHabitsSectionState extends State<SharedHabitsSection> {
  List<SharedHabitsMember>? _members;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final m = await ChallengeService().sharedHabits(widget.challengeId);
      if (!mounted) return;
      setState(() {
        _members = m;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = BrandColors.ink(context);
    final dim = BrandColors.inkDim(context);
    final members = _members;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'MEMBERS\' HABITS',
                  style: TextStyle(
                    color: dim,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              TextButton(
                onPressed: () async {
                  HapticService().light();
                  await showShareHabitsSheet(context);
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Choose mine'),
              ),
            ],
          ),
          if (members == null && !_failed)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else if (_failed)
            Text('Couldn\'t load members\' habits.',
                style: TextStyle(color: dim, fontSize: 13))
          else if (members!.isEmpty)
            Text(
              'No one is sharing habits here yet. Your habits stay '
              'private unless you choose to show them.',
              style: TextStyle(color: dim, fontSize: 13, height: 1.4),
            )
          else
            for (final m in members) ...[
              const SizedBox(height: 8),
              Text(m.name,
                  style: TextStyle(
                      color: ink, fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              for (final h in m.habits) _HabitLine(habit: h),
            ],
        ],
      ),
    );
  }
}

class _HabitLine extends StatelessWidget {
  const _HabitLine({required this.habit});

  final SharedHabit habit;

  @override
  Widget build(BuildContext context) {
    final (IconData?, Color) mark = switch (habit.status) {
      'done' => (Icons.check_circle_rounded, Colors.greenAccent),
      'pending' => (Icons.radio_button_unchecked, BrandColors.inkDim(context)),
      'off' => (Icons.remove_rounded, BrandColors.inkDim(context)),
      _ => (null, BrandColors.inkDim(context)),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(habit.icon, style: const TextStyle(fontSize: 16)),
          ),
          Expanded(
            child: Text(
              habit.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: BrandColors.inkSoft(context), fontSize: 13.5),
            ),
          ),
          if (mark.$1 != null) Icon(mark.$1, size: 18, color: mark.$2),
        ],
      ),
    );
  }
}

/// Bottom sheet: one switch per habit — "Show in my challenges".
Future<void> showShareHabitsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: BrandColors.bgCard(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => const _ShareHabitsSheet(),
  );
}

class _ShareHabitsSheet extends StatefulWidget {
  const _ShareHabitsSheet();

  @override
  State<_ShareHabitsSheet> createState() => _ShareHabitsSheetState();
}

class _ShareHabitsSheetState extends State<_ShareHabitsSheet> {
  late List<Habit> _habits = HabitRepository().getActiveHabits();

  Future<void> _toggle(Habit h, bool value) async {
    HapticService().selection();
    h.shareInChallenges = value;
    setState(() {});
    await HabitRepository().updateHabit(h);
    if (mounted) {
      setState(() => _habits = HabitRepository().getActiveHabits());
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = BrandColors.ink(context);
    final dim = BrandColors.inkDim(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Show in my challenges',
                  style: TextStyle(
                      color: ink, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              Text(
                'Everything is private by default. A habit you switch on '
                'is shown only to members of your challenges: its name and '
                'whether you did it today. Nothing else.',
                style: TextStyle(color: dim, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 10),
              if (_habits.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text('You have no active habits yet.',
                      style: TextStyle(color: dim)),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final h in _habits)
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text('${h.icon}  ${h.title}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: ink, fontSize: 14.5)),
                          value: h.shareInChallenges,
                          onChanged: (v) => _toggle(h, v),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
