import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/routine_category.dart';
import '../models/routine_item.dart';
import '../services/routine_repository.dart';
import '../theme/app_theme.dart';
import 'category_chip.dart';

const List<int> _kDurationOptions = [15, 30, 45, 60, 90, 120];

Future<void> showAddRoutineSheet(
  BuildContext context, {
  RoutineItem? editing,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => AddRoutineSheet(editing: editing),
  );
}

class AddRoutineSheet extends StatefulWidget {
  const AddRoutineSheet({super.key, this.editing});

  final RoutineItem? editing;

  @override
  State<AddRoutineSheet> createState() => _AddRoutineSheetState();
}

class _AddRoutineSheetState extends State<AddRoutineSheet> {
  final RoutineRepository _repo = RoutineRepository();
  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _metaCtrl = TextEditingController();
  final FocusNode _titleFocus = FocusNode();

  late DateTime _time;
  late int _duration;
  late RoutineCategory _category;
  String? _titleError;
  bool _saving = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final item = widget.editing;
    _titleCtrl.text = item?.title ?? '';
    _metaCtrl.text = item?.meta ?? '';
    _time = item?.time ?? _nextHalfHour();
    _duration = item?.durationMinutes ?? 30;
    _category = item?.category ?? RoutineCategory.work;
    if (!_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _titleFocus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _metaCtrl.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  static DateTime _nextHalfHour() {
    final now = DateTime.now();
    final m = now.minute < 30 ? 30 : 60;
    final base = DateTime(now.year, now.month, now.day, now.hour, 0)
        .add(Duration(minutes: m));
    return base;
  }

  Future<void> _onSave() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Give this routine a name.');
      return;
    }
    setState(() {
      _titleError = null;
      _saving = true;
    });

    try {
      if (_isEditing) {
        final item = widget.editing!;
        item.title = title;
        item.time = _time;
        item.durationMinutes = _duration;
        item.category = _category;
        item.meta = _metaCtrl.text.trim();
        await _repo.updateRoutine(item);
      } else {
        await _repo.addRoutine(
          title: title,
          time: _time,
          durationMinutes: _duration,
          category: _category,
          meta: _metaCtrl.text.trim(),
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
    final item = widget.editing;
    if (item == null) return;
    try {
      await _repo.deleteRoutine(item.id);
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
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.bg,
              AppColors.bgDeep,
            ],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                    _isEditing ? 'Edit routine' : 'New routine',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 22),
                  _Label("What's the activity?"),
                  const SizedBox(height: 8),
                  _UnderlineField(
                    controller: _titleCtrl,
                    focusNode: _titleFocus,
                    hint: 'Deep work block',
                    error: _titleError,
                    textInputAction: TextInputAction.next,
                  )
                      .animate()
                      .fadeIn(duration: 350.ms)
                      .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                  const SizedBox(height: 22),
                  _Label('When?'),
                  const SizedBox(height: 8),
                  _TimePickerCard(
                    value: _time,
                    onChanged: (t) => setState(() => _time = t),
                  )
                      .animate()
                      .fadeIn(delay: 60.ms, duration: 350.ms)
                      .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                  const SizedBox(height: 22),
                  _Label('How long?'),
                  const SizedBox(height: 8),
                  _DurationChips(
                    value: _duration,
                    onChanged: (d) => setState(() => _duration = d),
                  )
                      .animate()
                      .fadeIn(delay: 120.ms, duration: 350.ms)
                      .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                  const SizedBox(height: 22),
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
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _category = c);
                          },
                        ),
                    ],
                  )
                      .animate()
                      .fadeIn(delay: 180.ms, duration: 350.ms)
                      .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
                  const SizedBox(height: 22),
                  _Label('Notes (optional)'),
                  const SizedBox(height: 8),
                  _UnderlineField(
                    controller: _metaCtrl,
                    hint: 'Peak focus · 90 min',
                    textInputAction: TextInputAction.done,
                  )
                      .animate()
                      .fadeIn(delay: 240.ms, duration: 350.ms)
                      .slideY(begin: 0.1, end: 0, curve: Curves.easeOut),
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
                            color:
                                AppColors.purple.withValues(alpha: 0.35),
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
                      _GradientButton(
                        label: _saving
                            ? 'Saving…'
                            : (_isEditing ? 'Update' : 'Save'),
                        onTap: _saving ? null : _onSave,
                      ),
                    ],
                  ),
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
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: AppColors.inkDim,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.6,
      ),
    );
  }
}

class _UnderlineField extends StatelessWidget {
  const _UnderlineField({
    required this.controller,
    required this.hint,
    this.focusNode,
    this.error,
    this.textInputAction,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final String? error;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: textInputAction,
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
            border: UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppColors.purple.withValues(alpha: 0.30),
              ),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppColors.purple.withValues(alpha: 0.30),
              ),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(
                color: AppColors.pinkLight,
                width: 1.5,
              ),
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

class _TimePickerCard extends StatelessWidget {
  const _TimePickerCard({required this.value, required this.onChanged});

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.20),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CupertinoTheme(
          data: const CupertinoThemeData(
            brightness: Brightness.dark,
            primaryColor: AppColors.pinkLight,
            textTheme: CupertinoTextThemeData(
              dateTimePickerTextStyle: TextStyle(
                color: AppColors.ink,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            use24hFormat: true,
            initialDateTime: value,
            onDateTimeChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _DurationChips extends StatelessWidget {
  const _DurationChips({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final inPreset = _kDurationOptions.contains(value);
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final m in _kDurationOptions) ...[
            _DurationChip(
              label: _labelFor(m),
              selected: m == value,
              onTap: () {
                HapticFeedback.selectionClick();
                onChanged(m);
              },
            ),
            const SizedBox(width: 8),
          ],
          _DurationChip(
            label: inPreset ? 'Custom' : '${value}m · Custom',
            selected: !inPreset,
            onTap: () async {
              final picked = await _pickCustom(context, value);
              if (picked != null) onChanged(picked);
            },
          ),
        ],
      ),
    );
  }

  static String _labelFor(int m) {
    if (m < 60) return '${m}min';
    if (m == 60) return '1h';
    if (m % 60 == 0) return '${m ~/ 60}h';
    return '${(m / 60).toStringAsFixed(1)}h';
  }

  Future<int?> _pickCustom(BuildContext context, int initial) async {
    final ctrl = TextEditingController(text: '$initial');
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: const Text('Custom duration',
            style: TextStyle(color: AppColors.ink)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: AppColors.ink),
          decoration: const InputDecoration(
            suffixText: 'minutes',
            suffixStyle: TextStyle(color: AppColors.inkDim),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text.trim());
              if (v != null && v > 0) Navigator.of(ctx).pop(v);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
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
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.buttonGradient : null,
          color: selected ? null : AppColors.bgCard.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : AppColors.purple.withValues(alpha: 0.20),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.pink.withValues(alpha: 0.35),
                    blurRadius: 14,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.inkSoft,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onTap});
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
