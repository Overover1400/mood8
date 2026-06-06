import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/frequency.dart';
import '../models/habit.dart';
import '../models/habit_polarity.dart';
import '../models/habit_type.dart';
import '../models/routine_category.dart';
import '../screens/paywall_screen.dart';
import '../services/habit_repository.dart';
import '../services/notification_service.dart';
import '../services/subscription_service.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import 'category_chip.dart';

const List<String> _kEmojiPresets = [
  '💧', '🧘', '📚', '💪', '☕', '🚶',
  '🎨', '✍️', '🎵', '🧠', '💭', '❤️',
];

/// Emoji presets shown when the user is building an "avoid" habit —
/// hints at the kinds of things people try to cut down on rather than
/// the constructive defaults above.
const List<String> _kAvoidEmojiPresets = [
  '🚭', '🍷', '🍰', '📱', '🎰', '💢',
  '☕', '🍔', '🛋️', '⏰', '🛒', '🎮',
];

const List<int> _kReduceDurations = [7, 30, 90];

Future<void> showAddHabitSheet(
  BuildContext context, {
  Habit? editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => AddHabitSheet(editing: editing),
  );
}

class AddHabitSheet extends StatefulWidget {
  const AddHabitSheet({super.key, this.editing});
  final Habit? editing;

  @override
  State<AddHabitSheet> createState() => _AddHabitSheetState();
}

class _AddHabitSheetState extends State<AddHabitSheet> {
  final HabitRepository _repo = HabitRepository();
  final UserRepository _userRepo = UserRepository();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _targetCtrl = TextEditingController(text: '8');
  final TextEditingController _unitCtrl = TextEditingController();
  final FocusNode _titleFocus = FocusNode();

  late String _emoji;
  late HabitType _type;
  late String _identity;
  late RoutineCategory _category;
  late Frequency _frequency;
  late Set<int> _customDays;
  late HabitPolarity _polarity;
  late AvoidMode _avoidMode;
  late int _avoidDurationDays;
  late bool _remindersEnabled;
  late List<int> _reminderMinutes; // minute-of-day, sorted.
  String? _titleError;
  bool _saving = false;

