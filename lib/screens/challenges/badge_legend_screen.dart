import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../widgets/challenges/rank_insignia.dart';
import '../../widgets/challenges/user_badge_chip.dart';
import '../../widgets/responsive_container.dart';

/// Full reference for the rank + prestige systems. Reachable from the
/// challenges list (info icon in the header) and the challenge detail
/// screen's overflow menu. Doubles as a motivation surface — users see
/// what they're climbing toward, with the actual art rendered next to
/// each name + earning criterion.
class BadgeLegendScreen extends StatelessWidget {
  const BadgeLegendScreen({super.key});

  static const List<String> _rankNames = [
    'Recruit',
    'Private',
    'Corporal',
    'Sergeant',
    'Lieutenant',
    'Captain',
    'Major',
    'Colonel',
    'General',
    'King/Queen',
    'Legend',
  ];

  static const List<String> _rankRules = [
    'Where everyone starts.',
    'One on-time check-in.',
    'Two on-time check-ins.',
    'Three on-time check-ins.',
    'Day four in a row.',
    'Day five — still here.',
    'Mid-march. Building.',
    'Past the halfway grind.',
    'Approaching legend.',
    'Within reach of the top.',
    'The summit of a challenge.',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 720,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              _TopBar(onBack: () => Navigator.of(context).maybePop()),
              const SizedBox(height: 4),
              Text(
                'The way up',
                style: GoogleFonts.bricolageGrotesque(
                  color: BrandColors.ink(context),
                  fontSize: 34,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Every challenge has two ladders: the rank you hold inside it, and the prestige you carry forever.',
                style: TextStyle(
                  color: BrandColors.inkSoft(context),
                  fontSize: 14,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 24),
              _RulesCard(),
              const SizedBox(height: 28),
              _SectionTitle('IN-CHALLENGE RANKS'),
              const SizedBox(height: 4),
              Text(
                'You start at Recruit when you join a challenge. Check in on time and you advance one tier each day, all the way to Legend. Miss a deadline and you stay — miss too many and you stop earning Profile Prestige at the end.',
                style: TextStyle(
                  color: BrandColors.inkSoft(context),
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < _rankNames.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RankRow(
                    rankIndex: i,
                    name: _rankNames[i],
                    rule: _rankRules[i],
                  ),
                ),
              const SizedBox(height: 24),
              _SectionTitle('PROFILE PRESTIGE'),
              const SizedBox(height: 4),
              Text(
                'Earn one of these by completing a challenge — finish it AND miss at most three on-time deadlines. Prestige is permanent and follows you across every challenge you ever join.',
                style: TextStyle(
                  color: BrandColors.inkSoft(context),
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 14),
              for (var i = 0; i < prestigeBadgeNames.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PrestigeRow(
                    name: prestigeBadgeNames[i],
                    threshold: prestigeBadgeThresholds[i],
                  ),
                ),
              const SizedBox(height: 18),
              Text(
                'Built to be earned. Worn forever.',
                textAlign: TextAlign.center,
                style: GoogleFonts.bricolageGrotesque(
                  color: BrandColors.inkDim(context),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack});
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: BrandColors.inkSoft(context)),
          onPressed: onBack,
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: BrandColors.inkDim(context),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.8,
      ),
    );
  }
}

class _RulesCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.purple.withValues(alpha: 0.25),
            AppColors.pink.withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.purpleLight.withValues(alpha: 0.42),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded,
                  color: AppColors.pinkLight, size: 16),
              const SizedBox(width: 6),
              Text(
                'HOW IT WORKS',
                style: TextStyle(
                  color: AppColors.pinkLight,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _bullet(context, 'Check in BEFORE the daily deadline to rank up.'),
          _bullet(context,
              'Late check-ins log the day — but no rank-up + a missed-rankup tally.'),
          _bullet(context,
              'Skipping a day entirely removes you from that challenge — no rejoining.'),
          _bullet(context,
              'Finish AND keep missed rank-ups under four to earn the next Prestige tier.'),
        ],
      ),
    );
  }

  Widget _bullet(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.pinkLight.withValues(alpha: 0.85),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: BrandColors.inkSoft(context),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rankIndex,
    required this.name,
    required this.rule,
  });
  final int rankIndex;
  final String name;
  final String rule;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          RankInsigniaArt(rankIndex: rankIndex, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.bricolageGrotesque(
                    color: BrandColors.ink(context),
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  rule,
                  style: TextStyle(
                    color: BrandColors.inkSoft(context),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text(
              '${rankIndex + 1}/11',
              style: TextStyle(
                color: BrandColors.inkDim(context),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrestigeRow extends StatelessWidget {
  const _PrestigeRow({required this.name, required this.threshold});
  final String name;
  final int threshold;

  @override
  Widget build(BuildContext context) {
    final accent = prestigeAccentFor(name);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.20),
            accent.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accent.withValues(alpha: 0.50),
        ),
      ),
      child: Row(
        children: [
          PrestigeBadgeArt(badge: name, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.bricolageGrotesque(
                    color: BrandColors.ink(context),
                    fontSize: 22,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Complete $threshold ${threshold == 1 ? "challenge" : "challenges"}.',
                  style: TextStyle(
                    color: BrandColors.inkSoft(context),
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
