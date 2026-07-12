import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/challenge.dart';
import '../../services/challenge_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/challenges/network_avatar.dart';
import '../../widgets/challenges/user_badge_chip.dart';
import '../../widgets/responsive_container.dart';
import '../profile/public_profile_screen.dart';

/// Global Challenge Ranking screen. Owns:
///   • Your own tier card at the top (rank #, score, tier chip,
///     next-tier hint).
///   • Global top-100 list below, with special treatment for the
///     top 3.
///   • Pull-to-refresh.
/// All numbers are server-authoritative — the client never writes
/// score. See challenge_scoring.py in the backend.
class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen> {
  Leaderboard? _board;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final board = await ChallengeService().leaderboard();
      if (!mounted) return;
      setState(() {
        _board = board;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = "Couldn't load the leaderboard. Try again.";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: BrandColors.inkSoft(context)),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Ranking',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 640,
          child: RefreshIndicator(
            onRefresh: _load,
            color: AppColors.pinkLight,
            backgroundColor: BrandColors.bgCard(context),
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _board == null) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation(Color(0xFFEC4899)),
          ),
        ),
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 80),
          Center(
            child: Text(_error!,
                style: TextStyle(color: BrandColors.inkSoft(context))),
          ),
        ],
      );
    }
    final board = _board!;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _MyRankCard(me: board.me),
        const SizedBox(height: 20),
        _TierLadderStrip(currentTier: board.me.tier),
        const SizedBox(height: 24),
        if (board.top.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                Icon(Icons.emoji_events_outlined,
                    color: BrandColors.inkFaint(context), size: 48),
                const SizedBox(height: 12),
                Text(
                  'No public scores yet.',
                  style: TextStyle(
                    color: BrandColors.inkSoft(context),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Finish a challenge and you'll be first on the board.",
                  style: TextStyle(
                    color: BrandColors.inkDim(context),
                    fontSize: 12.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else ...[
          _SectionLabel('TOP 100'),
          const SizedBox(height: 10),
          for (final entry in board.top)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _LeaderboardRow(
                entry: entry,
                highlightAsMe: entry.userId ==
                    _findMyUserIdFrom(board),
              ),
            ),
        ],
      ],
    );
  }

  /// The leaderboard payload doesn't carry the requester's user_id
  /// directly (the `me` block has position/score/tier only) — but
  /// when they're in top-100 we still want to highlight their row.
  /// We detect it by matching the me.position against the top rows'
  /// positions. Position is 1-indexed, top-N is stable-ordered, so
  /// a position hit is unique.
  int? _findMyUserIdFrom(Leaderboard board) {
    if (!board.me.isTop100) return null;
    for (final row in board.top) {
      if (row.position == board.me.position) return row.userId;
    }
    return null;
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────

class _MyRankCard extends StatelessWidget {
  const _MyRankCard({required this.me});
  final LeaderboardMe me;

  @override
  Widget build(BuildContext context) {
    final tierC = tierColor(me.tier);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tierC.withValues(alpha: 0.25),
            AppColors.pink.withValues(alpha: 0.18),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: tierC.withValues(alpha: 0.55),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: tierC.withValues(alpha: 0.28),
            blurRadius: 22,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'YOUR RANK',
                style: TextStyle(
                  color: BrandColors.inkDim(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.6,
                ),
              ),
              const Spacer(),
              _TierChip(tier: me.tier),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '#${me.position}',
                style: GoogleFonts.bricolageGrotesque(
                  color: BrandColors.ink(context),
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${me.score} pts',
                style: GoogleFonts.bricolageGrotesque(
                  color: tierC,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (me.nextTierName != null && me.nextTierPointsNeeded != null) ...[
            const SizedBox(height: 12),
            _NextTierProgress(
              nextTierName: me.nextTierName!,
              pointsNeeded: me.nextTierPointsNeeded!,
              currentScore: me.score,
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              'Top of the ladder. Keep going.',
              style: TextStyle(
                color: BrandColors.inkSoft(context),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (me.hiddenFromLeaderboard) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: BrandColors.bgDeep(context).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: BrandColors.inkFaint(context).withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility_off_outlined,
                      color: BrandColors.inkDim(context), size: 13),
                  const SizedBox(width: 6),
                  Text(
                    "Hidden from public leaderboard",
                    style: TextStyle(
                      color: BrandColors.inkSoft(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NextTierProgress extends StatelessWidget {
  const _NextTierProgress({
    required this.nextTierName,
    required this.pointsNeeded,
    required this.currentScore,
  });
  final String nextTierName;
  final int pointsNeeded;
  final int currentScore;

  @override
  Widget build(BuildContext context) {
    final target = currentScore + pointsNeeded;
    final progress = target == 0 ? 0.0 : (currentScore / target).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$pointsNeeded pts to $nextTierName',
          style: TextStyle(
            color: BrandColors.inkSoft(context),
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor:
                BrandColors.bgDeep(context).withValues(alpha: 0.5),
            valueColor: AlwaysStoppedAnimation(tierColor(nextTierName)),
          ),
        ),
      ],
    );
  }
}

/// Compact horizontal ladder: [Bronze · Silver · Gold · Plat · Diamond
/// · Legend] with the current tier highlighted. Gives context to the
/// "N pts to Gold" line above.
class _TierLadderStrip extends StatelessWidget {
  const _TierLadderStrip({required this.currentTier});
  final String currentTier;

  static const _ladder = [
    ('Bronze', 'Br'),
    ('Silver', 'Si'),
    ('Gold', 'Go'),
    ('Platinum', 'Pt'),
    ('Diamond', 'Di'),
    ('Legend League', 'Lg'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < _ladder.length; i++) ...[
            _TierPip(
              name: _ladder[i].$1,
              short: _ladder[i].$2,
              active: _ladder[i].$1 == currentTier,
            ),
            if (i < _ladder.length - 1)
              Container(
                width: 14,
                height: 1.5,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                color: BrandColors.inkFaint(context).withValues(alpha: 0.4),
              ),
          ],
        ],
      ),
    );
  }
}

class _TierPip extends StatelessWidget {
  const _TierPip({
    required this.name,
    required this.short,
    required this.active,
  });
  final String name;
  final String short;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = tierColor(name);
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? c : BrandColors.bgCard(context),
            border: Border.all(
              color: active ? c : c.withValues(alpha: 0.45),
              width: active ? 2 : 1,
            ),
            boxShadow: active
                ? [BoxShadow(color: c.withValues(alpha: 0.55), blurRadius: 10)]
                : null,
          ),
          child: Text(
            short,
            style: TextStyle(
              color: active ? Colors.white : c,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: TextStyle(
            color: active ? c : BrandColors.inkDim(context),
            fontSize: 9,
            fontWeight: active ? FontWeight.w800 : FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }
}

class _TierChip extends StatelessWidget {
  const _TierChip({required this.tier});
  final String tier;

  @override
  Widget build(BuildContext context) {
    final c = tierColor(tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.60), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_rounded, color: c, size: 14),
          const SizedBox(width: 4),
          Text(
            tier,
            style: TextStyle(
              color: c,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;
  @override
  Widget build(BuildContext context) => Text(
        label,
        style: TextStyle(
          color: BrandColors.inkDim(context),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.8,
        ),
      );
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({
    required this.entry,
    required this.highlightAsMe,
  });
  final LeaderboardEntry entry;
  final bool highlightAsMe;

  @override
  Widget build(BuildContext context) {
    // Top-3 get a medal treatment: gold/silver/bronze border + medal
    // icon in place of the plain number.
    final isTop3 = entry.position <= 3;
    final medalColor = switch (entry.position) {
      1 => const Color(0xFFFFD700),
      2 => const Color(0xFFC0C0C0),
      3 => const Color(0xFFCD7F32),
      _ => BrandColors.inkFaint(context),
    };
    final tierC = tierColor(entry.tier);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticService().light();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PublicProfileScreen(
                userId: entry.userId,
                initialName: entry.name,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
            color: highlightAsMe
                ? tierC.withValues(alpha: 0.14)
                : BrandColors.bgCard(context).withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: highlightAsMe
                  ? tierC.withValues(alpha: 0.60)
                  : isTop3
                      ? medalColor.withValues(alpha: 0.60)
                      : AppColors.purple.withValues(alpha: 0.22),
              width: (isTop3 || highlightAsMe) ? 1.6 : 1,
            ),
            boxShadow: isTop3
                ? [
                    BoxShadow(
                      color: medalColor.withValues(alpha: 0.30),
                      blurRadius: 14,
                      spreadRadius: -4,
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Position / medal.
              SizedBox(
                width: 36,
                child: isTop3
                    ? Icon(
                        Icons.emoji_events_rounded,
                        color: medalColor,
                        size: 26,
                      )
                    : Center(
                        child: Text(
                          '${entry.position}',
                          style: TextStyle(
                            color: BrandColors.inkSoft(context),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              NetworkAvatar(
                name: entry.name,
                avatarUrl: absoluteAvatarUrl(entry.avatarUrl),
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            entry.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.bricolageGrotesque(
                              color: BrandColors.ink(context),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (highlightAsMe) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: tierC.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'YOU',
                              style: TextStyle(
                                color: tierC,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _TierChip(tier: entry.tier),
                        const SizedBox(width: 6),
                        if (entry.profileBadge != null)
                          UserBadgeChip(badge: entry.profileBadge!),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${entry.challengeScore}',
                style: GoogleFonts.bricolageGrotesque(
                  color: tierC,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
