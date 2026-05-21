import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/share_card_data.dart';
import '../models/year_in_review.dart';
import '../services/haptic_service.dart';
import '../services/year_in_review_service.dart';
import '../theme/app_theme.dart';
import 'share_progress_screen.dart';

/// Full-screen, swipeable, story-style Year-in-Review experience.
/// Auto-advances every ~5s, tap-right for next, tap-left for previous,
/// long-press to pause. Story-style progress bars at the top.
class YearInReviewScreen extends StatefulWidget {
  const YearInReviewScreen({super.key, this.year});

  /// Calendar year to recap. Defaults to the previous full calendar
  /// year in January (so the December experience is the just-finished
  /// year), otherwise the current year.
  final int? year;

  @override
  State<YearInReviewScreen> createState() => _YearInReviewScreenState();
}

class _YearInReviewScreenState extends State<YearInReviewScreen>
    with TickerProviderStateMixin {
  late int _year;
  YearInReviewData? _data;
  bool _loading = true;
  int _index = 0;
  late AnimationController _progress;
  bool _paused = false;

  static const Duration _cardDuration = Duration(seconds: 6);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = widget.year ??
        (now.month == 1 ? now.year - 1 : now.year);
    _progress = AnimationController(
      vsync: this,
      duration: _cardDuration,
    )..addStatusListener(_onStatus);
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await YearInReviewService().generateForYear(_year);
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
      if (d.hasMinimumData) {
        _progress.forward(from: 0);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _onStatus(AnimationStatus s) {
    if (s == AnimationStatus.completed && mounted) {
      _next();
    }
  }

  List<_YearCard> get _cards {
    final d = _data;
    if (d == null) return const [];
    return <_YearCard>[
      _YearCard.intro,
      _YearCard.activity,
      _YearCard.streak,
      _YearCard.habits,
      _YearCard.mood,
      _YearCard.bestMonth,
      _YearCard.words,
      _YearCard.badges,
      _YearCard.identity,
      _YearCard.theme,
      _YearCard.outro,
    ];
  }

  void _next() {
    if (_index >= _cards.length - 1) {
      Navigator.of(context).maybePop();
      return;
    }
    HapticService().selection();
    setState(() => _index += 1);
    _progress.forward(from: 0);
  }

  void _prev() {
    if (_index <= 0) {
      _progress.forward(from: 0);
      return;
    }
    HapticService().selection();
    setState(() => _index -= 1);
    _progress.forward(from: 0);
  }

  void _onTap(TapUpDetails details) {
    final w = MediaQuery.of(context).size.width;
    if (details.globalPosition.dx < w / 3) {
      _prev();
    } else {
      _next();
    }
  }

  void _onLongPress() {
    setState(() => _paused = true);
    _progress.stop();
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    setState(() => _paused = false);
    _progress.forward();
  }

  void _share() {
    HapticService().light();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const ShareProgressScreen(
          initialTemplate: ShareCardTemplate.yearInReview,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _YirScaffold(child: Center(child: _Spinner()));
    }
    final d = _data;
    if (d == null) {
      return _YirScaffold(
        child: _EmptyState(
          onClose: () => Navigator.of(context).maybePop(),
        ),
      );
    }
    if (!d.hasMinimumData) {
      return _YirScaffold(
        child: _EmptyState(
          onClose: () => Navigator.of(context).maybePop(),
          subtitle:
              'Your Year in Review will be ready as you build your story — keep checking in, and come back soon.',
        ),
      );
    }
    final card = _cards[_index];
    return _YirScaffold(
      child: GestureDetector(
        onTapUp: _onTap,
        onLongPress: _onLongPress,
        onLongPressEnd: _onLongPressEnd,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          children: [
            Positioned.fill(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: KeyedSubtree(
                  key: ValueKey(_index),
                  child: _CardBody(card: card, data: d, onShare: _share),
                ),
              ),
            ),
            // Progress bars + close button live above everything.
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ProgressBars(
                      count: _cards.length,
                      active: _index,
                      progress: _progress,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(
                          '${d.year}  ·  YEAR IN REVIEW',
                          style: TextStyle(
                            color: BrandColors.inkSoft(context),
                            fontSize: 11,
                            letterSpacing: 2.0,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        if (_paused)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Text(
                              'PAUSED',
                              style: TextStyle(
                                color: AppColors.pinkLight,
                                fontSize: 10,
                                letterSpacing: 1.8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        IconButton(
                          icon: Icon(
                            Icons.close_rounded,
                            color: BrandColors.inkSoft(context),
                          ),
                          onPressed: () =>
                              Navigator.of(context).maybePop(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _YearCard {
  intro,
  activity,
  streak,
  habits,
  mood,
  bestMonth,
  words,
  badges,
  identity,
  theme,
  outro,
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.card,
    required this.data,
    required this.onShare,
  });
  final _YearCard card;
  final YearInReviewData data;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    switch (card) {
      case _YearCard.intro:
        return _IntroCard(data: data);
      case _YearCard.activity:
        return _BigStatCard(
          eyebrow: 'YOU SHOWED UP',
          value: '${data.daysActive}',
          unit: 'days',
          tagline:
              'On ${data.daysActive} days, you opened Mood8 and chose presence.',
        );
      case _YearCard.streak:
        return _BigStatCard(
          eyebrow: 'YOUR LONGEST STREAK',
          value: '${data.longestStreakDays}',
          unit: data.longestStreakDays == 1 ? 'day' : 'days',
          tagline: data.longestStreakHabit != null
              ? '“${data.longestStreakHabit}” — kept alive, day after day.'
              : 'Consistency, built one quiet day at a time.',
          icon: '🔥',
        );
      case _YearCard.habits:
        return _BigStatCard(
          eyebrow: 'HABITS COMPLETED',
          value: '${data.totalHabitsCompleted}',
          unit: '',
          tagline: 'Every check, a quiet vote for who you are becoming.',
        );
      case _YearCard.mood:
        return _MoodCard(data: data);
      case _YearCard.bestMonth:
        return _BestMonthCard(data: data);
      case _YearCard.words:
        return _WordsCard(data: data);
      case _YearCard.badges:
        return _BigStatCard(
          eyebrow: 'BADGES EARNED',
          value: '${data.badgesEarned}',
          unit: '',
          tagline: data.badgesEarned == 0
              ? 'Your collection starts now.'
              : 'Moments worth marking. You marked them.',
          icon: '🏅',
        );
      case _YearCard.identity:
        return _IdentityCard(data: data);
      case _YearCard.theme:
        return _ThemeCard(data: data);
      case _YearCard.outro:
        return _OutroCard(data: data, onShare: onShare);
    }
  }
}

// ── Scaffold + background ──────────────────────────────────────────────

class _YirScaffold extends StatelessWidget {
  const _YirScaffold({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0612),
      body: Stack(
        children: [
          const Positioned.fill(child: _BackgroundGlow()),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A0612),
            Color(0xFF110821),
            Color(0xFF1F1338),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -160, right: -120,
            child: _Glow(color: AppColors.purple, size: 460),
          ),
          Positioned(
            bottom: -200, left: -160,
            child: _Glow(color: AppColors.pink, size: 520),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.30),
              Colors.transparent,
            ],
            stops: const [0.0, 0.85],
          ),
        ),
      ),
    );
  }
}

// ── Progress bars ──────────────────────────────────────────────────────

class _ProgressBars extends StatelessWidget {
  const _ProgressBars({
    required this.count,
    required this.active,
    required this.progress,
  });
  final int count;
  final int active;
  final AnimationController progress;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (_, _) {
        return Row(
          children: [
            for (var i = 0; i < count; i++) ...[
              Expanded(
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: i < active
                        ? 1.0
                        : i == active
                            ? progress.value
                            : 0.0,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: AppColors.buttonGradient,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              if (i != count - 1) const SizedBox(width: 4),
            ],
          ],
        );
      },
    );
  }
}

// ── Cards ──────────────────────────────────────────────────────────────

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.data});
  final YearInReviewData data;

  @override
  Widget build(BuildContext context) {
    return _CardScaffold(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Your',
            textAlign: TextAlign.center,
            style: GoogleFonts.instrumentSerif(
              color: AppColors.ink,
              fontSize: 64,
              height: 1.0,
            ),
          )
              .animate()
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
          Text(
            '${data.year}',
            textAlign: TextAlign.center,
            style: GoogleFonts.instrumentSerif(
              color: AppColors.ink,
              fontStyle: FontStyle.italic,
              fontSize: 132,
              height: 1.0,
              foreground: Paint()
                ..shader = AppColors.primaryGradient
                    .createShader(const Rect.fromLTWH(0, 0, 400, 180)),
            ),
          )
              .animate(delay: 250.ms)
              .fadeIn(duration: 700.ms)
              .scaleXY(begin: 0.82, end: 1.0, curve: Curves.easeOutCubic),
          const SizedBox(height: 8),
          Text(
            'on Mood8',
            textAlign: TextAlign.center,
            style: GoogleFonts.instrumentSerif(
              color: AppColors.inkSoft,
              fontStyle: FontStyle.italic,
              fontSize: 36,
            ),
          ).animate(delay: 600.ms).fadeIn(duration: 600.ms),
          const SizedBox(height: 36),
          Text(
            'Let’s look back — gently.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.inkSoft.withValues(alpha: 0.85),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ).animate(delay: 1100.ms).fadeIn(duration: 600.ms),
        ],
      ),
    );
  }
}

