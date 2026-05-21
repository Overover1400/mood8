import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/share_card_data.dart';
import '../models/weekly_recap.dart';
import '../services/haptic_service.dart';
import '../services/weekly_recap_service.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_container.dart';
import 'share_progress_screen.dart';

class WeeklyRecapScreen extends StatefulWidget {
  const WeeklyRecapScreen({
    super.key,
    this.existing,
    this.autoGenerate = true,
  });

  /// Pre-rendered recap (history mode, no AI call).
  final WeeklyRecap? existing;

  /// When true and no `existing` provided, the screen kicks off
  /// `generateAndSendRecap()` immediately on first frame.
  final bool autoGenerate;

  @override
  State<WeeklyRecapScreen> createState() => _WeeklyRecapScreenState();
}

class _WeeklyRecapScreenState extends State<WeeklyRecapScreen> {
  final WeeklyRecapService _service = WeeklyRecapService();

  WeeklyRecap? _recap;
  bool _loading = false;
  bool _resending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _recap = widget.existing;
    if (_recap == null && widget.autoGenerate) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _kickoff());
    }
  }

  Future<void> _kickoff() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await _service.generateAndSendRecap();
    if (!mounted) return;
    if (result == null) {
      setState(() {
        _loading = false;
        _error = "Couldn't reach Mood8. Try again in a moment.";
      });
      return;
    }
    HapticService().medium();
    setState(() {
      _recap = result;
      _loading = false;
    });
  }

  Future<void> _emailMe() async {
    if (_recap == null || _resending) return;
    setState(() => _resending = true);
    HapticService().light();
    final result =
        await _service.generateAndSendRecap(sendEmail: true);
    if (!mounted) return;
    setState(() {
      _resending = false;
      if (result != null) _recap = result;
    });
    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Recap emailed to you.'),
          backgroundColor: BrandColors.bgCard(context),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
    }
  }

  Future<void> _share() async {
    if (_recap == null) return;
    HapticService().light();
    // Prefer the visual card flow — far more shareable than plain text
    // and represents the brand on social. The previous plain-text share
    // is retired in favour of the image.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ShareProgressScreen(
          initialTemplate: ShareCardTemplate.weekRecap,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      body: Stack(
        children: [
          const _BackgroundGlow(),
          SafeArea(
            child: ResponsiveContainer(
              maxWidth: 560,
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _Header(onClose: _close)),
                  SliverToBoxAdapter(child: _content()),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _close() {
    HapticService().selection();
    Navigator.of(context).maybePop();
  }

  Widget _content() {
    if (_loading) return const _LoadingState();
    if (_error != null) return _ErrorState(message: _error!, onRetry: _kickoff);
    final r = _recap;
    if (r == null) return const SizedBox.shrink();
    return _LoadedState(
      recap: r,
      resending: _resending,
      onEmail: r.emailSent ? null : _emailMe,
      onShare: _share,
    );
  }
}

// ─── Header ─────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WEEKLY RECAP',
                  style: TextStyle(
                    color: AppColors.pinkLight,
                    fontSize: 11,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your week in review',
                  style: GoogleFonts.instrumentSerif(
                    color: BrandColors.ink(context),
                    fontStyle: FontStyle.italic,
                    fontSize: 32,
                    height: 1.05,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: Icon(
              Icons.close_rounded,
              color: BrandColors.inkSoft(context),
              size: 22,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Loading ────────────────────────────────────────────────────────────

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 160,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.purple.withValues(alpha: 0.22),
                  AppColors.pink.withValues(alpha: 0.10),
                ],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.purpleLight.withValues(alpha: 0.40),
              ),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ShimmerOrb()
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .scaleXY(
                      begin: 0.92,
                      end: 1.08,
                      duration: 1500.ms,
                      curve: Curves.easeInOut,
                    ),
                const SizedBox(height: 18),
                Text(
                  'Reading your week…',
                  style: GoogleFonts.instrumentSerif(
                    color: BrandColors.ink(context),
                    fontStyle: FontStyle.italic,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _ShimmerBlock(height: 100),
          const SizedBox(height: 12),
          _ShimmerBlock(height: 60),
          const SizedBox(height: 12),
          _ShimmerBlock(height: 60),
        ],
      ),
    );
  }
}

class _ShimmerOrb extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            AppColors.pinkLight.withValues(alpha: 0.85),
            AppColors.purple.withValues(alpha: 0.30),
            Colors.transparent,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.pink.withValues(alpha: 0.50),
            blurRadius: 24,
            spreadRadius: -2,
          ),
        ],
      ),
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock({required this.height});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.18),
        ),
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeIn(begin: 0.55, duration: 900.ms);
  }
}

