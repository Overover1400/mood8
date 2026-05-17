import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../models/focus_area.dart';
import '../../../theme/app_theme.dart';
import '../onboarding_flow.dart';

class FocusAreasStep extends StatefulWidget {
  const FocusAreasStep({
    super.key,
    required this.initial,
    required this.onSubmit,
  });

  final List<FocusArea> initial;
  final ValueChanged<List<FocusArea>> onSubmit;

  @override
  State<FocusAreasStep> createState() => _FocusAreasStepState();
}

class _FocusAreasStepState extends State<FocusAreasStep> {
  late final Set<FocusArea> _selected = {...widget.initial};

  void _toggle(FocusArea area) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(area)) {
        _selected.remove(area);
      } else if (_selected.length < 4) {
        _selected.add(area);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final valid = _selected.length >= 2 && _selected.length <= 4;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What matters most\nright now?',
            style: Theme.of(context).textTheme.headlineLarge,
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
          const SizedBox(height: 8),
          Text(
            "Pick 2–4 areas we'll focus on together.",
            style: TextStyle(color: AppColors.inkDim, fontSize: 14),
          ).animate().fadeIn(delay: 120.ms, duration: 500.ms),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              itemCount: FocusArea.values.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final area = FocusArea.values[i];
                final selected = _selected.contains(area);
                return _FocusRow(
                  area: area,
                  selected: selected,
                  onTap: () => _toggle(area),
                )
                    .animate(delay: (50 * i).ms)
                    .fadeIn(duration: 320.ms)
                    .slideX(
                        begin: -0.05, end: 0, curve: Curves.easeOut);
              },
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              '${_selected.length} of 4 selected',
              style: TextStyle(
                color: AppColors.inkDim,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
          const SizedBox(height: 12),
          OnboardingPrimaryButton(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            onTap: valid ? () => widget.onSubmit(_selected.toList()) : null,
          ),
        ],
      ),
    );
  }
}

class _FocusRow extends StatelessWidget {
  const _FocusRow({
    required this.area,
    required this.selected,
    required this.onTap,
  });

  final FocusArea area;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = area.color;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color.withValues(alpha: 0.32),
                    color.withValues(alpha: 0.12),
                  ],
                )
              : null,
          color: selected ? null : AppColors.bgCard.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.7)
                : AppColors.purple.withValues(alpha: 0.18),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.30),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.20),
              ),
              child: Text(area.emoji,
                  style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    area.label,
                    style: const TextStyle(
                      color: AppColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    area.description,
                    style: const TextStyle(
                      color: AppColors.inkDim,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: selected ? AppColors.buttonGradient : null,
                color: selected
                    ? null
                    : AppColors.bg.withValues(alpha: 0.5),
                border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : AppColors.inkFaint.withValues(alpha: 0.6),
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
