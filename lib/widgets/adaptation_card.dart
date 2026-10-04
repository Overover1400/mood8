import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/adaptation_service.dart';
import '../services/haptic_service.dart';
import '../theme/app_theme.dart';

/// The adaptation card — the one place the engine is visible.
///
/// Spec 10.4: one card, at most once a day, never its own screen, and
/// always dismissible. It now works as a short conversation instead of
/// a verdict:
///
///   1. why?        no time · not in the mood · too hard / too much
///   2. follow-up   which part of the day (morning / afternoon / night)
///                  or what to shrink (duration / amount)
///   3. proposal    the concrete change, accept or keep as is
///
/// Older proposals that already carry a concrete change skip straight
/// to step 3.
class AdaptationCard extends StatefulWidget {
  const AdaptationCard({super.key, this.onResolved});

  /// Called after the user accepts or declines, so the host screen can
  /// refresh (an accepted time change alters today's schedule).
  final VoidCallback? onResolved;

  @override
  State<AdaptationCard> createState() => _AdaptationCardState();
}

enum _Stage { reason, window, reduce, tooSmall, proposal }

const _windowLabels = {
  'morning': 'Morning',
  'afternoon': 'Afternoon',
  'night': 'Night',
};

class _AdaptationCardState extends State<AdaptationCard> {
  AdaptationProposal? _proposal;
  _Stage _stage = _Stage.proposal;
  String? _reason; // no_time | no_mood | too_hard
  bool _busy = false;
  bool _done = false;
  String? _closing;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await AdaptationService().todaysProposal();
    if (!mounted) return;
    setState(() {
      _proposal = p;
      _stage = (p != null && p.isAsk) ? _Stage.reason : _Stage.proposal;
    });
  }

  void _pickReason(String reason) {
    final p = _proposal;
    if (p == null) return;
    HapticService().light();
    setState(() {
      _reason = reason;
      _error = null;
      if (reason == 'too_hard') {
        _stage = (p.canReduceAmount || p.canReduceDuration)
            ? _Stage.reduce
            : _Stage.tooSmall;
      } else {
        _stage = _Stage.window;
      }
    });
  }

  Future<void> _submitAnswer({String? window, String? reduce}) async {
    final p = _proposal;
    final reason = _reason;
    if (p == null || reason == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    HapticService().light();
    final next = await AdaptationService()
        .answer(p.id, reason: reason, window: window, reduce: reduce);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (next == null) {
        _error = 'Couldn\'t save that — try again.';
      } else {
        _proposal = next;
        _stage = _Stage.proposal;
      }
    });
  }

  Future<void> _respond(bool accept) async {
    final p = _proposal;
    if (p == null || _busy) return;
    setState(() => _busy = true);
    HapticService().light();
    var ok = accept
        ? await AdaptationService().accept(p.id)
        : await AdaptationService().decline(p.id);
    var applied = true;
    if (ok && accept) {
      applied = await AdaptationService().applyToHabit(p);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = true;
      _closing = !ok
          ? 'Couldn\'t save that — try again later.'
          : !accept
              ? 'Kept as it is.'
              : applied
                  ? 'Done — updated. We\'ll check in two weeks whether it '
                      'helped.'
                  : 'Saved, but we couldn\'t update the habit on this '
                      'device. Edit it by hand.';
    });
    widget.onResolved?.call();
    // Let the confirmation sit for a moment, then collapse the card.
    Future<void>.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _proposal = null);
    });
  }

  /// "Not now" on a question card: closes it and tells the server, so
  /// it isn't asked again today.
  Future<void> _dismiss() async {
    final p = _proposal;
    if (p == null || _busy) return;
    setState(() => _busy = true);
    await AdaptationService().decline(p.id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _proposal = null;
    });
    widget.onResolved?.call();
  }

  String _range(List<int> r) =>
      '${r[0].toString().padLeft(2, '0')}:00–'
      '${r[1].toString().padLeft(2, '0')}:59';

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
            else
              ..._body(context, p),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 420.ms)
          .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),
    );
  }

  Widget _question(BuildContext context, String text) => Text(
        text,
        style: GoogleFonts.plusJakartaSans(
          color: BrandColors.ink(context),
          fontSize: 15,
          height: 1.45,
          fontWeight: FontWeight.w600,
        ),
      );

  Widget _hint(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          text,
          style: TextStyle(
            color: BrandColors.inkDim(context),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Widget _backRow(VoidCallback onBack, {String label = 'Back'}) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: _busy ? null : onBack,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(label),
          ),
        ),
      );

  List<Widget> _body(BuildContext context, AdaptationProposal p) {
    final err = _error == null
        ? const <Widget>[]
        : [
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
          ];

    switch (_stage) {
      case _Stage.reason:
        return [
          _hint(context, p.habitTitle),
          _question(context, p.rationale),
          const SizedBox(height: 12),
          _Choice(
              label: 'I don\'t have time',
              onTap: () => _pickReason('no_time')),
          _Choice(
              label: 'I\'m not in the mood',
              onTap: () => _pickReason('no_mood')),
          _Choice(
              label: 'It\'s too hard or too much',
              onTap: () => _pickReason('too_hard')),
          _backRow(_dismiss, label: 'Not now'),
        ];

      case _Stage.window:
        final keys = ['morning', 'afternoon', 'night']
            .where(p.windows.containsKey)
            .toList();
        return [
          _hint(context, p.habitTitle),
          _question(
              context,
              _reason == 'no_mood'
                  ? 'When are you usually in a better mood for it?'
                  : 'Which time of day suits you?'),
          const SizedBox(height: 12),
          for (final k in keys)
            _Choice(
              label: _windowLabels[k] ?? k,
              sub: _range(p.windows[k]!),
              busy: _busy,
              onTap: () => _submitAnswer(window: k),
            ),
          ...err,
          _backRow(() => setState(() => _stage = _Stage.reason)),
        ];

      case _Stage.reduce:
        return [
          _hint(context, p.habitTitle),
          _question(context, 'What should we make smaller?'),
          const SizedBox(height: 12),
          if (p.canReduceDuration)
            _Choice(
              label: 'The duration',
              sub: 'A shorter program',
              busy: _busy,
              onTap: () => _submitAnswer(reduce: 'duration'),
            ),
          if (p.canReduceAmount)
            _Choice(
              label: 'The amount',
              sub: 'Less each day',
              busy: _busy,
              onTap: () => _submitAnswer(reduce: 'amount'),
            ),
          ...err,
          _backRow(() => setState(() => _stage = _Stage.reason)),
        ];

      case _Stage.tooSmall:
        return [
          _hint(context, p.habitTitle),
          _question(
              context,
              'This habit is already as small as it gets. Try a different '
              'time instead?'),
          const SizedBox(height: 12),
          _Choice(
            label: 'Pick a time of day',
            onTap: () => setState(() {
              _reason = 'no_time';
              _stage = _Stage.window;
            }),
          ),
          _backRow(() => setState(() => _stage = _Stage.reason)),
        ];

      case _Stage.proposal:
        return [
          _question(context, p.rationale),
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
          ...err,
        ];
    }
  }
}

/// One full-width answer option on a question step.
class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.onTap,
    this.sub,
    this.busy = false,
  });

  final String label;
  final String? sub;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: busy ? null : onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: BrandColors.bgDeep(context).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppColors.purple.withValues(alpha: 0.34)),
            ),
            child: Row(
              children: [
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
                if (sub != null)
                  Text(
                    sub!,
                    style: TextStyle(
                      color: BrandColors.inkDim(context),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
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
