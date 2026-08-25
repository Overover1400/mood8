import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/adaptation_service.dart';
import '../services/haptic_service.dart';
import '../theme/app_theme.dart';

/// The adaptation card — the one place the engine is visible.
///
/// Spec 10.4: one card, one sentence, two buttons. It appears inline in
/// the normal flow, never as its own screen, at most once a day, and it
/// is always dismissible. Everything the engine knows is compressed
/// into a single sentence the user can accept or ignore in one tap.
class AdaptationCard extends StatefulWidget {
  const AdaptationCard({super.key, this.onResolved});

  /// Called after the user accepts or declines, so the host screen can
  /// refresh (an accepted time change alters today's schedule).
  final VoidCallback? onResolved;

  @override
  State<AdaptationCard> createState() => _AdaptationCardState();
}

class _AdaptationCardState extends State<AdaptationCard> {
  AdaptationProposal? _proposal;
  bool _busy = false;
  bool _done = false;
  String? _closing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await AdaptationService().todaysProposal();
    if (!mounted) return;
    setState(() => _proposal = p);
  }

  Future<void> _respond(bool accept) async {
    final p = _proposal;
    if (p == null || _busy) return;
    setState(() => _busy = true);
    HapticService().light();
    final ok = accept
        ? await AdaptationService().accept(p.id)
        : await AdaptationService().decline(p.id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = true;
      _closing = ok
          ? (accept
              ? 'Done — updated. We\'ll check in two weeks whether it helped.'
              : 'Kept as it is.')
          : 'Couldn\'t save that — try again later.';
    });
    widget.onResolved?.call();
    // Let the confirmation sit for a moment, then collapse the card.
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _proposal = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _proposal;
    if (p == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.purple.withValues(alpha: 0.18),
              BrandColors.bgCard(context).withValues(alpha: 0.94),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.purple.withValues(alpha: 0.34),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 18,
              spreadRadius: -8,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_fix_high_rounded,
                    size: 17, color: AppColors.pinkLight),
                const SizedBox(width: 7),
                Text(
                  'YOUR PLAN, ADJUSTED',
                  style: TextStyle(
                    color: BrandColors.inkDim(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_done)
              Text(
                _closing ?? '',
                style: TextStyle(
                  color: BrandColors.inkSoft(context),
                  fontSize: 14.5,
                  height: 1.45,
                ),
              )
            else ...[
              Text(
                p.rationale,
                style: GoogleFonts.plusJakartaSans(
                  color: BrandColors.ink(context),
                  fontSize: 15,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _Btn(
                      label: p.acceptLabel,
                      primary: true,
                      busy: _busy,
                      onTap: () => _respond(true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Btn(
                      label: p.declineLabel,
                      primary: false,
                      busy: _busy,
                      onTap: () => _respond(false),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 420.ms)
          .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
    );
  }
}

class _Btn extends StatelessWidget {
  const _Btn({
    required this.label,
    required this.primary,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool primary;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: busy ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: primary
                ? LinearGradient(colors: [
                    AppColors.purpleLight,
                    AppColors.pinkLight,
                  ])
                : null,
            color: primary
                ? null
                : BrandColors.bgDeep(context).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(22),
            border: primary
                ? null
                : Border.all(
                    color: AppColors.purple.withValues(alpha: 0.34)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: primary ? Colors.white : BrandColors.inkSoft(context),
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}