class _BigStatCard extends StatelessWidget {
  const _BigStatCard({
    required this.eyebrow,
    required this.value,
    required this.unit,
    required this.tagline,
    this.icon,
  });
  final String eyebrow;
  final String value;
  final String unit;
  final String tagline;
  final String? icon;

  @override
  Widget build(BuildContext context) {
    return _CardScaffold(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Text(
              icon!,
              style: TextStyle(
                fontSize: 90,
                shadows: [
                  Shadow(
                    color: AppColors.pink.withValues(alpha: 0.55),
                    blurRadius: 40,
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(duration: 500.ms)
                .scaleXY(begin: 0.6, end: 1.0, curve: Curves.easeOutBack),
          if (icon != null) const SizedBox(height: 14),
          Text(
            eyebrow,
            style: TextStyle(
              color: AppColors.inkDim,
              fontSize: 12,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w800,
            ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _CountUpText(
                end: int.tryParse(value) ?? 0,
                builder: (n) => Text(
                  '$n',
                  style: GoogleFonts.instrumentSerif(
                    color: AppColors.ink,
                    fontStyle: FontStyle.italic,
                    fontSize: 140,
                    height: 0.95,
                    foreground: Paint()
                      ..shader = AppColors.buttonGradient
                          .createShader(const Rect.fromLTWH(0, 0, 600, 200)),
                  ),
                ),
              ),
              if (unit.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 10, bottom: 22),
                  child: Text(
                    unit,
                    style: TextStyle(
                      color: AppColors.inkSoft.withValues(alpha: 0.85),
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                    ),
                  ).animate(delay: 800.ms).fadeIn(duration: 500.ms),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            tagline,
            style: GoogleFonts.instrumentSerif(
              color: AppColors.inkSoft,
              fontStyle: FontStyle.italic,
              fontSize: 22,
              height: 1.35,
            ),
          ).animate(delay: 1000.ms).fadeIn(duration: 700.ms),
        ],
      ),
    );
  }
}

/// Counts up to [end] over ~1s, calling [builder] on each frame.
class _CountUpText extends StatelessWidget {
  const _CountUpText({required this.end, required this.builder});
  final int end;
  final Widget Function(int) builder;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: end),
      duration: const Duration(milliseconds: 1100),
      curve: Curves.easeOutCubic,
      builder: (_, value, _) => builder(value),
    );
  }
}

