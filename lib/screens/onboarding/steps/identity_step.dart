import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../theme/app_theme.dart';
import '../onboarding_flow.dart';

class _IdentityOption {
  const _IdentityOption(this.label, this.emoji, this.description);
  final String label;
  final String emoji;
  final String description;
}

const List<_IdentityOption> _kIdentities = [
  _IdentityOption('Athlete', '💪', 'Strong, energetic, disciplined'),
  _IdentityOption('Creator', '🎨', 'Builder of things that matter'),
  _IdentityOption('Mindful', '🧘', 'Calm, present, aware'),
  _IdentityOption('Scholar', '📚', 'Always learning, curious'),
  _IdentityOption('Connector', '❤️', 'Deep relationships, great listener'),
  _IdentityOption('Leader', '🌟', 'Inspires others, takes initiative'),
  _IdentityOption('Entrepreneur', '🚀', 'Builds, takes risks'),
  _IdentityOption('Parent', '👨‍👩‍👧', 'Present, patient, loving'),
];

const int _kMaxIdentities = 3;

class IdentityStep extends StatefulWidget {
  const IdentityStep({
    super.key,
    required this.initial,
    required this.onSubmit,
  });

  final List<String> initial;
  final ValueChanged<List<String>> onSubmit;

  @override
  State<IdentityStep> createState() => _IdentityStepState();
}

class _IdentityStepState extends State<IdentityStep> {
  late final Set<String> _selected = {...widget.initial};

  void _toggle(String label) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(label)) {
        _selected.remove(label);
      } else if (_selected.length < _kMaxIdentities) {
        _selected.add(label);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Who do you want\nto become?',
            style: Theme.of(context).textTheme.headlineLarge,
          )
              .animate()
              .fadeIn(duration: 500.ms)
              .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
          const SizedBox(height: 8),
          Text(
            "Choose up to 3. We'll help you become this person.",
            style: TextStyle(color: AppColors.inkDim, fontSize: 14),
          ).animate().fadeIn(delay: 120.ms, duration: 500.ms),
          const SizedBox(height: 18),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.95,
              ),
              itemCount: _kIdentities.length,
              itemBuilder: (context, i) {
                final option = _kIdentities[i];
                final selected = _selected.contains(option.label);
                return _IdentityCard(
                  option: option,
                  selected: selected,
                  onTap: () => _toggle(option.label),
                )
                    .animate(delay: (60 * i).ms)
                    .fadeIn(duration: 350.ms)
                    .slideY(begin: 0.08, end: 0, curve: Curves.easeOut);
              },
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '${_selected.length} of $_kMaxIdentities selected',
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
            onTap: _selected.isEmpty
                ? null
                : () => widget.onSubmit(_selected.toList()),
          ),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final _IdentityOption option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.purple.withValues(alpha: 0.55),
                    AppColors.pink.withValues(alpha: 0.45),
                  ],
                )
              : null,
          color: selected ? null : AppColors.bgCard.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected
                ? AppColors.pinkLight.withValues(alpha: 0.65)
                : AppColors.purple.withValues(alpha: 0.18),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.pink.withValues(alpha: 0.40),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(option.emoji, style: const TextStyle(fontSize: 30)),
            const Spacer(),
            Text(
              option.label,
              style: selected
                  ? GoogleFonts.instrumentSerif(
                      color: Colors.white,
                      fontStyle: FontStyle.italic,
                      fontSize: 22,
                      height: 1.0,
                    )
                  : const TextStyle(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
            ),
            const SizedBox(height: 4),
            Text(
              option.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected
                    ? Colors.white.withValues(alpha: 0.85)
                    : AppColors.inkDim,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
