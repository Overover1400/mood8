import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/challenge.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/challenges/network_avatar.dart';
import '../../widgets/challenges/rank_insignia.dart';
import '../../widgets/responsive_container.dart';
import '../profile/public_profile_screen.dart';

/// Full-screen participants view — opened from the detail screen's
/// "Did it today" avatar row and from the participants strip. Tabs
/// segment by participant status. Each row shows avatar, name, rank
/// insignia, a "checked in today" marker where relevant, and taps
/// through to the participant's public profile.
class ChallengeParticipantsScreen extends StatefulWidget {
  const ChallengeParticipantsScreen({
    super.key,
    required this.challengeTitle,
    required this.participants,
    this.initialTabIndex = 0,
  });

  final String challengeTitle;
  final List<ChallengeParticipant> participants;
  final int initialTabIndex;

  @override
  State<ChallengeParticipantsScreen> createState() =>
      _ChallengeParticipantsScreenState();
}

class _ChallengeParticipantsScreenState
    extends State<ChallengeParticipantsScreen>
    with SingleTickerProviderStateMixin {
  late final List<ChallengeParticipant> _active = widget.participants
      .where((p) => p.status == 'active')
      .toList();
  late final List<ChallengeParticipant> _removed = widget.participants
      .where((p) => p.status == 'removed')
      .toList();
  late final List<ChallengeParticipant> _completed = widget.participants
      .where((p) => p.status == 'completed')
      .toList();

  late final TabController _tabs = TabController(
    length: _completed.isEmpty ? 2 : 3,
    initialIndex: widget.initialTabIndex.clamp(
      0,
      _completed.isEmpty ? 1 : 2,
    ),
    vsync: this,
  );

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs = <Tab>[
      Tab(text: 'Active · ${_active.length}'),
      Tab(text: 'Gave up · ${_removed.length}'),
      if (_completed.isNotEmpty) Tab(text: 'Completed · ${_completed.length}'),
    ];
    final views = <Widget>[
      _ParticipantsList(
        participants: _active,
        emptyLabel: 'No active participants yet.',
        showTodayMarker: true,
      ),
      _ParticipantsList(
        participants: _removed,
        emptyLabel: 'Nobody has left this challenge.',
      ),
      if (_completed.isNotEmpty)
        _ParticipantsList(
          participants: _completed,
          emptyLabel: 'No completions yet.',
        ),
    ];
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
          'Participants',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            decoration: BoxDecoration(
              color: BrandColors.bgCard(context).withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.purple.withValues(alpha: 0.24),
              ),
            ),
            child: TabBar(
              controller: _tabs,
              tabs: tabs,
              indicator: BoxDecoration(
                gradient: AppColors.buttonGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              indicatorPadding: const EdgeInsets.all(4),
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: BrandColors.inkSoft(context),
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12.5,
                letterSpacing: 0.2,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
              splashFactory: NoSplash.splashFactory,
              overlayColor: WidgetStatePropertyAll(Colors.transparent),
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ResponsiveContainer(
          maxWidth: 640,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                child: Text(
                  widget.challengeTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: BrandColors.inkDim(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(controller: _tabs, children: views),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ParticipantsList extends StatelessWidget {
  const _ParticipantsList({
    required this.participants,
    required this.emptyLabel,
    this.showTodayMarker = false,
  });

  final List<ChallengeParticipant> participants;
  final String emptyLabel;
  final bool showTodayMarker;

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            emptyLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: BrandColors.inkSoft(context),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: participants.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _ParticipantRow(
        participant: participants[i],
        showTodayMarker: showTodayMarker,
      ),
    );
  }
}

class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.participant,
    required this.showTodayMarker,
  });
  final ChallengeParticipant participant;
  final bool showTodayMarker;

  @override
  Widget build(BuildContext context) {
    final p = participant;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticService().light();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PublicProfileScreen(
                userId: p.userId,
                initialName: p.name,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
          decoration: BoxDecoration(
            color: BrandColors.bgCard(context).withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.purple.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  NetworkAvatar(
                    name: p.name,
                    avatarUrl: absoluteAvatarUrl(p.avatarUrl),
                    size: 40,
                  ),
                  // Green dot on the avatar when this participant has
                  // already checked in today. Only shown on the Active
                  // tab (per the constructor default).
                  if (showTodayMarker && p.checkedInToday)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF34D399),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: BrandColors.bgDeep(context),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 8,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            p.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.bricolageGrotesque(
                              color: BrandColors.ink(context),
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _CompactScoreChip(
                          score: p.challengeScore,
                          tier: p.challengeTier,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    RankInsignia(
                      rankIndex: p.rankIndex,
                      rankName: p.rankName,
                    ),
                  ],
                ),
              ),
              if (showTodayMarker && p.checkedInToday)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF34D399).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF34D399).withValues(alpha: 0.55),
                    ),
                  ),
                  child: const Text(
                    'DID IT TODAY',
                    style: TextStyle(
                      color: Color(0xFF34D399),
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact tier-colored "1,250 pts" chip shown next to a participant
/// name in the roster. Deliberately small so the primary read stays
/// name + avatar + rank insignia. Renders nothing when the score is
/// 0 so new users don't get a "Bronze · 0 pts" chip cluttering every
/// row.
class _CompactScoreChip extends StatelessWidget {
  const _CompactScoreChip({required this.score, required this.tier});
  final int score;
  final String tier;

  static String _formatScore(int s) {
    if (s < 1000) return '$s';
    // 1250 → "1.3k", 15000 → "15k". Terse so the chip stays narrow
    // in rows that already carry name + rank insignia.
    if (s < 10000) {
      final k = s / 1000;
      return '${k.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}k';
    }
    return '${(s / 1000).round()}k';
  }

  @override
  Widget build(BuildContext context) {
    if (score <= 0) return const SizedBox.shrink();
    final c = tierColor(tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.50), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.emoji_events_rounded, color: c, size: 11),
          const SizedBox(width: 3),
          Text(
            _formatScore(score),
            style: TextStyle(
              color: c,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