// ─── Error ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
        decoration: BoxDecoration(
          color: BrandColors.bgCard(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.pink.withValues(alpha: 0.40),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A little hiccup',
              style: GoogleFonts.instrumentSerif(
                color: BrandColors.ink(context),
                fontStyle: FontStyle.italic,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                color: BrandColors.inkSoft(context),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Text(
                  'Try again',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
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

// ─── Loaded ─────────────────────────────────────────────────────────────

class _LoadedState extends StatelessWidget {
  const _LoadedState({
    required this.recap,
    required this.resending,
    required this.onEmail,
    required this.onShare,
  });

  final WeeklyRecap recap;
  final bool resending;
  final VoidCallback? onEmail;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        '${DateFormat('MMM d').format(recap.weekStart)} – ${DateFormat('MMM d').format(recap.weekEnd)}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            dateLabel,
            style: TextStyle(
              color: BrandColors.inkDim(context),
              fontSize: 12,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          _StatsRow(stats: recap.stats),
          const SizedBox(height: 18),
          _NarrativeCard(narrative: recap.narrative),
          const SizedBox(height: 18),
          if (recap.patterns.isNotEmpty) ...[
            _SectionLabel('PATTERNS WE NOTICED'),
            const SizedBox(height: 8),
            for (final p in recap.patterns) ...[
              _PatternCard(text: p),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 10),
          ],
          if (recap.gratitudeThemes.isNotEmpty) ...[
            _SectionLabel('YOUR GRATITUDE THEMES'),
            const SizedBox(height: 8),
            for (final g in recap.gratitudeThemes) ...[
              _GratitudeCard(text: g),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 10),
          ],
          _SectionLabel('LOOKING AHEAD'),
          const SizedBox(height: 8),
          _LookingAheadCard(text: recap.lookingAhead),
          const SizedBox(height: 24),
          Row(
            children: [
              if (onEmail != null) ...[
                Expanded(
                  child: _PrimaryButton(
                    label: resending ? 'Sending…' : 'Email this to me',
                    icon: Icons.mail_outline_rounded,
                    onTap: resending ? null : onEmail,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: onEmail == null ? 2 : 1,
                child: _SecondaryButton(
                  label: 'Share',
                  icon: Icons.ios_share_rounded,
                  onTap: onShare,
                ),
              ),
            ],
          ),
          if (recap.emailSent) ...[
            const SizedBox(height: 8),
            Center(
              child: Text(
                '✓ Emailed',
                style: TextStyle(
                  color: AppColors.blueAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4),
      child: Text(
        label,
        style: TextStyle(
          color: BrandColors.inkDim(context),
          fontSize: 10,
          letterSpacing: 1.8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final Map<String, dynamic> stats;

  int _int(String key) => (stats[key] as num?)?.toInt() ?? 0;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StatPill(label: 'Mood', value: '${_int('mood_entries')}'),
        const SizedBox(width: 10),
        _StatPill(label: 'Habits', value: '${_int('habits')}'),
        const SizedBox(width: 10),
        _StatPill(label: 'Routines', value: '${_int('routines')}'),
        const SizedBox(width: 10),
        _StatPill(
          label: 'Discipline',
          value: '${_int('discipline')}%',
          accent: AppColors.purpleLight,
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    this.accent,
  });
  final String label;
  final String value;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = accent ?? AppColors.pinkLight;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BrandColors.bgCard(context).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: c.withValues(alpha: 0.35),
          ),
          boxShadow: [
            BoxShadow(
              color: c.withValues(alpha: 0.20),
              blurRadius: 14,
              spreadRadius: -6,
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.instrumentSerif(
                color: BrandColors.ink(context),
                fontStyle: FontStyle.italic,
                fontSize: 22,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: BrandColors.inkDim(context),
                fontSize: 10,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NarrativeCard extends StatelessWidget {
  const _NarrativeCard({required this.narrative});
  final String narrative;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.purple.withValues(alpha: 0.22),
            AppColors.pink.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.purpleLight.withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.30),
            blurRadius: 26,
            spreadRadius: -6,
          ),
        ],
      ),
      child: Text(
        narrative,
        style: TextStyle(
          color: BrandColors.ink(context),
          fontSize: 15,
          height: 1.65,
        ),
      ),
    );
  }
}

class _PatternCard extends StatelessWidget {
  const _PatternCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 7, right: 10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.buttonGradient,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: BrandColors.inkSoft(context),
                fontSize: 14,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GratitudeCard extends StatelessWidget {
  const _GratitudeCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.pink.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.pinkLight.withValues(alpha: 0.40),
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.instrumentSerif(
          color: BrandColors.ink(context),
          fontStyle: FontStyle.italic,
          fontSize: 15,
          height: 1.4,
        ),
      ),
    );
  }
}

class _LookingAheadCard extends StatelessWidget {
  const _LookingAheadCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.purpleLight.withValues(alpha: 0.20),
            AppColors.blueAccent.withValues(alpha: 0.14),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.purpleLight.withValues(alpha: 0.45),
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.instrumentSerif(
          color: BrandColors.ink(context),
          fontStyle: FontStyle.italic,
          fontSize: 15,
          height: 1.5,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.6 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.pink.withValues(alpha: 0.40),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BrandColors.bgCard(context).withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.purple.withValues(alpha: 0.30),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: BrandColors.ink(context), size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: BrandColors.ink(context),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();
  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -80,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.purple.withValues(alpha: 0.30),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              left: -100,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.pink.withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
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