class _MoodCard extends StatelessWidget {
  const _MoodCard({required this.data});
  final YearInReviewData data;

  @override
  Widget build(BuildContext context) {
    final avg = data.avgMood?.toStringAsFixed(1) ?? '—';
    return _CardScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'YOUR MOOD JOURNEY',
            style: TextStyle(
              color: AppColors.inkDim,
              fontSize: 12,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w800,
            ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                avg,
                style: GoogleFonts.instrumentSerif(
                  color: AppColors.ink,
                  fontStyle: FontStyle.italic,
                  fontSize: 120,
                  height: 0.95,
                  foreground: Paint()
                    ..shader = AppColors.buttonGradient
                        .createShader(const Rect.fromLTWH(0, 0, 600, 200)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 22),
                child: Text(
                  '/10',
                  style: TextStyle(
                    color: AppColors.inkSoft.withValues(alpha: 0.85),
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 600.ms),
          const SizedBox(height: 8),
          Text(
            'average across ${data.totalCheckIns} check-ins',
            style: TextStyle(
              color: AppColors.inkSoft.withValues(alpha: 0.75),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 120,
            child: CustomPaint(
              size: const Size.fromHeight(120),
              painter: _MoodWavePainter(monthly: data.moodByMonth),
            ),
          ).animate(delay: 600.ms).fadeIn(duration: 800.ms),
          const SizedBox(height: 14),
          Text(
            data.highestMoodDay != null
                ? 'Your brightest day was ${DateFormat('MMMM d').format(data.highestMoodDay!)}.'
                : 'You wrote your inner weather, all year.',
            style: GoogleFonts.instrumentSerif(
              color: AppColors.inkSoft,
              fontStyle: FontStyle.italic,
              fontSize: 20,
              height: 1.35,
            ),
          ).animate(delay: 1200.ms).fadeIn(duration: 600.ms),
        ],
      ),
    );
  }
}

class _MoodWavePainter extends CustomPainter {
  _MoodWavePainter({required this.monthly});
  final Map<int, double> monthly;

