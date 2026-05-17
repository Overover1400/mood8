import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../onboarding_flow.dart';

class NameStep extends StatefulWidget {
  const NameStep({super.key, required this.initial, required this.onSubmit});

  final String initial;
  final ValueChanged<String> onSubmit;

  @override
  State<NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<NameStep> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);
  late final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text(
            'First things first…',
            style: Theme.of(context).textTheme.headlineLarge,
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
          const SizedBox(height: 8),
          Text(
            'What should we call you?',
            style: TextStyle(color: AppColors.inkDim, fontSize: 15),
          ).animate().fadeIn(delay: 120.ms, duration: 500.ms),
          const SizedBox(height: 32),
          _GradientField(
            controller: _ctrl,
            focusNode: _focus,
            onSubmit: _submit,
          )
              .animate()
              .fadeIn(delay: 220.ms, duration: 600.ms)
              .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
          const Spacer(),
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final valid = _ctrl.text.trim().length >= 2;
              return OnboardingPrimaryButton(
                label: 'Continue',
                icon: Icons.arrow_forward_rounded,
                onTap: valid ? _submit : null,
              );
            },
          ),
        ],
      ),
    );
  }

  void _submit() {
    final value = _ctrl.text.trim();
    if (value.length < 2) return;
    widget.onSubmit(value);
  }
}

class _GradientField extends StatelessWidget {
  const _GradientField({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          focusNode: focusNode,
          onSubmitted: (_) => onSubmit(),
          textInputAction: TextInputAction.done,
          cursorColor: AppColors.pinkLight,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.instrumentSerif(
            color: AppColors.ink,
            fontStyle: FontStyle.italic,
            fontSize: 28,
          ),
          decoration: InputDecoration(
            hintText: 'Your name',
            hintStyle: GoogleFonts.instrumentSerif(
              color: AppColors.inkDim.withValues(alpha: 0.7),
              fontStyle: FontStyle.italic,
              fontSize: 28,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
        Container(
          height: 2,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            gradient: AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: AppColors.pink.withValues(alpha: 0.45),
                blurRadius: 10,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
