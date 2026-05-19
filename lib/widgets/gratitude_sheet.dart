import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/gratitude_entry.dart';
import '../services/gratitude_repository.dart';
import '../services/haptic_service.dart';
import '../theme/app_theme.dart';

const int _kMaxItemChars = 80;

/// Bottom-sheet entry point for the gratitude log. Returns the saved entry
/// or `null` if dismissed / skipped.
Future<GratitudeEntry?> showGratitudeSheet(
  BuildContext context, {
  GratitudeEntry? existing,
}) async {
  HapticService().light();
  return showModalBottomSheet<GratitudeEntry?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => GratitudeSheet(existing: existing),
  );
}

class GratitudeSheet extends StatefulWidget {
  const GratitudeSheet({super.key, this.existing});
  final GratitudeEntry? existing;

  @override
  State<GratitudeSheet> createState() => _GratitudeSheetState();
}

class _GratitudeSheetState extends State<GratitudeSheet> {
  final GratitudeRepository _repo = GratitudeRepository();
  late final List<TextEditingController> _ctrls;
  late final List<FocusNode> _focus;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final seed = widget.existing?.items ?? const <String>['', '', ''];
    _ctrls = [
      TextEditingController(text: seed.isNotEmpty ? seed[0] : ''),
      TextEditingController(text: seed.length > 1 ? seed[1] : ''),
      TextEditingController(text: seed.length > 2 ? seed[2] : ''),
    ];
    _focus = [FocusNode(), FocusNode(), FocusNode()];
    for (final c in _ctrls) {
      c.addListener(_onChange);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus[0].requestFocus();
    });
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.removeListener(_onChange);
      c.dispose();
    }
    for (final f in _focus) {
      f.dispose();
    }
    super.dispose();
  }

  bool get _hasAny =>
      _ctrls.any((c) => c.text.trim().isNotEmpty);

  Future<void> _save() async {
    if (_saving || !_hasAny) return;
    setState(() => _saving = true);
    try {
      final entry = await _repo.saveEntry(_ctrls.map((c) => c.text).toList());
      HapticService().medium();
      if (!mounted) return;
      Navigator.of(context).pop(entry);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _skip() {
    if (_saving) return;
    HapticService().selection();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.bgCard,
                AppColors.bg,
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.pinkLight.withValues(alpha: 0.40),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.pink.withValues(alpha: 0.26),
                blurRadius: 44,
                spreadRadius: -8,
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.inkFaint.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(child: const _HeartHero()),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  "Three things you're grateful for",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                ),
              )
                  .animate()
                  .fadeIn(duration: 320.ms)
                  .slideY(begin: 0.05, end: 0, curve: Curves.easeOut),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Small moments. Big impact.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.inkDim,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              )
                  .animate(delay: 80.ms)
                  .fadeIn(duration: 360.ms)
                  .slideY(begin: 0.05, end: 0, curve: Curves.easeOut),
              const SizedBox(height: 22),
              for (var i = 0; i < 3; i++) ...[
                _GratitudeField(
                  index: i + 1,
                  controller: _ctrls[i],
                  focusNode: _focus[i],
                  nextFocus: i < 2 ? _focus[i + 1] : null,
                  enabled: !_saving,
                  isLast: i == 2,
                  onLastSubmit: _hasAny ? _save : null,
                )
                    .animate(delay: (140 + i * 80).ms)
                    .fadeIn(duration: 320.ms)
                    .slideY(
                        begin: 0.04, end: 0, curve: Curves.easeOut),
                if (i < 2) const SizedBox(height: 10),
              ],
              const SizedBox(height: 18),
              _GradientButton(
                label: _saving ? 'Saving…' : 'Save gratitude',
                enabled: _hasAny && !_saving,
                onTap: _save,
              )
                  .animate(delay: 380.ms)
                  .fadeIn(duration: 320.ms),
              const SizedBox(height: 6),
              TextButton(
                onPressed: _saving ? null : _skip,
                child: Text(
                  'Maybe later',
                  style: TextStyle(
                    color: AppColors.inkDim,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
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

class _GratitudeField extends StatelessWidget {
  const _GratitudeField({
    required this.index,
    required this.controller,
    required this.focusNode,
    required this.nextFocus,
    required this.enabled,
    required this.isLast,
    this.onLastSubmit,
  });

  final int index;
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode? nextFocus;
  final bool enabled;
  final bool isLast;
  final VoidCallback? onLastSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bg.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.pink.withValues(alpha: 0.22),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.pinkLight.withValues(alpha: 0.65),
                  AppColors.purple.withValues(alpha: 0.18),
                ],
              ),
            ),
            child: Text(
              '$index',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              maxLength: _kMaxItemChars,
              cursorColor: AppColors.pinkLight,
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 14,
                height: 1.4,
              ),
              textCapitalization: TextCapitalization.sentences,
              textInputAction:
                  isLast ? TextInputAction.done : TextInputAction.next,
              onSubmitted: (_) {
                if (isLast) {
                  onLastSubmit?.call();
                } else {
                  nextFocus?.requestFocus();
                }
              },
              inputFormatters: [
                LengthLimitingTextInputFormatter(_kMaxItemChars),
              ],
              decoration: InputDecoration(
                isCollapsed: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: InputBorder.none,
                counterText: '',
                hintText: _hintFor(index),
                hintStyle: TextStyle(
                  color: AppColors.inkDim.withValues(alpha: 0.8),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _hintFor(int i) {
    switch (i) {
      case 1:
        return 'A person, a moment, a kindness…';
      case 2:
        return 'Something small that made you smile';
      default:
        return 'A reason to come back tomorrow';
    }
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.55,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            gradient: AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(26),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: AppColors.pink.withValues(alpha: 0.45),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: AppColors.purple.withValues(alpha: 0.32),
                      blurRadius: 26,
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite_rounded,
                  color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeartHero extends StatelessWidget {
  const _HeartHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.pinkLight.withValues(alpha: 0.85),
            AppColors.pink.withValues(alpha: 0.35),
            AppColors.purple.withValues(alpha: 0.18),
            Colors.transparent,
          ],
          stops: const [0.0, 0.4, 0.75, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.pink.withValues(alpha: 0.55),
            blurRadius: 30,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: AppColors.pinkLight.withValues(alpha: 0.45),
            blurRadius: 18,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Icon(
        Icons.favorite_rounded,
        size: 40,
        color: Colors.white,
        shadows: [
          Shadow(
            color: AppColors.pink.withValues(alpha: 0.95),
            blurRadius: 18,
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(
          begin: 1.0,
          end: 1.08,
          duration: 1500.ms,
          curve: Curves.easeInOut,
        );
  }
}
