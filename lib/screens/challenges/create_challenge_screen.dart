import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/challenge.dart';
import '../../services/challenge_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive_container.dart';

/// Visual vocabulary deliberately mirrors `add_habit_sheet.dart` — same
/// underline fields, segmented chip rows, gradient save pill — so
/// creating a challenge feels like the same flow as creating a habit.
class CreateChallengeScreen extends StatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _maxCtrl = TextEditingController(text: '25');
  final _titleFocus = FocusNode();

  String _category = 'fitness';
  int _durationDays = 30;
  TimeOfDay _deadlineLocal = const TimeOfDay(hour: 22, minute: 0);
  bool _limitParticipants = false;
  bool _submitting = false;
  String? _rejection;
  String? _formError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _titleFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _maxCtrl.dispose();
    _titleFocus.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _deadlineLocal,
    );
    if (picked != null && mounted) {
      setState(() => _deadlineLocal = picked);
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final title = _titleCtrl.text.trim();
    final description = _descCtrl.text.trim();
    if (title.length < 3 || description.length < 10) {
      setState(() => _formError =
          'Add a title and a description (10+ characters).');
      return;
    }
    int? max;
    if (_limitParticipants) {
      max = int.tryParse(_maxCtrl.text.trim());
      if (max == null || max < 2) {
        setState(() =>
            _formError = 'Max participants must be a number ≥ 2.');
        return;
      }
    }
    final utcMinutes = localTimeToUtcMinutes(
      _deadlineLocal.hour, _deadlineLocal.minute,
    );
    setState(() {
      _formError = null;
      _submitting = true;
      _rejection = null;
    });
    HapticService().medium();
    try {
      final result = await ChallengeService().create(
        title: title,
        description: description,
        category: _category,
        durationDays: _durationDays,
        dailyDeadlineMinutesUtc: utcMinutes,
        maxParticipants: max,
      );
      if (!mounted) return;
      if (!result.published) {
        setState(() {
          _submitting = false;
          _rejection =
              result.reason ?? 'Your challenge wasn’t approved.';
        });
        return;
      }
      Navigator.of(context).pop<int>(result.challengeId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _rejection = e is ChallengeError
            ? e.message
            : 'Could not create — try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitting && _rejection == null) {
      return const _ReviewingOverlay();
    }
    if (_rejection != null) {
      return _RejectionScreen(
        reason: _rejection!,
        onEdit: () => setState(() => _rejection = null),
      );
    }
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 600,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 6, 24, 32),
            children: [
              _TopBar(onClose: () => Navigator.of(context).maybePop()),
              const SizedBox(height: 4),
              Text(
                'New challenge',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Mood8 quickly reviews each one — anything risky to health '
                'gets flagged kindly.',
                style: TextStyle(
                  color: BrandColors.inkSoft(context),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              const _Label('Category'),
              const SizedBox(height: 8),
              _CategoryChips(
                current: _category,
                onChanged: (c) {
                  HapticFeedback.selectionClick();
                  setState(() => _category = c);
                },
              ),
              const SizedBox(height: 20),
              const _Label('Title'),
              const SizedBox(height: 8),
              _UnderlineField(
                controller: _titleCtrl,
                focusNode: _titleFocus,
                hint: '30 days of meditation',
                maxLength: 80,
              ),
              const SizedBox(height: 20),
              const _Label('What does each day look like?'),
              const SizedBox(height: 8),
              _UnderlineField(
                controller: _descCtrl,
                hint: 'How does someone show up every day?',
                maxLength: 600,
                minLines: 3,
                maxLines: 5,
              ),
              const SizedBox(height: 20),
              const _Label('Duration'),
              const SizedBox(height: 8),
              _DurationTabs(
                current: _durationDays,
                onChanged: (d) {
                  HapticFeedback.selectionClick();
                  setState(() => _durationDays = d);
                },
              ),
              const SizedBox(height: 20),
              const _Label('Daily deadline'),
              const SizedBox(height: 8),
              _DeadlineTile(
                value: _deadlineLocal,
                onTap: _pickDeadline,
              ),
              const SizedBox(height: 4),
              Text(
                'Check in before this each day to keep your rank in the '
                'challenge.',
                style: TextStyle(
                  color: BrandColors.inkDim(context),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              const _Label('Participant limit'),
              const SizedBox(height: 8),
              _LimitToggle(
                limit: _limitParticipants,
                controller: _maxCtrl,
                onToggle: (v) {
                  HapticFeedback.selectionClick();
                  setState(() => _limitParticipants = v);
                },
              ),
              if (_formError != null) ...[
                const SizedBox(height: 14),
                Text(
                  _formError!,
                  style: const TextStyle(
                    color: Color(0xFFFF6B81),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 26),
              _PublishButton(onTap: _submit),
            ]
                .map((w) => w
                    .animate()
                    .fadeIn(duration: 320.ms)
                    .slideY(begin: 0.02, end: 0))
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});
  final VoidCallback onClose;
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: IconButton(
        icon: Icon(Icons.close_rounded,
            color: BrandColors.inkSoft(context)),
        onPressed: onClose,
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

class _UnderlineField extends StatelessWidget {
  const _UnderlineField({
    required this.controller,
    required this.hint,
    this.focusNode,
    this.maxLength,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hint;
  final FocusNode? focusNode;
  final int? maxLength;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      cursorColor: AppColors.purpleLight,
      maxLength: maxLength,
      minLines: minLines,
      maxLines: maxLines,
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
        counterText: '',
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

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.current, required this.onChanged});
  final String current;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in kChallengeCategories)
          GestureDetector(
            onTap: () => onChanged(c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient:
                    c == current ? AppColors.buttonGradient : null,
                color: c == current
                    ? null
                    : BrandColors.bgCard(context).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: c == current
                      ? Colors.transparent
                      : AppColors.purple.withValues(alpha: 0.20),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _iconForCategory(c),
                    color: c == current
                        ? Colors.white
                        : BrandColors.inkSoft(context),
                    size: 13,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    prettyCategory(c),
                    style: TextStyle(
                      color: c == current
                          ? Colors.white
                          : BrandColors.inkSoft(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DurationTabs extends StatelessWidget {
  const _DurationTabs({required this.current, required this.onChanged});
  final int current;
  final ValueChanged<int> onChanged;

  static const _options = [7, 14, 30, 60, 90];

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
          for (final d in _options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: d == current
                        ? AppColors.buttonGradient
                        : null,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    '${d}d',
                    style: TextStyle(
                      color: d == current
                          ? Colors.white
                          : BrandColors.inkDim(context),
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

class _DeadlineTile extends StatelessWidget {
  const _DeadlineTile({required this.value, required this.onTap});
  final TimeOfDay value;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: BrandColors.bgCard(context).withValues(alpha: 0.70),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.purple.withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.alarm_rounded,
                color: AppColors.pinkLight, size: 18),
            const SizedBox(width: 10),
            Text(
              value.format(context),
              style: TextStyle(
                color: BrandColors.ink(context),
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded,
                color: BrandColors.inkDim(context)),
          ],
        ),
      ),
    );
  }
}

class _LimitToggle extends StatelessWidget {
  const _LimitToggle({
    required this.limit,
    required this.controller,
    required this.onToggle,
  });
  final bool limit;
  final TextEditingController controller;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: limit
                ? TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    style: TextStyle(
                      color: BrandColors.ink(context),
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: '25',
                      hintStyle: TextStyle(
                        color: BrandColors.inkFaint(context),
                      ),
                      suffixText: 'max',
                      suffixStyle: TextStyle(
                        color: BrandColors.inkDim(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : Text(
                    'Anyone can request to join',
                    style: TextStyle(
                      color: BrandColors.inkSoft(context),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          Switch.adaptive(
            value: limit,
            activeThumbColor: AppColors.pinkLight,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}

class _PublishButton extends StatelessWidget {
  const _PublishButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppColors.buttonGradient,
          borderRadius: BorderRadius.circular(27),
          boxShadow: [
            BoxShadow(
              color: AppColors.pink.withValues(alpha: 0.45),
              blurRadius: 24,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text(
              'Publish challenge',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
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

class _ReviewingOverlay extends StatelessWidget {
  const _ReviewingOverlay();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.orbGradient,
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 36),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scaleXY(
                    begin: 1.0,
                    end: 1.08,
                    duration: 1400.ms,
                    curve: Curves.easeInOut,
                  ),
              const SizedBox(height: 22),
              Text(
                'Reviewing your challenge…',
                textAlign: TextAlign.center,
                style: GoogleFonts.bricolageGrotesque(
                  color: BrandColors.ink(context),
                  fontSize: 28,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'A quick health-and-safety check. This usually takes a few '
                'seconds.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: BrandColors.inkSoft(context),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  valueColor: AlwaysStoppedAnimation(Color(0xFFEC4899)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RejectionScreen extends StatelessWidget {
  const _RejectionScreen({required this.reason, required this.onEdit});
  final String reason;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 560,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    icon: Icon(Icons.arrow_back_rounded,
                        color: BrandColors.inkSoft(context)),
                    onPressed: onEdit,
                  ),
                ),
                const Spacer(),
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.pink.withValues(alpha: 0.18),
                    border: Border.all(
                      color: AppColors.pinkLight.withValues(alpha: 0.55),
                    ),
                  ),
                  child: Icon(Icons.favorite_rounded,
                      color: AppColors.pinkLight, size: 32),
                ),
                const SizedBox(height: 18),
                Text(
                  'Let’s rework this one.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bricolageGrotesque(
                    color: BrandColors.ink(context),
                    fontSize: 30,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  reason,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: BrandColors.inkSoft(context),
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'This is based on established health research — not a '
                  'judgement of you. Edit the description and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: BrandColors.inkDim(context),
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
                const Spacer(flex: 2),
                GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    width: double.infinity,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: AppColors.buttonGradient,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: const Text(
                      'Edit and resubmit',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

IconData _iconForCategory(String c) {
  switch (c.toLowerCase()) {
    case 'health':
      return Icons.favorite_rounded;
    case 'fitness':
      return Icons.directions_run_rounded;
    case 'mindfulness':
      return Icons.self_improvement_rounded;
    case 'productivity':
      return Icons.bolt_rounded;
    case 'learning':
      return Icons.menu_book_rounded;
    case 'social':
      return Icons.groups_rounded;
    default:
      return Icons.flag_rounded;
  }
}