  @override
  void paint(Canvas canvas, Size size) {
    if (monthly.isEmpty) return;
    final months = List<int>.generate(12, (i) => i + 1);
    final points = <Offset>[];
    final stepX = size.width / 11;
    for (var i = 0; i < months.length; i++) {
      final mood = monthly[months[i]];
      if (mood == null) continue;
      final x = i * stepX;
      final y = size.height - (mood / 10.0) * size.height;
      points.add(Offset(x, y));
    }
    if (points.length < 2) return;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final p = points[i];
      final cx = (prev.dx + p.dx) / 2;
      path.cubicTo(cx, prev.dy, cx, p.dy, p.dx, p.dy);
    }
    final stroke = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFA855F7), Color(0xFFEC4899), Color(0xFFF472B6)],
      ).createShader(Offset.zero & size)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, stroke);
    final dot = Paint()..color = const Color(0xFFF472B6);
    for (final p in points) {
      canvas.drawCircle(p, 4, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _MoodWavePainter oldDelegate) =>
      oldDelegate.monthly != monthly;
}

class _BestMonthCard extends StatelessWidget {
  const _BestMonthCard({required this.data});
  final YearInReviewData data;

  @override
  Widget build(BuildContext context) {
    final name = data.monthName;
    return _CardScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'YOUR BEST MONTH',
            style: TextStyle(
              color: AppColors.inkDim,
              fontSize: 12,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w800,
            ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 10),
          Text(
            name,
            style: GoogleFonts.instrumentSerif(
              color: AppColors.ink,
              fontStyle: FontStyle.italic,
              fontSize: 96,
              height: 0.95,
              foreground: Paint()
                ..shader = AppColors.primaryGradient
                    .createShader(const Rect.fromLTWH(0, 0, 600, 160)),
            ),
          )
              .animate(delay: 250.ms)
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 14),
          Text(
            '${data.bestMonthScore} days of presence — your most engaged month.',
            style: GoogleFonts.instrumentSerif(
              color: AppColors.inkSoft,
              fontStyle: FontStyle.italic,
              fontSize: 22,
              height: 1.35,
            ),
          ).animate(delay: 800.ms).fadeIn(duration: 700.ms),
        ],
      ),
    );
  }
}

class _WordsCard extends StatelessWidget {
  const _WordsCard({required this.data});
  final YearInReviewData data;

  @override
  Widget build(BuildContext context) {
    return _CardScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'WORDS YOU WROTE',
            style: TextStyle(
              color: AppColors.inkDim,
              fontSize: 12,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w800,
            ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 22),
          _WordRow(
            value: '${data.totalReflections}',
            label: 'Reflections',
            delay: 200.ms,
          ),
          const SizedBox(height: 14),
          _WordRow(
            value: '${data.totalGratitudes}',
            label: 'Gratitudes',
            delay: 500.ms,
          ),
          const SizedBox(height: 30),
          Text(
            'You wrote your way through this year.',
            style: GoogleFonts.instrumentSerif(
              color: AppColors.inkSoft,
              fontStyle: FontStyle.italic,
              fontSize: 22,
              height: 1.35,
            ),
          ).animate(delay: 900.ms).fadeIn(duration: 700.ms),
        ],
      ),
    );
  }
}

