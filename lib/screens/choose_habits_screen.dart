import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/habit.dart';
import '../services/habit_repository.dart';
import '../services/haptic_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_container.dart';

/// "Choose your habits" — shown once the free-mode grace window closes and
/// a user is over the free habit limit. They pick which N habits stay
/// ACTIVE; the rest go read-only (never deleted). The selection is stored
/// server-side (source of truth) via SubscriptionService.setActiveHabits.
///
/// Reachable during grace too, so a user can decide early. Subscribing
/// unlocks everything and makes this moot.
class ChooseHabitsScreen extends StatefulWidget {
  const ChooseHabitsScreen({super.key});

  @override
  State<ChooseHabitsScreen> createState() => _ChooseHabitsScreenState();
}

class _ChooseHabitsScreenState extends State<ChooseHabitsScreen> {
  final HabitRepository _repo = HabitRepository();
  late List<Habit> _habits;
  late int _limit;
  final Set<String> _selected = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _limit = SubscriptionService().habitLimit ?? 3;
    // Most-recently-active first, so the default keeps their live habits.
    _habits = _repo.getActiveHabits()
      ..sort((a, b) {
        final ax = a.updatedAt ?? a.createdAt;
        final bx = b.updatedAt ?? b.createdAt;
        return bx.compareTo(ax);
      });
    final serverChoice = SubscriptionService().activeHabitIds;
    if (serverChoice.isNotEmpty) {
      _selected.addAll(
          serverChoice.where((id) => _habits.any((h) => h.id == id)));
    }
    // Default: fill up to the limit with the most recent.
    for (final h in _habits) {
      if (_selected.length >= _limit) break;
      _selected.add(h.id);
    }
  }

  void _toggle(String id) {
    HapticService().selection();
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else if (_selected.length < _limit) {
        _selected.add(id);
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final ok = await SubscriptionService().setActiveHabits(_selected.toList());
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      HapticService().reward();
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't save — check your connection.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _limit - _selected.length;
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
        title: Text('Choose your habits',
            style: Theme.of(context).textTheme.headlineSmall),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 560,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  'The free plan keeps $_limit habits active. Pick the ones '
                  'to keep — the rest stay saved and just pause until you '
                  'choose them or go Premium. Nothing is ever deleted.',
                  style: TextStyle(
                    color: BrandColors.inkSoft(context),
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                  itemCount: _habits.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final h = _habits[i];
                    final on = _selected.contains(h.id);
                    final canAdd = on || _selected.length < _limit;
                    return _HabitChoiceTile(
                      title: h.title,
                      selected: on,
                      enabled: canAdd,
                      onTap: () => _toggle(h.id),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  children: [
                    Text(
                      remaining > 0
                          ? '$remaining more can stay active'
                          : 'Your $_limit active habits are chosen',
                      style: TextStyle(
                        color: BrandColors.inkDim(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: _saving ? null : _save,
                      child: Container(
                        height: 52,
                        width: double.infinity,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          gradient: AppColors.buttonGradient,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                'Save',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                      ),
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

class _HabitChoiceTile extends StatelessWidget {
  const _HabitChoiceTile({
    required this.title,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });
  final String title;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.purple.withValues(alpha: 0.22)
                : BrandColors.bgCard(context).withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppColors.pinkLight.withValues(alpha: 0.6)
                  : AppColors.purple.withValues(alpha: 0.2),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined,
                color: selected
                    ? AppColors.pinkLight
                    : BrandColors.inkDim(context),
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.bricolageGrotesque(
                    color: BrandColors.ink(context),
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
