import 'package:flutter/material.dart';

import '../models/habit.dart';
import '../services/anchor_service.dart';
import '../services/habit_repository.dart';
import '../services/haptic_service.dart';
import '../theme/app_theme.dart';

/// Spec 3.2 — the anchor offer.
///
/// Shown at most once a day, for one habit that is being missed and has
/// no anchor yet. Every option is one tap; declining is one tap and is
/// remembered permanently for that habit.
class AnchorSheet extends StatelessWidget {
  const AnchorSheet({super.key, required this.habit});

  final Habit habit;

  /// Offers an anchor for [habit] if the once-a-day budget allows.
  /// Returns true when the user set one.
  static Future<bool> maybeShow(
    BuildContext context, {
    required Habit habit,
  }) async {
    final svc = AnchorService();
    if (!await svc.shouldOfferToday()) return false;
    await svc.markOffered();
    if (!context.mounted) return false;
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AnchorSheet(habit: habit),
    );
    return result ?? false;
  }

  Future<void> _choose(BuildContext context, String anchor) async {
    HapticService().selection();
    habit.anchor = anchor;
    await HabitRepository().updateHabit(habit);
    if (context.mounted) Navigator.of(context).pop(true);
  }

  Future<void> _decline(BuildContext context) async {
    await AnchorService().markDeclined(habit);
    if (context.mounted) Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final options = AnchorService().suggestionsFor(habit);
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(14),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: BoxDecoration(
          color: BrandColors.bgCard(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.purple.withValues(alpha: 0.30)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: BrandColors.inkFaint(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tie it to something you already do.',
              style: TextStyle(
                color: BrandColors.ink(context),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Habits stick better when they follow a routine that’s '
              'already automatic. When could “${habit.title}” go?',
              style: TextStyle(
                color: BrandColors.inkSoft(context),
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            for (final o in options) ...[
              _AnchorOption(
                label: 'After $o',
                onTap: () => _choose(context, o),
              ),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 2),
            Center(
              child: TextButton(
                onPressed: () => _decline(context),
                child: Text(
                  'Not for this one',
                  style: TextStyle(
                    color: BrandColors.inkDim(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnchorOption extends StatelessWidget {
  const _AnchorOption({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: BrandColors.bgDeep(context).withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.purple.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Icon(Icons.link_rounded, size: 16, color: AppColors.purpleLight),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: BrandColors.ink(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