  bool get _isEditing => widget.editing != null;
  bool get _isAvoid => _polarity == HabitPolarity.avoid;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _polarity = e?.polarity ?? HabitPolarity.build;
    _avoidMode = e?.avoidMode ?? AvoidMode.quit;
    _avoidDurationDays = e?.avoidDurationDays ?? 30;
    _emoji = e?.icon ?? (_isAvoid ? '🚭' : '💧');
    _type = e?.habitType ?? HabitType.yesNo;
    _identity = e?.identity ?? 'General';
    _category = e?.category ?? RoutineCategory.health;
    _frequency = e?.frequency ?? Frequency.daily;
    _customDays = {...?e?.frequencyDays};
    _titleCtrl.text = e?.title ?? '';
    _targetCtrl.text = (e?.targetValue ?? _defaultTarget()).toString();
    _unitCtrl.text = e?.targetUnit ?? _type.defaultUnit;
    _remindersEnabled = e?.remindersEnabled ?? false;
    _reminderMinutes = [...?e?.reminderMinutes]..sort();
    if (!_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _titleFocus.requestFocus();
      });
    }
  }

  void _onPolarityChange(HabitPolarity p) {
    if (_polarity == p) return;
    setState(() {
      _polarity = p;
      if (p == HabitPolarity.avoid) {
        // Avoid habits ride on top of existing habit types: quit = yesNo
        // (stayed clean), reduce = counter (slip count). Resync the
        // type + sensible defaults when the user flips into Avoid.
        _type = _avoidMode == AvoidMode.quit
            ? HabitType.yesNo
            : HabitType.counter;
        _targetCtrl.text = _defaultTarget().toString();
        _unitCtrl.text = _avoidMode == AvoidMode.reduce
            ? 'times'
            : _type.defaultUnit;
        if (_emoji == '💧') _emoji = '🚭';
        _category = RoutineCategory.mindful;
      } else {
        if (_emoji == '🚭') _emoji = '💧';
        _type = HabitType.yesNo;
        _targetCtrl.text = _defaultTarget().toString();
        _unitCtrl.text = _type.defaultUnit;
      }
    });
  }

  void _onAvoidModeChange(AvoidMode m) {
    if (_avoidMode == m) return;
    setState(() {
      _avoidMode = m;
      _type = m == AvoidMode.quit ? HabitType.yesNo : HabitType.counter;
      _targetCtrl.text = _defaultTarget().toString();
      _unitCtrl.text = m == AvoidMode.reduce ? 'times' : _type.defaultUnit;
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _targetCtrl.dispose();
    _unitCtrl.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  int _defaultTarget() {
    if (_isAvoid && _avoidMode == AvoidMode.reduce) {
      // Reduce mode tracks a daily count with no fixed ceiling — the
      // "win" is trending down, not hitting a number. Store 0 so old
      // analytics paths that read targetValue treat it as goalless.
      return 0;
    }
    switch (_type) {
      case HabitType.yesNo:
        return 1;
      case HabitType.counter:
        return 8;
      case HabitType.duration:
        return 30;
    }
  }

  void _onTypeChange(HabitType t) {
    setState(() {
      _type = t;
      _targetCtrl.text = _defaultTarget().toString();
      _unitCtrl.text = t.defaultUnit;
    });
  }

  Future<void> _onSave() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Give this habit a name.');
      return;
    }
    if (_frequency == Frequency.custom && _customDays.isEmpty) {
      setState(() => _titleError = 'Pick at least one day for custom.');
      return;
    }
    if (!_isEditing) {
      final subs = SubscriptionService();
      if (!subs.isPremium) {
        final active = _repo.getActiveHabits().length;
        if (subs.habitLimitReached(active)) {
          final tookAction = await _showHabitLimitDialog();
          if (!mounted) return;
          if (tookAction != true) return;
        }
      }
    }
    setState(() {
      _titleError = null;
      _saving = true;
    });

    try {
      final target = _type == HabitType.yesNo
          ? 1
          : (int.tryParse(_targetCtrl.text.trim()) ?? _defaultTarget());
      final effectivePolarity = _polarity;
      final effectiveAvoidMode = _isAvoid ? _avoidMode : null;
      final effectiveAvoidDuration = _isAvoid && _avoidMode == AvoidMode.reduce
          ? _avoidDurationDays
          : null;
      // Normalize reminder selection — drop duplicates, drop out-of-range
      // values, sort. We don't allow reminders on a habit that has them
      // enabled but no times picked (the UI prevents this anyway).
      final cleanedReminders = _reminderMinutes
          .where((m) => m >= 0 && m < 24 * 60)
          .toSet()
          .toList()
        ..sort();
      final effectiveRemindersEnabled =
          _remindersEnabled && cleanedReminders.isNotEmpty;

      if (_isEditing) {
        final h = widget.editing!;
        h.title = title;
        h.icon = _emoji;
        h.habitType = _type;
        h.identity = _identity;
        h.category = _category;
        h.frequency = _frequency;
        h.frequencyDays =
            _frequency == Frequency.custom ? _customDays.toList() : null;
        h.targetValue = target;
        h.targetUnit = _type == HabitType.yesNo ? null : _unitCtrl.text.trim();
        h.color = _category.color.toARGB32();
        h.polarity = effectivePolarity;
        h.avoidMode = effectiveAvoidMode;
        h.avoidDurationDays = effectiveAvoidDuration;
        h.remindersEnabled = effectiveRemindersEnabled;
        h.reminderMinutes = cleanedReminders;
        await _repo.updateHabit(h);
      } else {
        final h = await _repo.addHabit(
          title: title,
          icon: _emoji,
          habitType: _type,
          identity: _identity,
          category: _category,
          frequency: _frequency,
          targetValue: target,
          targetUnit: _type == HabitType.yesNo ? null : _unitCtrl.text.trim(),
          frequencyDays:
              _frequency == Frequency.custom ? _customDays.toList() : null,
          polarity: effectivePolarity,
          avoidMode: effectiveAvoidMode,
          avoidDurationDays: effectiveAvoidDuration,
        );
        // addHabit doesn't take reminder args today (signature is wide
        // already); patch the fresh row, then update so the
        // HabitReminderService.rescheduleFor call inside updateHabit
        // picks them up.
        if (effectiveRemindersEnabled) {
          h.remindersEnabled = true;
          h.reminderMinutes = cleanedReminders;
          await _repo.updateHabit(h);
        }
      }
      HapticFeedback.lightImpact();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save: $e'),
          backgroundColor: BrandColors.bgCard(context),
        ),
      );
    }
  }

  Future<bool?> _showHabitLimitDialog() {
    final cap = SubscriptionService().maxHabits;
    return showDialog<bool>(
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
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Maybe later'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(false);
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

  // ─── Reminder handlers ─────────────────────────────────────────────────

  Future<void> _onRemindersToggle(bool enabled) async {
    if (enabled) {
      // Asking for permission at the moment the user opts in is the
      // most honest place — they just expressed intent to receive
      // notifications. If they deny, we still let the toggle flip on
      // so the choice survives across permission changes, but we show
      // a hint that nothing will fire until they grant.
      final notif = NotificationService();
      if (notif.isSupported && !notif.isGranted) {
        await notif.requestPermission();
      }
    }
    setState(() {
      _remindersEnabled = enabled;
      if (enabled && _reminderMinutes.isEmpty) {
        // Seed with a sensible default so the user doesn't see an
        // empty list and wonder what to do. 09:00 is a fine first
        // nudge for almost any habit.
        _reminderMinutes = [540];
      }
    });
  }

  Future<void> _onAddReminder() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null) return;
    final m = picked.hour * 60 + picked.minute;
    if (_reminderMinutes.contains(m)) return;
    setState(() {
      _reminderMinutes = [..._reminderMinutes, m]..sort();
      if (!_remindersEnabled) _remindersEnabled = true;
    });
  }

  Future<void> _onEditReminder(int index) async {
    final current = _reminderMinutes[index];
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
    );
    if (picked == null) return;
    final m = picked.hour * 60 + picked.minute;
    setState(() {
      _reminderMinutes = <int>{
        for (var i = 0; i < _reminderMinutes.length; i++)
          if (i == index) m else _reminderMinutes[i],
      }.toList()
        ..sort();
    });
  }

  void _onRemoveReminder(int index) {
    setState(() {
      _reminderMinutes = [..._reminderMinutes]..removeAt(index);
      if (_reminderMinutes.isEmpty) _remindersEnabled = false;
    });
  }

  /// Quick-set buttons for counter habits — "every 2h between 9am and
  /// 9pm" is the canonical "drink water 8x/day" pattern. The user can
  /// edit / remove individual times after applying.
  void _onApplyReminderPreset(_ReminderPreset preset) {
    final times = preset.minutes();
    setState(() {
      _reminderMinutes = times;
      _remindersEnabled = times.isNotEmpty;
    });
  }

  Future<void> _onDelete() async {
    final h = widget.editing;
    if (h == null) return;
    try {
      await _repo.deleteHabit(h.id);
      HapticFeedback.mediumImpact();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete: $e'),
          backgroundColor: BrandColors.bgCard(context),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _userRepo.getCurrentUser();
    final identityOptions = <String>{'General', ...?user?.identities};
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [BrandColors.bg(context), BrandColors.bgDeep(context)],
          ),
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(
            color: AppColors.purple.withValues(alpha: 0.22),
          ),
        ),
        child: SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.92,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    _isEditing ? 'Edit habit' : 'New habit',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 18),
                  _Label('Goal'),
                  const SizedBox(height: 8),
                  _PolarityTabs(
                    value: _polarity,
                    onChanged: _onPolarityChange,
                  ),
                  if (_isAvoid) ...[
                    const SizedBox(height: 14),
                    _AvoidModeTabs(
                      value: _avoidMode,
                      onChanged: _onAvoidModeChange,
                    ),
                    const SizedBox(height: 6),
                    _AvoidModeHint(mode: _avoidMode),
                    if (_avoidMode == AvoidMode.reduce) ...[
                      const SizedBox(height: 14),
                      _Label('Track for'),
                      const SizedBox(height: 8),
                      _DurationPicker(
                        value: _avoidDurationDays,
                        onChanged: (d) =>
                            setState(() => _avoidDurationDays = d),
                      ),
                    ],
                  ],
                  const SizedBox(height: 18),
                  _Label('Icon'),
                  const SizedBox(height: 8),
                  _EmojiPicker(
                    value: _emoji,
                    presets:
                        _isAvoid ? _kAvoidEmojiPresets : _kEmojiPresets,
                    onChanged: (e) => setState(() => _emoji = e),
                  ),
                  const SizedBox(height: 18),
                  _Label(
                    _isAvoid
                        ? 'What do you want to avoid?'
                        : "What's the habit?",
                  ),
                  const SizedBox(height: 8),
                  _UnderlineField(
                    controller: _titleCtrl,
                    focusNode: _titleFocus,
                    hint: _isAvoid
                        ? (_avoidMode == AvoidMode.quit
                            ? 'Smoking'
                            : 'Scrolling')
                        : 'Drink water',
                    error: _titleError,
                  ),
                  if (!_isAvoid) ...[
                    const SizedBox(height: 18),
                    _Label('Type'),
                    const SizedBox(height: 8),
                    _TypeTabs(value: _type, onChanged: _onTypeChange),
                  ],
                  if (!_isAvoid && _type != HabitType.yesNo) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Label('Target'),
                              const SizedBox(height: 8),
                              _NumberField(controller: _targetCtrl),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Label('Unit'),
                              const SizedBox(height: 8),
                              _UnderlineField(
                                controller: _unitCtrl,
                                hint: _type.defaultUnit,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  _Label('Identity'),
                  const SizedBox(height: 8),
                  _IdentityPicker(
                    options: identityOptions.toList(),
                    value: _identity,
                    onChanged: (v) => setState(() => _identity = v),
                  ),
                  const SizedBox(height: 18),
                  _Label('Category'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in RoutineCategory.values)
                        CategoryChip(
                          category: c,
                          selected: c == _category,
                          onTap: () => setState(() => _category = c),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _Label('Frequency'),
                  const SizedBox(height: 8),
                  _FrequencyPicker(
                    value: _frequency,
                    onChanged: (f) => setState(() => _frequency = f),
                  ),
                  if (_frequency == Frequency.custom) ...[
                    const SizedBox(height: 12),
                    _CustomDaysRow(
                      selected: _customDays,
                      onChanged: (s) => setState(() => _customDays = s),
                    ),
                  ],
                  const SizedBox(height: 18),
                  _Label('Reminders'),
                  const SizedBox(height: 8),
                  _ReminderSection(
                    enabled: _remindersEnabled,
                    times: _reminderMinutes,
                    onToggle: _onRemindersToggle,
                    onAdd: _onAddReminder,
                    onEdit: _onEditReminder,
                    onRemove: _onRemoveReminder,
                    onPreset: _onApplyReminderPreset,
                    isCounter: !_isAvoid && _type == HabitType.counter,
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      if (_isEditing)
                        TextButton(
                          onPressed: _saving ? null : _onDelete,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFFF6B81),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                          ),
                          child: const Text(
                            'Delete',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      const Spacer(),
                      OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: BrandColors.inkSoft(context),
                          side: BorderSide(
                            color: AppColors.purple.withValues(alpha: 0.35),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 10),
                      _SaveButton(
                        label: _saving
                            ? 'Saving…'
                            : (_isEditing ? 'Update' : 'Save'),
                        onTap: _saving ? null : _onSave,
                      ),
                    ],
                  )
                      .animate()
                      .fadeIn(delay: 60.ms, duration: 350.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          color: BrandColors.inkDim(context),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
        ),
      );
}

