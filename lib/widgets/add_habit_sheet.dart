import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/frequency.dart';
import '../models/habit.dart';
import '../models/habit_type.dart';
import '../models/routine_category.dart';
import '../services/habit_repository.dart';
import '../services/user_repository.dart';
import '../theme/app_theme.dart';
import 'category_chip.dart';

const List<String> _kEmojiPresets = [
  '💧', '🧘', '📚', '💪', '☕', '🚶',
  '🎨', '✍️', '🎵', '🧠', '💭', '❤️',
];

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
  String? _titleError;
  bool _saving = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _emoji = e?.icon ?? '💧';
    _type = e?.habitType ?? HabitType.yesNo;
    _identity = e?.identity ?? 'General';
    _category = e?.category ?? RoutineCategory.health;
    _frequency = e?.frequency ?? Frequency.daily;
    _customDays = {...?e?.frequencyDays};
    _titleCtrl.text = e?.title ?? '';
    _targetCtrl.text = (e?.targetValue ?? _defaultTarget()).toString();
    _unitCtrl.text = e?.targetUnit ?? _type.defaultUnit;
    if (!_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _titleFocus.requestFocus();
      });
    }
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
    setState(() {
      _titleError = null;
      _saving = true;
    });

    try {
      final target = _type == HabitType.yesNo
          ? 1
          : (int.tryParse(_targetCtrl.text.trim()) ?? _defaultTarget());
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
        await _repo.updateHabit(h);
      } else {
        await _repo.addHabit(
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
        );
      }
      HapticFeedback.lightImpact();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save: $e'),
          backgroundColor: AppColors.bgCard,
        ),
      );
    }
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
          backgroundColor: AppColors.bgCard,
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
            colors: [AppColors.bg, AppColors.bgDeep],
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
                        color: AppColors.inkFaint.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Text(
                    _isEditing ? 'Edit habit' : 'New habit',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 18),
                  _Label('Icon'),
                  const SizedBox(height: 8),
                  _EmojiPicker(
                    value: _emoji,
                    onChanged: (e) => setState(() => _emoji = e),
                  ),
                  const SizedBox(height: 18),
                  _Label("What's the habit?"),
                  const SizedBox(height: 8),
                  _UnderlineField(
                    controller: _titleCtrl,
                    focusNode: _titleFocus,
                    hint: 'Drink water',
                    error: _titleError,
                  ),
                  const SizedBox(height: 18),
                  _Label('Type'),
                  const SizedBox(height: 8),
                  _TypeTabs(value: _type, onChanged: _onTypeChange),
                  if (_type != HabitType.yesNo) ...[
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
                          foregroundColor: AppColors.inkSoft,
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
          color: AppColors.inkDim,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
        ),
      );
}

class _EmojiPicker extends StatelessWidget {
  const _EmojiPicker({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final e in _kEmojiPresets)
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
                    value == e ? null : AppColors.bgCard.withValues(alpha: 0.7),
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
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppColors.inkDim.withValues(alpha: 0.8),
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
      style: const TextStyle(
        color: AppColors.ink,
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
        color: AppColors.bgCard.withValues(alpha: 0.7),
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
                      color: t == value ? Colors.white : AppColors.inkDim,
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
                    : AppColors.bgCard.withValues(alpha: 0.6),
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
                  color: o == value ? Colors.white : AppColors.inkSoft,
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
                    : AppColors.bgCard.withValues(alpha: 0.6),
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
                  color: f == value ? Colors.white : AppColors.inkSoft,
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
                      : AppColors.bgCard.withValues(alpha: 0.6),
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
                        : AppColors.inkSoft,
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
