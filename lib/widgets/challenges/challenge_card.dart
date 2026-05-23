import 'package:flutter/material.dart';

import '../../models/challenge.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import 'user_badge_chip.dart';

/// Single challenge tile used in the list + my-challenges views.
class ChallengeCard extends StatelessWidget {
  const ChallengeCard({
    super.key,
    required this.challenge,
    required this.onTap,
    this.onToggleUpvote,
  });

  final ChallengeSummary challenge;
  final VoidCallback onTap;
  /// When supplied, the upvote button is interactive. The list screen
  /// wires this to optimistic per-row state + a server toggle.
  final VoidCallback? onToggleUpvote;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                BrandColors.bgCard(context),
                BrandColors.bg(context),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.purple.withValues(alpha: 0.32),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.purple.withValues(alpha: 0.16),
                blurRadius: 22,
                spreadRadius: -8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Creator row
              Row(
                children: [
                  _CreatorAvatar(
                    name: challenge.creator.name,
                    avatarUrl:
                        absoluteAvatarUrl(challenge.creator.avatarUrl),
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          challenge.creator.name,
                          style: TextStyle(
                            color: BrandColors.ink(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        UserBadgeChip(
                          badge: challenge.creator.profileBadge,
                          creatorScore: challenge.creator.creatorScore,
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                  _CategoryPill(label: challenge.category),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                challenge.title,
                style: brandFont(
                  color: BrandColors.ink(context),
                  fontSize: 22,
                  weight: FontWeight.w800,
                  height: 1.15,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule_rounded,
                      size: 14, color: BrandColors.inkDim(context)),
                  const SizedBox(width: 6),
                  Text(
                    '${challenge.durationDays}-day · ${challenge.daysRemaining} left',
                    style: TextStyle(
                      color: BrandColors.inkSoft(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.group_rounded,
                      size: 14, color: BrandColors.inkDim(context)),
                  const SizedBox(width: 6),
                  Text(
                    '${challenge.participantCount} in',
                    style: TextStyle(
                      color: BrandColors.inkSoft(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (challenge.participantsPreview.isNotEmpty) ...[
                const SizedBox(height: 12),
                _ParticipantAvatarRow(
                  previews: challenge.participantsPreview,
                  totalActive: challenge.activeCount,
                ),
              ],
              const SizedBox(height: 12),
              _StatsBar(
                activePct: challenge.activePct,
                gaveUpPct: challenge.gaveUpPct,
              ),
              const SizedBox(height: 12),
              _EngagementRow(
                challenge: challenge,
                onToggleUpvote: onToggleUpvote,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Round avatar that renders the server-provided image when available
/// and falls back to a gradient + initial.
class _CreatorAvatar extends StatelessWidget {
  const _CreatorAvatar({
    required this.name,
    required this.avatarUrl,
    required this.size,
  });
  final String name;
  final String? avatarUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.orbGradient,
      ),
      child: Text(
        letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.45,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    if (avatarUrl == null) return fallback;
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: Image.network(
          avatarUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}

/// Horizontal row of up to ~7 visible participant avatars with a
/// "+N" pill at the end when there are more total active participants
/// than fit in the row.
class _ParticipantAvatarRow extends StatelessWidget {
  const _ParticipantAvatarRow({
    required this.previews,
    required this.totalActive,
  });
  final List<ParticipantPreview> previews;
  final int totalActive;

  static const int _visible = 7;
  static const double _size = 24;
  static const double _overlap = 8;

  @override
  Widget build(BuildContext context) {
    final shown = previews.take(_visible).toList();
    final overflow = totalActive - shown.length;
    final children = <Widget>[];
    for (var i = 0; i < shown.length; i++) {
      children.add(Positioned(
        left: i * (_size - _overlap),
        child: _Avatar(
          name: shown[i].name,
          avatarUrl: absoluteAvatarUrl(shown[i].avatarUrl),
        ),
      ));
    }
    if (overflow > 0) {
      children.add(Positioned(
        left: shown.length * (_size - _overlap),
        child: _OverflowChip(text: '+$overflow'),
      ));
    }
    final width =
        shown.length * (_size - _overlap) + _size + (overflow > 0 ? 4 : 0);
    return SizedBox(
      height: _size + 2,
      width: width.toDouble(),
      child: Stack(clipBehavior: Clip.none, children: children),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.avatarUrl});
  final String name;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final fallback = Container(
      width: _ParticipantAvatarRow._size,
      height: _ParticipantAvatarRow._size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.orbGradient,
        border: Border.all(
          color: BrandColors.bgDeep(context),
          width: 2,
        ),
      ),
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    if (avatarUrl == null) return fallback;
    return Container(
      width: _ParticipantAvatarRow._size,
      height: _ParticipantAvatarRow._size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: BrandColors.bgDeep(context),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: Image.network(
          avatarUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => fallback,
        ),
      ),
    );
  }
}

class _OverflowChip extends StatelessWidget {
  const _OverflowChip({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: _ParticipantAvatarRow._size,
      height: _ParticipantAvatarRow._size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: BrandColors.bgCard(context),
        border: Border.all(
          color: BrandColors.bgDeep(context),
          width: 2,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: BrandColors.inkSoft(context),
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.pink.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.pinkLight.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        prettyCategory(label),
        style: TextStyle(
          color: AppColors.pinkLight,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Upvote pill + comment-count chip in a row at the bottom of the
/// card. The comment chip only renders when `commentCount > 0`
/// (silent surface until there's something to read).
class _EngagementRow extends StatelessWidget {
  const _EngagementRow({
    required this.challenge,
    required this.onToggleUpvote,
  });
  final ChallengeSummary challenge;
  final VoidCallback? onToggleUpvote;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _UpvoteButton(
          upvoted: challenge.userUpvoted,
          count: challenge.upvoteCount,
          onTap: onToggleUpvote,
        ),
        if (challenge.commentCount > 0) ...[
          const SizedBox(width: 10),
          _CommentChip(count: challenge.commentCount),
        ],
        const Spacer(),
      ],
    );
  }
}

class _UpvoteButton extends StatelessWidget {
  const _UpvoteButton({
    required this.upvoted,
    required this.count,
    required this.onTap,
  });
  final bool upvoted;
  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              HapticService().selection();
              onTap!();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: upvoted
              ? LinearGradient(
                  colors: [
                    AppColors.purple.withValues(alpha: 0.35),
                    AppColors.pink.withValues(alpha: 0.30),
                  ],
                )
              : null,
          color: upvoted
              ? null
              : BrandColors.bgCard(context).withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: upvoted
                ? AppColors.pinkLight.withValues(alpha: 0.55)
                : AppColors.purple.withValues(alpha: 0.30),
          ),
          boxShadow: upvoted
              ? [
                  BoxShadow(
                    color: AppColors.pink.withValues(alpha: 0.35),
                    blurRadius: 14,
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              upvoted
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              size: 14,
              color: upvoted ? Colors.white : BrandColors.inkSoft(context),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: TextStyle(
                color: upvoted ? Colors.white : BrandColors.inkSoft(context),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentChip extends StatelessWidget {
  const _CommentChip({required this.count});
  final int count;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 12, color: BrandColors.inkSoft(context)),
          const SizedBox(width: 6),
          Text(
            '$count',
            style: TextStyle(
              color: BrandColors.inkSoft(context),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.activePct, required this.gaveUpPct});
  final double activePct;
  final double gaveUpPct;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                Container(
                  height: 6,
                  color: BrandColors.inkFaint(context)
                      .withValues(alpha: 0.25),
                ),
                Row(
                  children: [
                    Expanded(
                      flex: activePct.round().clamp(0, 100),
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          gradient: AppColors.buttonGradient,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: gaveUpPct.round().clamp(0, 100),
                      child: Container(
                        height: 6,
                        color: AppColors.pink.withValues(alpha: 0.55),
                      ),
                    ),
                    Expanded(
                      flex:
                          (100 - activePct - gaveUpPct).round().clamp(0, 100),
                      child: const SizedBox.shrink(),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${activePct.toStringAsFixed(0)}% active',
          style: TextStyle(
            color: BrandColors.inkSoft(context),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}