class _EmojiPicker extends StatelessWidget {
  const _EmojiPicker({
    required this.value,
    required this.onChanged,
    this.presets = _kEmojiPresets,
  });
  final String value;
  final ValueChanged<String> onChanged;
  final List<String> presets;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in presets)
          GestureDetector(
            onTap: () => onChanged(e),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: value == e
                    ? AppColors.buttonGradient
                    : null,
                color:
                    value == e ? null : BrandColors.bgCard(context).withValues(alpha: 0.7),
                border: Border.all(
                  color: value == e
                      ? Colors.transparent
                      : AppColors.purple.withValues(alpha: 0.20),
                ),
                boxShadow: value == e
                    ? [
                        BoxShadow(
                          color: AppColors.pink.withValues(alpha: 0.35),
                          blurRadius: 14,
                        ),
                      ]
                    : null,
              ),
              child: Text(e, style: const TextStyle(fontSize: 20)),
            ),
          ),
      ],
    );
  }
}

class _UnderlineField extends StatelessWidget {
  const _UnderlineField({
    required this.controller,
    required this.hint,
    this.focusNode,
    this.error,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          cursorColor: AppColors.purpleLight,
          style: TextStyle(
            color: BrandColors.ink(context),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: BrandColors.inkDim(context).withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppColors.purple.withValues(alpha: 0.30),
              ),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.pinkLight, width: 1.5),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error!,
            style: const TextStyle(
              color: Color(0xFFFF6B81),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
      ],
      cursorColor: AppColors.purpleLight,
      style: TextStyle(
        color: BrandColors.ink(context),
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        enabledBorder: UnderlineInputBorder(
          borderSide: BorderSide(
            color: AppColors.purple.withValues(alpha: 0.30),
          ),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.pinkLight, width: 1.5),
        ),
      ),
    );
  }
}

