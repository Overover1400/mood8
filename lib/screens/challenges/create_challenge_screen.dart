import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/challenge.dart';
import '../../services/challenge_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive_container.dart';

class CreateChallengeScreen extends StatefulWidget {
  const CreateChallengeScreen({super.key});

  @override
  State<CreateChallengeScreen> createState() => _CreateChallengeScreenState();
}

class _CreateChallengeScreenState extends State<CreateChallengeScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _maxCtrl = TextEditingController();
  String _category = 'fitness';
  int _durationDays = 30;
  TimeOfDay _deadlineLocal = const TimeOfDay(hour: 22, minute: 0);
  bool _limitParticipants = false;
  bool _submitting = false;
  String? _rejection;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _maxCtrl.dispose();
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'Add a title and a description (10+ characters).',
        )),
      );
      return;
    }
    int? max;
    if (_limitParticipants) {
      max = int.tryParse(_maxCtrl.text.trim());
      if (max == null || max < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
            'Max participants must be a number ≥ 2.',
          )),
        );
        return;
      }
    }
    final utcMinutes = localTimeToUtcMinutes(
      _deadlineLocal.hour, _deadlineLocal.minute,
    );
    setState(() {
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
          _rejection = result.reason ?? 'Your challenge wasn’t approved.';
        });
        return;
      }
      Navigator.of(context).pop<int>(result.challengeId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _rejection = e is ChallengeError ? e.message : 'Could not create — try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitting && _rejection == null) {
      return _ReviewingOverlay(onClose: () {});
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
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _TopBar(onClose: () => Navigator.of(context).maybePop()),
              const SizedBox(height: 4),
              Text(
                'Create a challenge',
                style: GoogleFonts.bricolageGrotesque(
                  color: BrandColors.ink(context),
                  fontSize: 34,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Mood8 will quickly review it before publishing — anything risky to health gets flagged kindly.',
                style: TextStyle(
                  color: BrandColors.inkSoft(context),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 22),
              _Field(
                label: 'Title',
                child: TextField(
                  controller: _titleCtrl,
                  maxLength: 80,
                  decoration: _inputDecoration(
                      hint: 'e.g. 30 days of meditation'),
                  style: TextStyle(color: BrandColors.ink(context)),
                ),
              ),
              _Field(
                label: 'Description',
                child: TextField(
                  controller: _descCtrl,
                  maxLines: 4,
                  maxLength: 600,
                  decoration: _inputDecoration(
                    hint:
                        'What does someone do every day? How do they show up?',
                  ),
                  style: TextStyle(color: BrandColors.ink(context)),
                ),
              ),
              _Field(
                label: 'Category',
                child: _CategoryDropdown(
                  current: _category,
                  onChanged: (c) => setState(() => _category = c),
                ),
              ),
              _Field(
                label: 'Duration',
                child: _DurationRow(
                  current: _durationDays,
                  onChanged: (d) => setState(() => _durationDays = d),
                ),
              ),
              _Field(
                label: 'Daily deadline',
                child: GestureDetector(
                  onTap: _pickDeadline,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: _outlineDecoration(),
                    child: Row(
                      children: [
                        Icon(Icons.alarm_rounded,
                            color: AppColors.pinkLight, size: 18),
                        const SizedBox(width: 10),
                        Text(
                          _deadlineLocal.format(context),
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
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  'Daily deadline: ${_deadlineLocal.format(context)} your time. '
                  'Check in before this each day to keep your rank.',
                  style: TextStyle(
                    color: BrandColors.inkDim(context),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
              _Field(
                label: 'Limit participants',
                child: Row(
                  children: [
                    Switch.adaptive(
                      value: _limitParticipants,
                      activeThumbColor: AppColors.pinkLight,
                      onChanged: (v) =>
                          setState(() => _limitParticipants = v),
                    ),
                    const SizedBox(width: 8),
                    if (_limitParticipants)
                      Expanded(
                        child: TextField(
                          controller: _maxCtrl,
                          keyboardType: TextInputType.number,
                          decoration:
                              _inputDecoration(hint: 'e.g. 25'),
                          style: TextStyle(color: BrandColors.ink(context)),
                        ),
                      )
                    else
                      Text(
                        'Anyone can request to join.',
                        style: TextStyle(
                          color: BrandColors.inkSoft(context),
                          fontSize: 13,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: _submit,
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
                  child: const Text(
                    'Publish challenge',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
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
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: BrandColors.inkFaint(context).withValues(alpha: 0.7),
      ),
      filled: true,
      fillColor: BrandColors.bgCard(context).withValues(alpha: 0.7),
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppColors.purple.withValues(alpha: 0.30),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: AppColors.purple.withValues(alpha: 0.30),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.pinkLight, width: 1.5),
      ),
    );
  }

  BoxDecoration _outlineDecoration() => BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.30),
        ),
      );
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

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: BrandColors.inkDim(context),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.current,
    required this.onChanged,
  });
  final String current;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.30),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: current,
          isExpanded: true,
          dropdownColor: BrandColors.bgCard(context),
          style: TextStyle(color: BrandColors.ink(context)),
          items: [
            for (final c in kChallengeCategories)
              DropdownMenuItem(
                value: c,
                child: Text(prettyCategory(c)),
              ),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _DurationRow extends StatelessWidget {
  const _DurationRow({required this.current, required this.onChanged});
  final int current;
  final ValueChanged<int> onChanged;
  static const _options = [7, 14, 30, 60, 90];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final d in _options)
          GestureDetector(
            onTap: () => onChanged(d),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: d == current ? AppColors.buttonGradient : null,
                color: d == current ? null : BrandColors.bgCard(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: d == current
                      ? Colors.transparent
                      : AppColors.purple.withValues(alpha: 0.30),
                ),
              ),
              child: Text(
                '$d days',
                style: TextStyle(
                  color: d == current
                      ? Colors.white
                      : BrandColors.inkSoft(context),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ReviewingOverlay extends StatelessWidget {
  const _ReviewingOverlay({required this.onClose});
  // ignore: unused_element_parameter
  final VoidCallback onClose;
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
                'A quick health-and-safety check. This usually takes a few seconds.',
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
                  'This is based on established health research — not a judgement of you. Edit the description and try again.',
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