class _WordRow extends StatelessWidget {
  const _WordRow({
    required this.value,
    required this.label,
    required this.delay,
  });
  final String value;
  final String label;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: GoogleFonts.instrumentSerif(
            color: AppColors.ink,
            fontStyle: FontStyle.italic,
            fontSize: 78,
            height: 1.0,
            foreground: Paint()
              ..shader = AppColors.buttonGradient
                  .createShader(const Rect.fromLTWH(0, 0, 400, 100)),
          ),
        ),
        const SizedBox(width: 14),
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Text(
            label,
            style: TextStyle(
              color: AppColors.inkSoft.withValues(alpha: 0.85),
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ).animate(delay: delay).fadeIn(duration: 600.ms);
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.data});
  final YearInReviewData data;

  @override
  Widget build(BuildContext context) {
    return _CardScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'WHO YOU’RE BECOMING',
            style: TextStyle(
              color: AppColors.inkDim,
              fontSize: 12,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w800,
            ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 14),
          if (data.identities.isEmpty)
            Text(
              'Your identity is forming — and you’re paying attention.',
              style: GoogleFonts.instrumentSerif(
                color: AppColors.ink,
                fontStyle: FontStyle.italic,
                fontSize: 40,
                height: 1.15,
              ),
            ).animate(delay: 200.ms).fadeIn(duration: 700.ms)
          else
            ...List.generate(data.identities.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  data.identities[i],
                  style: GoogleFonts.instrumentSerif(
                    color: AppColors.ink,
                    fontStyle: FontStyle.italic,
                    fontSize: 64,
                    height: 1.05,
                    foreground: Paint()
                      ..shader = AppColors.primaryGradient.createShader(
                        const Rect.fromLTWH(0, 0, 600, 120),
                      ),
                  ),
                )
                    .animate(delay: (300 + i * 250).ms)
                    .fadeIn(duration: 700.ms)
                    .slideX(begin: -0.1, end: 0, curve: Curves.easeOutCubic),
              );
            }),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({required this.data});
  final YearInReviewData data;

  @override
  Widget build(BuildContext context) {
    return _CardScaffold(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'THIS YEAR YOU WERE…',
            style: TextStyle(
              color: AppColors.inkDim,
              fontSize: 12,
              letterSpacing: 2.4,
              fontWeight: FontWeight.w800,
            ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 22),
          Text(
            data.theme,
            style: GoogleFonts.instrumentSerif(
              color: AppColors.ink,
              fontStyle: FontStyle.italic,
              fontSize: 72,
              height: 1.05,
              foreground: Paint()
                ..shader = AppColors.primaryGradient.createShader(
                  const Rect.fromLTWH(0, 0, 800, 140),
                ),
            ),
          )
              .animate(delay: 300.ms)
              .fadeIn(duration: 800.ms)
              .slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 18),
          Text(
            data.themeDescription,
            style: GoogleFonts.instrumentSerif(
              color: AppColors.inkSoft,
              fontStyle: FontStyle.italic,
              fontSize: 22,
              height: 1.4,
            ),
          ).animate(delay: 1000.ms).fadeIn(duration: 700.ms),
        ],
      ),
    );
  }
}

class _OutroCard extends StatelessWidget {
  const _OutroCard({required this.data, required this.onShare});
  final YearInReviewData data;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    return _CardScaffold(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Here’s to',
            textAlign: TextAlign.center,
            style: GoogleFonts.instrumentSerif(
              color: AppColors.ink,
              fontSize: 56,
              height: 1.0,
            ),
          ).animate().fadeIn(duration: 600.ms),
          const SizedBox(height: 6),
          Text(
            '${data.year + 1}',
            textAlign: TextAlign.center,
            style: GoogleFonts.instrumentSerif(
              color: AppColors.ink,
              fontStyle: FontStyle.italic,
              fontSize: 132,
              height: 1.0,
              foreground: Paint()
                ..shader = AppColors.primaryGradient.createShader(
                  const Rect.fromLTWH(0, 0, 400, 180),
                ),
            ),
          )
              .animate(delay: 300.ms)
              .fadeIn(duration: 800.ms)
              .scaleXY(begin: 0.85, end: 1.0, curve: Curves.easeOutCubic),
          const SizedBox(height: 26),
          Text(
            'May this year be a better year than the last.',
            textAlign: TextAlign.center,
            style: GoogleFonts.instrumentSerif(
              color: AppColors.inkSoft,
              fontStyle: FontStyle.italic,
              fontSize: 20,
              height: 1.4,
            ),
          ).animate(delay: 900.ms).fadeIn(duration: 700.ms),
          const SizedBox(height: 36),
          _ShareButton(onTap: onShare)
              .animate(delay: 1300.ms)
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppColors.buttonGradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.pink.withValues(alpha: 0.55),
              blurRadius: 26,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.ios_share_rounded,
                color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              'Share my year',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardScaffold extends StatelessWidget {
  const _CardScaffold({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 88, 28, 56),
        child: child,
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 36,
      height: 36,
      child: CircularProgressIndicator(
        strokeWidth: 2.4,
        valueColor: AlwaysStoppedAnimation(Color(0xFFEC4899)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onClose,
    this.subtitle =
        'Your Year in Review will be ready as you build your story — keep checking in.',
  });
  final VoidCallback onClose;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: onClose,
                icon: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFFE9D5FF),
                ),
              ),
            ),
            const Spacer(),
            Text(
              'Not yet — but soon.',
              textAlign: TextAlign.center,
              style: GoogleFonts.instrumentSerif(
                color: AppColors.ink,
                fontStyle: FontStyle.italic,
                fontSize: 38,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.inkSoft.withValues(alpha: 0.85),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const Spacer(flex: 2),
          ],
        ),
      ),
    );
  }
}
