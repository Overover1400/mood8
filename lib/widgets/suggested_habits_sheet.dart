import 'package:flutter/material.dart';

import '../models/frequency.dart';
import '../models/habit_type.dart';
import '../models/personalization.dart';
import '../models/routine_category.dart';
import '../screens/paywall_screen.dart';
import '../services/habit_repository.dart';
import '../services/haptic_service.dart';
import '../services/notification_service.dart';
import '../services/personalization_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';

/// The arguments for creating a habit from a suggestion. Pure, so the
/// mapping is testable without Hive.
class SuggestionHabitArgs {
  const SuggestionHabitArgs({
    required this.title,
    required this.icon,
    required this.habitType,
    required this.identity,
    required this.category,
    required this.frequency,
    required this.targetValue,
    required this.targetUnit,
    required this.reminderMinutes,
  });

  final String title;
  final String icon;
  final HabitType habitType;
  final String identity;
  final RoutineCategory category;
  final Frequency frequency;
  final int? targetValue;
  final String? targetUnit;
  final List<int> reminderMinutes;
}

SuggestionHabitArgs argsForSuggestion(PersonalizedSuggestion s) {
  final isYesNo = s.type == HabitType.yesNo;
  final unit = (s.unit ?? '').trim();
  final minute = s.reminderMinute;
  return SuggestionHabitArgs(
    title: s.title.trim(),
    icon: s.icon,
    habitType: s.type,
    identity: s.identity,
    category: s.category,
    frequency: s.frequency,
    targetValue: isYesNo ? 1 : (s.target ?? 1),
    targetUnit: isYesNo || unit.isEmpty ? null : unit,
    reminderMinutes: minute == null ? const [] : [minute],
  );
}

/// Opens the sheet. Resolves true when at least one habit was added.
Future<bool> showSuggestedHabitsSheet(
  BuildContext context,
  PersonalizationResult initial,
) async {
  final added = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: BrandColors.bgCard(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => SuggestedHabitsSheet(initial: initial),
  );
  return added == true;
}

class SuggestedHabitsSheet extends StatefulWidget {
  const SuggestedHabitsSheet({super.key, required this.initial});
  final PersonalizationResult initial;

  @override
  State<SuggestedHabitsSheet> createState() => _SuggestedHabitsSheetState();
}

class _SuggestedHabitsSheetState extends State<SuggestedHabitsSheet> {
  late PersonalizationResult _result = widget.initial;
  final HabitRepository _repo = HabitRepository();
  final Set<String> _added = {};
  final Set<String> _picked = {};
  bool _busy = false;
  bool _anyAdded = false;

  List<PersonalizedSuggestion> get _visible => _result
      .without(_repo.getActiveHabits().map((h) => h.title))
      .where((s) => !_added.contains(s.key))
      .toList();

