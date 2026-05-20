import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/haptic_service.dart';
import '../services/intention_repository.dart';
import '../theme/app_theme.dart';

const int _kMaxIntentionChars = 120;

/// Bottom-sheet entry point for the morning intention. Returns the saved
/// text or `null` if dismissed / skipped.
Future<String?> showIntentionSheet(
  BuildContext context, {
  String? existingText,
}) async {
  HapticService().light();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (ctx) => IntentionSheet(initialText: existingText),
  );
}

class IntentionSheet extends StatefulWidget {
  const IntentionSheet({super.key, this.initialText});
  final String? initialText;

  @override
  State<IntentionSheet> createState() => _IntentionSheetState();
}

class _IntentionSheetState extends State<IntentionSheet> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initialText ?? '');
  final FocusNode _focus = FocusNode();
  final IntentionRepository _repo = IntentionRepository();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void _onChange() => setState(() {});

  @override
  void dispose() {
    _ctrl.removeListener(_onChange);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _ctrl.text.trim();
    if (_saving || text.isEmpty) return;
    setState(() => _saving = true);
    try {
      await _repo.saveIntention(text);
      HapticService().medium();
      if (!mounted) return;
      Navigator.of(context).pop(text);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _skip() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _repo.skipToday();
      HapticService().selection();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = _ctrl.text;
    final canSave = text.trim().isNotEmpty && !_saving;
    final remaining = _kMaxIntentionChars - text.characters.length;

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
                BrandColors.bgCard(context),
                BrandColors.bg(context),
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppColors.purple.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.pink.withValues(alpha: 0.22),
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
                    color: BrandColors.inkFaint(context).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Center(child: const _Sunrise()),
              const SizedBox(height: 18),
              Center(
                child: Text(
                  "Set today's intention",
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
                  "What's one thing that would make today great?",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: BrandColors.inkDim(context),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              )
                  .animate(delay: 80.ms)
                  .fadeIn(duration: 360.ms)
                  .slideY(begin: 0.05, end: 0, curve: Curves.easeOut),
              const SizedBox(height: 20),
              _IntentionField(
                controller: _ctrl,
                focusNode: _focus,
                enabled: !_saving,
                onSubmit: canSave ? _save : null,
              )
                  .animate(delay: 140.ms)
                  .fadeIn(duration: 360.ms),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Spacer(),
                  Text(
                    '$remaining',
                    style: TextStyle(
                      color: remaining <= 10
                          ? AppColors.pinkLight
                          : BrandColors.inkFaint(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _GradientButton(
                label: _saving ? 'Saving…' : 'Set intention',
                enabled: canSave,
                onTap: _save,
              )
                  .animate(delay: 200.ms)
                  .fadeIn(duration: 320.ms),
              const SizedBox(height: 6),
              TextButton(
                onPressed: _saving ? null : _skip,
                child: Text(
                  'Skip for today',
                  style: TextStyle(
                    color: BrandColors.inkDim(context),
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

class _IntentionField extends StatelessWidget {
  const _IntentionField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: BrandColors.bg(context).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.28),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        minLines: 2,
        maxLines: 4,
        cursorColor: AppColors.pinkLight,
        style: TextStyle(
          color: BrandColors.ink(context),
          fontSize: 15,
          height: 1.4,
        ),
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => onSubmit?.call(),
        inputFormatters: [
          LengthLimitingTextInputFormatter(_kMaxIntentionChars),
        ],
        decoration: InputDecoration(
          isCollapsed: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 6),
          border: InputBorder.none,
          hintText: 'e.g., Finish my morning workout…',
          hintStyle: TextStyle(
            color: BrandColors.inkDim(context).withValues(alpha: 0.8),
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ),
    );
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
                      color: AppColors.pink.withValues(alpha: 0.42),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: AppColors.purple.withValues(alpha: 0.34),
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
              const Icon(Icons.auto_awesome_rounded,
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

class _Sunrise extends StatelessWidget {
  const _Sunrise();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            const Color(0xFFFFD08A).withValues(alpha: 0.85),
            AppColors.pink.withValues(alpha: 0.32),
            AppColors.purple.withValues(alpha: 0.18),
            Colors.transparent,
          ],
          stops: const [0.0, 0.35, 0.7, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.pink.withValues(alpha: 0.45),
            blurRadius: 30,
            spreadRadius: -2,
          ),
          BoxShadow(
            color: const Color(0xFFFFD08A).withValues(alpha: 0.55),
            blurRadius: 18,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Icon(
        Icons.wb_sunny_rounded,
        size: 42,
        color: Colors.white,
        shadows: [
          Shadow(
            color: const Color(0xFFFFD08A).withValues(alpha: 0.95),
            blurRadius: 18,
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(
          begin: 1.0,
          end: 1.08,
          duration: 1800.ms,
          curve: Curves.easeInOut,
        );
  }
}
