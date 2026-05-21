import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../models/share_card_data.dart';
import '../theme/app_theme.dart';

/// The shareable card surface. Layout is in *design* pixels at exactly
/// the export resolution (1080×1080 or 1080×1920) — capture it via the
/// [boundaryKey] with `pixelRatio: 1.0` and you get the canonical PNG.
///
/// The preview screen wraps this in a FittedBox/Transform.scale so it
/// fits the user's actual screen.
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key,
    required this.data,
    required this.template,
    required this.format,
    required this.boundaryKey,
  });

  final ShareCardData data;
  final ShareCardTemplate template;
  final ShareCardFormat format;
  final GlobalKey boundaryKey;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: boundaryKey,
      child: SizedBox(
        width: format.width,
        height: format.height,
        child: _CardBody(
          data: data,
          template: template,
          format: format,
        ),
      ),
    );
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.data,
    required this.template,
    required this.format,
  });

  final ShareCardData data;
  final ShareCardTemplate template;
  final ShareCardFormat format;

  bool get _isStory => format == ShareCardFormat.story;

  // Story formats reserve ~250px top + bottom for the OS chrome that
  // Instagram / Snapchat overlay. Square formats are flush.
  double get _topInset => _isStory ? 240 : 80;
  double get _bottomInset => _isStory ? 240 : 80;
  double get _sideInset => _isStory ? 80 : 80;

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
          const _Glow(top: -240, right: -200, color: Color(0xFFA855F7), size: 760),
          const _Glow(bottom: -260, left: -220, color: Color(0xFFEC4899), size: 720),
          Padding(
            padding: EdgeInsets.fromLTRB(
              _sideInset, _topInset, _sideInset, _bottomInset,
            ),
            child: _Content(
              data: data,
              template: template,
              isStory: _isStory,
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({
    this.top,
    this.bottom,
    this.left,
    this.right,
    required this.color,
    required this.size,
  });
  final double? top, bottom, left, right;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: IgnorePointer(
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [color.withValues(alpha: 0.28), Colors.transparent],
              stops: const [0.0, 0.85],
            ),
          ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.data,
    required this.template,
    required this.isStory,
  });

  final ShareCardData data;
  final ShareCardTemplate template;
  final bool isStory;

  String get _dateRange {
    final fmt = DateFormat('MMM d');
    return '${fmt.format(data.weekStart)} – ${fmt.format(data.weekEnd)}';
  }

  String get _headline {
    switch (template) {
      case ShareCardTemplate.weekRecap:
        final n = data.userName?.trim();
        return (n == null || n.isEmpty) ? 'My week' : '${n.split(' ').first}’s week';
      case ShareCardTemplate.streakMilestone:
        return '${data.streakDays}-day streak';
      case ShareCardTemplate.identityProgress:
        return 'Becoming';
      case ShareCardTemplate.yearInReview:
        return 'My ${data.weekEnd.year}';
    }
  }

  String get _subheadline {
    switch (template) {
      case ShareCardTemplate.weekRecap:
        return 'A week of becoming.';
      case ShareCardTemplate.streakMilestone:
        return 'Day by day, on purpose.';
      case ShareCardTemplate.identityProgress:
        final shown = data.identities.take(2).join(' · ');
        return shown.isEmpty ? 'My identity in motion.' : shown;
      case ShareCardTemplate.yearInReview:
        return 'A year of becoming, on Mood8.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.max,
      children: [
        const _BrandRow(),
        SizedBox(height: isStory ? 90 : 36),
        _HeadlineBlock(headline: _headline, subheadline: _subheadline),
        SizedBox(height: isStory ? 70 : 40),
        _HeroSection(
          data: data,
          template: template,
          isStory: isStory,
        ),
        const Spacer(),
        _StatRow(data: data, template: template),
        SizedBox(height: isStory ? 48 : 36),
        _IdentityLine(identities: data.identities),
        const SizedBox(height: 28),
        _FooterRow(dateRange: _dateRange),
      ],
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.orbGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.pink.withValues(alpha: 0.45),
                    blurRadius: 30,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 18),
            Text(
              'Mood8',
              style: GoogleFonts.instrumentSerif(
                color: AppColors.ink,
                fontStyle: FontStyle.italic,
                fontSize: 46,
                height: 1.0,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeadlineBlock extends StatelessWidget {
  const _HeadlineBlock({required this.headline, required this.subheadline});
  final String headline;
  final String subheadline;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headline,
          style: GoogleFonts.instrumentSerif(
            color: AppColors.ink,
            fontStyle: FontStyle.italic,
            fontSize: 120,
            height: 1.0,
            foreground: Paint()
              ..shader = AppColors.primaryGradient.createShader(
                const Rect.fromLTWH(0, 0, 800, 200),
              ),
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        Text(
          subheadline,
          style: TextStyle(
            color: AppColors.inkSoft.withValues(alpha: 0.85),
            fontSize: 32,
            fontWeight: FontWeight.w500,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.data,
    required this.template,
    required this.isStory,
  });

  final ShareCardData data;
  final ShareCardTemplate template;
  final bool isStory;

  @override
  Widget build(BuildContext context) {
    // The orb visual + a streak-flame hero. Templates emphasize differently.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _StaticOrb(size: isStory ? 280 : 220),
        const SizedBox(width: 36),
        Expanded(
          child: _HeroStat(
            template: template,
            data: data,
          ),
        ),
      ],
    );
  }
}

class _StaticOrb extends StatelessWidget {
  const _StaticOrb({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.orbGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.purple.withValues(alpha: 0.55),
                  blurRadius: 60,
                  spreadRadius: 8,
                ),
                BoxShadow(
                  color: AppColors.pink.withValues(alpha: 0.40),
                  blurRadius: 90,
                  spreadRadius: -10,
                ),
              ],
            ),
          ),
          Positioned(
            top: size * 0.18,
            left: size * 0.20,
            child: Container(
              width: size * 0.30,
              height: size * 0.20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size),
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.55),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.template, required this.data});
  final ShareCardTemplate template;
  final ShareCardData data;

  @override
  Widget build(BuildContext context) {
    if (template == ShareCardTemplate.identityProgress) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroNumber(
            value: '${data.disciplineScore}',
            unit: '/100',
            label: 'Discipline',
          ),
        ],
      );
    }
    if (template == ShareCardTemplate.yearInReview) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeroNumber(
            value: '${data.habitsCompleted}',
            unit: '',
            label: 'Habits completed',
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔥',
              style: TextStyle(
                fontSize: 110,
                height: 1.0,
                shadows: [
                  Shadow(
                    color: AppColors.pink.withValues(alpha: 0.6),
                    blurRadius: 40,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _HeroNumber(
              value: '${data.streakDays}',
              unit: data.streakDays == 1 ? ' day' : ' days',
              label: 'Current streak',
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroNumber extends StatelessWidget {
  const _HeroNumber({
    required this.value,
    required this.unit,
    required this.label,
  });
  final String value;
  final String unit;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: GoogleFonts.instrumentSerif(
                color: AppColors.ink,
                fontStyle: FontStyle.italic,
                fontSize: 140,
                height: 1.0,
                foreground: Paint()
                  ..shader = AppColors.buttonGradient.createShader(
                    const Rect.fromLTWH(0, 0, 600, 200),
                  ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: Text(
                unit,
                style: TextStyle(
                  color: AppColors.inkSoft.withValues(alpha: 0.85),
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: AppColors.inkDim,
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.4,
          ),
        ),
      ],
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.data, required this.template});
  final ShareCardData data;
  final ShareCardTemplate template;

  @override
  Widget build(BuildContext context) {
    final stats = <(String, String)>[];
    if (template == ShareCardTemplate.yearInReview) {
      // Year card already shows habits in the hero; secondary tiles
      // surface the rest of the year-scale stats.
      stats.add(('${data.streakDays}', 'Longest streak'));
      if (data.avgMood != null) {
        stats.add((data.avgMood!.toStringAsFixed(1), 'Avg mood'));
      }
      stats.add(('${data.disciplineScore}', 'Days active'));
    } else {
      // Streak template doesn't repeat the streak in the secondary row.
      if (template != ShareCardTemplate.streakMilestone) {
        stats.add(('${data.streakDays}', 'Streak'));
      } else {
        stats.add(('${data.disciplineScore}%', 'Discipline'));
      }
      if (data.avgMood != null) {
        stats.add((data.avgMood!.toStringAsFixed(1), 'Avg mood'));
      }
      stats.add(('${data.habitsCompleted}', 'Habits this week'));
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final s in stats)
          Expanded(child: _StatTile(value: s.$1, label: s.$2)),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1F1338).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.28),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.instrumentSerif(
              color: AppColors.ink,
              fontStyle: FontStyle.italic,
              fontSize: 56,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: AppColors.inkDim,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

class _IdentityLine extends StatelessWidget {
  const _IdentityLine({required this.identities});
  final List<String> identities;

  @override
  Widget build(BuildContext context) {
    final shown = identities.take(3).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    final joined = shown.map((i) => i).join(' · ');
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            AppColors.purple.withValues(alpha: 0.30),
            AppColors.pink.withValues(alpha: 0.22),
          ],
        ),
        border: Border.all(
          color: AppColors.pinkLight.withValues(alpha: 0.40),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Becoming:',
            style: TextStyle(
              color: AppColors.inkSoft,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              joined,
              style: GoogleFonts.instrumentSerif(
                color: AppColors.ink,
                fontStyle: FontStyle.italic,
                fontSize: 34,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FooterRow extends StatelessWidget {
  const _FooterRow({required this.dateRange});
  final String dateRange;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          dateRange,
          style: TextStyle(
            color: AppColors.inkDim,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        Text(
          'mood8.app',
          style: GoogleFonts.instrumentSerif(
            color: AppColors.pinkLight,
            fontStyle: FontStyle.italic,
            fontSize: 32,
          ),
        ),
      ],
    );
  }
}