  Future<void> _answer(String key, Object value) async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticService().selection();
    final next = await PersonalizationService().answer(key, value);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _picked.clear();
      if (next != null) {
        _result = next;
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't save that. Try again.")),
        );
      }
    });
  }

  Future<void> _add(PersonalizedSuggestion s) async {
    if (_busy) return;
    // The same single, server-driven plan gate the add-habit sheet uses.
    final subs = SubscriptionService();
    if (subs.habitLimitReached(_repo.getActiveHabits().length)) {
      await _showLimitDialog();
      return;
    }
    setState(() => _busy = true);
    try {
      final a = argsForSuggestion(s);
      final h = await _repo.addHabit(
        title: a.title,
        icon: a.icon,
        habitType: a.habitType,
        identity: a.identity,
        category: a.category,
        frequency: a.frequency,
        targetValue: a.targetValue,
        targetUnit: a.targetUnit,
      );
      if (a.reminderMinutes.isNotEmpty) {
        final notif = NotificationService();
        await notif.ensureInitialized();
        if (notif.isSupported && !notif.isGranted) {
          await notif.requestPermission();
        }
        h.remindersEnabled = true;
        h.reminderMinutes = a.reminderMinutes;
        await _repo.updateHabit(h);
      }
      HapticService().light();
      if (!mounted) return;
      setState(() {
        _added.add(s.key);
        _anyAdded = true;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add it: $e')),
      );
    }
  }

  Future<void> _showLimitDialog() {
    final cap = SubscriptionService().maxHabits;
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrandColors.bgCard(context),
        title: Text('Habit limit reached',
            style: TextStyle(color: BrandColors.ink(context))),
        content: Text(
          'Free plan supports up to $cap habits.\n\n'
          'Premium gives you unlimited habits, routines, and AI Coach.',
          style: TextStyle(color: BrandColors.inkSoft(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Maybe later'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PaywallScreen(
                    contextNote: 'Unlimited habits is a Premium feature',
                  ),
                ),
              );
            },
            child: const Text('See Premium'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ink = BrandColors.ink(context);
    final dim = BrandColors.inkDim(context);
    final items = _visible;
    final q = _result.followUp;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_anyAdded);
      },
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: BrandColors.inkFaint(context),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Suggested for you',
                  style: TextStyle(
                      color: ink, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(_result.basisLine,
                  style: TextStyle(color: dim, fontSize: 13.5)),
              if (_result.basis.dropOffs.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'People like you often drop: '
                  '${_result.basis.dropOffs.join(', ')}.',
                  style: TextStyle(color: dim, fontSize: 12.5),
                ),
              ],
              if (_result.slotsLeft != null) ...[
                const SizedBox(height: 4),
                Text(
                  _result.slotsLeft == 0
                      ? 'Your free plan has no habit slots left.'
                      : '${_result.slotsLeft} free habit '
                          '${_result.slotsLeft == 1 ? 'slot' : 'slots'} left.',
                  style: TextStyle(color: dim, fontSize: 12.5),
                ),
              ],
              if (q != null) ...[
                const SizedBox(height: 16),
                _FollowUp(
                  question: q,
                  picked: _picked,
                  busy: _busy,
                  onToggle: (v) => setState(() {
                    if (!_picked.add(v)) _picked.remove(v);
                  }),
                  onAnswer: (v) => _answer(q.key, v),
                ),
              ],
              const SizedBox(height: 12),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    q == null
                        ? "You already have everything we'd suggest right now."
                        : 'Answer the question above to get suggestions.',
                    style: TextStyle(color: dim),
                  ),
                )
              else
                for (final s in items)
                  _Tile(
                    suggestion: s,
                    busy: _busy,
                    onAdd: () => _add(s),
                  ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(_anyAdded),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FollowUp extends StatelessWidget {
  const _FollowUp({
    required this.question,
    required this.picked,
    required this.busy,
    required this.onToggle,
    required this.onAnswer,
  });

  final FollowUpQuestion question;
  final Set<String> picked;
  final bool busy;
  final ValueChanged<String> onToggle;
  final ValueChanged<Object> onAnswer;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BrandColors.bg(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(question.question,
              style: TextStyle(
                  color: BrandColors.ink(context),
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in question.options)
                question.multi
                    ? FilterChip(
                        label: Text(o.label),
                        selected: picked.contains(o.value),
                        onSelected: busy ? null : (_) => onToggle(o.value),
                      )
                    : ActionChip(
                        label: Text(o.label),
                        onPressed: busy ? null : () => onAnswer(o.value),
                      ),
            ],
          ),
          if (question.multi) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: busy || picked.isEmpty
                    ? null
                    : () => onAnswer(picked.toList()),
                child: const Text('Save'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.suggestion,
    required this.busy,
    required this.onAdd,
  });

  final PersonalizedSuggestion suggestion;
  final bool busy;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final s = suggestion;
    final meta = [
      if (s.amountLabel.isNotEmpty) s.amountLabel,
      if (s.time != null) 'at ${s.time}',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: BrandColors.bg(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.icon, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.title,
                    style: TextStyle(
                        color: BrandColors.ink(context),
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                if (meta.isNotEmpty)
                  Text(meta,
                      style: TextStyle(
                          color: BrandColors.inkSoft(context), fontSize: 13)),
                if (s.why.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(s.why,
                      style: TextStyle(
                          color: BrandColors.inkDim(context), fontSize: 12.5)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: busy ? null : onAdd,
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

/// Compact entry point for the Habits screen. Fetches once, quietly: if
/// there is nothing to show (signed out, offline, older server, no
/// suggestions) it renders nothing.
class SuggestedHabitsCard extends StatefulWidget {
  const SuggestedHabitsCard({super.key});

  @override
  State<SuggestedHabitsCard> createState() => _SuggestedHabitsCardState();
}

class _SuggestedHabitsCardState extends State<SuggestedHabitsCard> {
  PersonalizationResult? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await PersonalizationService().fetch();
    if (mounted && r != null) setState(() => _result = r);
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    if (r == null || r.isEmpty) return const SizedBox.shrink();
    final n = r
        .without(HabitRepository().getActiveHabits().map((h) => h.title))
        .length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: BrandColors.bgCard(context),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            HapticService().selection();
            final changed = await showSuggestedHabitsSheet(context, r);
            if (changed) await _load();
            if (mounted) setState(() {});
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Text('✨', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Suggested for you',
                          style: TextStyle(
                              color: BrandColors.ink(context),
                              fontWeight: FontWeight.w700)),
                      Text(
                        n > 0
                            ? '$n ${n == 1 ? 'habit' : 'habits'} that fit you'
                            : 'Answer one question to personalise',
                        style: TextStyle(
                            color: BrandColors.inkDim(context), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: BrandColors.inkFaint(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