class _TypeTabs extends StatelessWidget {
  const _TypeTabs({required this.value, required this.onChanged});
  final HabitType value;
  final ValueChanged<HabitType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          for (final t in HabitType.values)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(t);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient:
                        t == value ? AppColors.buttonGradient : null,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    t.label,
                    style: TextStyle(
                      color: t == value ? Colors.white : BrandColors.inkDim(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _IdentityPicker extends StatelessWidget {
  const _IdentityPicker({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(o);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: o == value ? AppColors.buttonGradient : null,
                color: o == value
                    ? null
                    : BrandColors.bgCard(context).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: o == value
                      ? Colors.transparent
                      : AppColors.purple.withValues(alpha: 0.20),
                ),
              ),
              child: Text(
                o,
                style: TextStyle(
                  color: o == value ? Colors.white : BrandColors.inkSoft(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _FrequencyPicker extends StatelessWidget {
  const _FrequencyPicker({required this.value, required this.onChanged});
  final Frequency value;
  final ValueChanged<Frequency> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final f in Frequency.values)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(f);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: f == value ? AppColors.buttonGradient : null,
                color: f == value
                    ? null
                    : BrandColors.bgCard(context).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: f == value
                      ? Colors.transparent
                      : AppColors.purple.withValues(alpha: 0.20),
                ),
              ),
              child: Text(
                f.label,
                style: TextStyle(
                  color: f == value ? Colors.white : BrandColors.inkSoft(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CustomDaysRow extends StatelessWidget {
  const _CustomDaysRow({required this.selected, required this.onChanged});
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                final next = {...selected};
                if (!next.add(i)) next.remove(i);
                onChanged(next);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: selected.contains(i)
                      ? AppColors.buttonGradient
                      : null,
                  color: selected.contains(i)
                      ? null
                      : BrandColors.bgCard(context).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected.contains(i)
                        ? Colors.transparent
                        : AppColors.purple.withValues(alpha: 0.20),
                  ),
                ),
                child: Text(
                  kWeekdayShort[i],
                  style: TextStyle(
                    color: selected.contains(i)
                        ? Colors.white
                        : BrandColors.inkSoft(context),
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          if (i < 6) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

/// Build vs Avoid segmented control. Visually mirrors [_TypeTabs] but
/// uses the avoid-tint (pink-rose) for the Avoid side so a quick glance
/// reveals which mode is selected.
class _PolarityTabs extends StatelessWidget {
  const _PolarityTabs({required this.value, required this.onChanged});
  final HabitPolarity value;
  final ValueChanged<HabitPolarity> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          for (final p in HabitPolarity.values)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(p);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: p == value
                        ? (p == HabitPolarity.avoid
                            ? const LinearGradient(
                                colors: [
                                  Color(0xFFEC4899),
                                  Color(0xFFFB7185),
                                ],
                              )
                            : AppColors.buttonGradient)
                        : null,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        p == HabitPolarity.build
                            ? Icons.add_circle_outline_rounded
                            : Icons.do_not_disturb_alt_rounded,
                        size: 14,
                        color: p == value
                            ? Colors.white
                            : BrandColors.inkDim(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        p == HabitPolarity.build
                            ? 'Build a habit'
                            : 'Avoid a habit',
                        style: TextStyle(
                          color: p == value
                              ? Colors.white
                              : BrandColors.inkDim(context),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvoidModeTabs extends StatelessWidget {
  const _AvoidModeTabs({required this.value, required this.onChanged});
  final AvoidMode value;
  final ValueChanged<AvoidMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.pink.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          for (final m in AvoidMode.values)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onChanged(m);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: m == value
                        ? AppColors.pinkLight.withValues(alpha: 0.20)
                        : null,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    m == AvoidMode.quit ? 'Quit it' : 'Cut down',
                    style: TextStyle(
                      color: m == value
                          ? AppColors.pinkLight
                          : BrandColors.inkSoft(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvoidModeHint extends StatelessWidget {
  const _AvoidModeHint({required this.mode});
  final AvoidMode mode;

  @override
  Widget build(BuildContext context) {
    final text = mode == AvoidMode.quit
        ? 'Each day you stay clean adds to your streak. A slip resets — no judgement, just data.'
        : "Log a count each day. The win is the number drifting down — small steps count.";
    return Text(
      text,
      style: TextStyle(
        color: BrandColors.inkDim(context),
        fontSize: 11.5,
        height: 1.4,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _DurationPicker extends StatelessWidget {
  const _DurationPicker({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _kReduceDurations.length; i++) ...[
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(_kReduceDurations[i]);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: _kReduceDurations[i] == value
                      ? AppColors.buttonGradient
                      : null,
                  color: _kReduceDurations[i] == value
                      ? null
                      : BrandColors.bgCard(context).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _kReduceDurations[i] == value
                        ? Colors.transparent
                        : AppColors.purple.withValues(alpha: 0.20),
                  ),
                ),
                child: Text(
                  '${_kReduceDurations[i]} days',
                  style: TextStyle(
                    color: _kReduceDurations[i] == value
                        ? Colors.white
                        : BrandColors.inkSoft(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
          if (i < _kReduceDurations.length - 1) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: disabled ? 0.7 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            gradient: AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.pink.withValues(alpha: 0.40),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

/// Counter-habit reminder presets — pre-built rhythms that match the
/// most common "8x/day" patterns. Picking one sets [_reminderMinutes]
/// in one tap; the user can then tweak individual times if they want.
enum _ReminderPreset {
  every2h,
  every3h,
  morningMiddayEvening,
}

extension _ReminderPresetX on _ReminderPreset {
  String get label {
    switch (this) {
      case _ReminderPreset.every2h:
        return 'Every 2h (9–21)';
      case _ReminderPreset.every3h:
        return 'Every 3h (9–21)';
      case _ReminderPreset.morningMiddayEvening:
        return '3 a day';
    }
  }

  List<int> minutes() {
    switch (this) {
      case _ReminderPreset.every2h:
        return [for (var h = 9; h <= 21; h += 2) h * 60];
      case _ReminderPreset.every3h:
        return [for (var h = 9; h <= 21; h += 3) h * 60];
      case _ReminderPreset.morningMiddayEvening:
        return [9 * 60, 13 * 60, 19 * 60];
    }
  }
}

/// Reminder picker rendered inside the Add/Edit Habit sheet. Three
/// states:
///
///   1. master toggle off → just the switch with a one-line copy
///   2. master toggle on, no times yet → "Add a reminder" pill
///   3. master toggle on, times set → list of time chips with edit/
///      delete, + add-reminder pill + (counter only) preset row
class _ReminderSection extends StatelessWidget {
  const _ReminderSection({
    required this.enabled,
    required this.times,
    required this.onToggle,
    required this.onAdd,
    required this.onEdit,
    required this.onRemove,
    required this.onPreset,
    required this.isCounter,
  });

  final bool enabled;
  final List<int> times;
  final ValueChanged<bool> onToggle;
  final VoidCallback onAdd;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onRemove;
  final ValueChanged<_ReminderPreset> onPreset;
  final bool isCounter;

  @override
  Widget build(BuildContext context) {
    final notif = NotificationService();
    final permissionWarning = enabled && !notif.isGranted && notif.isSupported;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                enabled
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_outlined,
                color: enabled
                    ? AppColors.pinkLight
                    : BrandColors.inkDim(context),
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  enabled
                      ? 'Notify me at:'
                      : 'No reminders for this habit',
                  style: TextStyle(
                    color: BrandColors.ink(context),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Switch.adaptive(
                value: enabled,
                onChanged: onToggle,
                activeTrackColor: AppColors.pinkLight,
              ),
            ],
          ),
          if (permissionWarning) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6B81).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFF6B81).withValues(alpha: 0.30),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 14, color: Color(0xFFFF6B81)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "Notifications permission not granted — reminders won't fire.",
                      style: TextStyle(
                        color: BrandColors.inkSoft(context),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (enabled) ...[
            const SizedBox(height: 10),
            if (times.isEmpty)
              _AddTimePill(onTap: onAdd, label: 'Add a time')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < times.length; i++)
                    _TimeChip(
                      minutes: times[i],
                      onEdit: () => onEdit(i),
                      onRemove: () => onRemove(i),
                    ),
                  _AddTimePill(onTap: onAdd, label: '+ Add'),
                ],
              ),
            if (isCounter) ...[
              const SizedBox(height: 12),
              Text(
                'PRESETS',
                style: TextStyle(
                  color: BrandColors.inkDim(context),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in _ReminderPreset.values)
                    _PresetPill(label: p.label, onTap: () => onPreset(p)),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'A tap opens Mood8 so you can mark the habit done.',
              style: TextStyle(
                color: BrandColors.inkDim(context),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({
    required this.minutes,
    required this.onEdit,
    required this.onRemove,
  });
  final int minutes;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  String _label() {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.purple.withValues(alpha: 0.30),
              AppColors.pink.withValues(alpha: 0.22),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.pinkLight.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.schedule_rounded,
                size: 14, color: BrandColors.ink(context)),
            const SizedBox(width: 6),
            Text(
              _label(),
              style: TextStyle(
                color: BrandColors.ink(context),
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: BrandColors.inkSoft(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTimePill extends StatelessWidget {
  const _AddTimePill({required this.onTap, required this.label});
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: BrandColors.bgCard(context).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.purple.withValues(alpha: 0.35),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded,
                size: 14, color: BrandColors.inkSoft(context)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: BrandColors.inkSoft(context),
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetPill extends StatelessWidget {
  const _PresetPill({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.blueAccent.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.blueAccent.withValues(alpha: 0.45),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: AppColors.blueAccent,
            fontWeight: FontWeight.w800,
            fontSize: 11,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

