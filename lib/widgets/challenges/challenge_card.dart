import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/challenge.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import 'network_avatar.dart';
import 'user_badge_chip.dart';

/// Single challenge tile used in the list + my-challenges views.
/// Visual vocabulary matches HabitCard — same gradient body, same
/// pink/purple border tokens, same icon-bubble + identity-chip header
/// layout — so the two surfaces feel like one app.
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
    final accent = _accentFor(challenge.category);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
          decoration: BoxDecoration(
            // Same dual-stop gradient body the HabitCard uses, with an
            // accent-tinted border keyed off the category color.
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                BrandColors.bgCard(context).withValues(alpha: 0.94),
                BrandColors.bg(context).withValues(alpha: 0.86),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: accent.withValues(alpha: 0.28),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: category icon-bubble + title + creator badge.
              // Mirrors HabitCard's icon + title + identity stack.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CategoryBubble(
                    category: challenge.category,
                    color: accent,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          challenge.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.bricolageGrotesque(
                            color: BrandColors.ink(context),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        _CategoryChip(
                          label: prettyCategory(challenge.category),
                          color: accent,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Creator row. Pulled out from the title block so the
              // creator's avatar + badge get the breathing room they
              // deserve and so the layout doesn't fight long titles.
              Row(
                children: [
                  NetworkAvatar(
                    name: challenge.creator.name,
                    avatarUrl: absoluteAvatarUrl(challenge.creator.avatarUrl),
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'by ${challenge.creator.name}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: BrandColors.inkSoft(context),
                            fontSize: 12,
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
                  _DurationPill(
                    durationDays: challenge.durationDays,
                    daysRemaining: challenge.daysRemaining,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _StatsBar(
                activePct: challenge.activePct,
                gaveUpPct: challenge.gaveUpPct,
                accent: accent,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.group_rounded,
                      size: 14, color: BrandColors.inkDim(context)),
                  const SizedBox(width: 6),
                  Text(
                    '${challenge.activeCount} in · ${challenge.participantCount} joined',
                    style: TextStyle(
                      color: BrandColors.inkSoft(context),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const Spacer(),
                  if (challenge.participantsPreview.isNotEmpty)
                    _ParticipantAvatarStack(
                      previews: challenge.participantsPreview,
                      totalActive: challenge.activeCount,
                    ),
                ],
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

/// Round icon-bubble keyed to the challenge category. Mirrors
/// HabitCard's `_IconBubble` but uses a Material icon (categories don't
/// carry an emoji on the backend).
class _CategoryBubble extends StatelessWidget {
  const _CategoryBubble({required this.category, required this.color});
  final String category;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0.12),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Icon(
        _iconFor(category),
        color: Colors.white,
        size: 20,
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: BrandColors.inkSoft(context),
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _DurationPill extends StatelessWidget {
  const _DurationPill({
    required this.durationDays,
    required this.daysRemaining,
  });
  final int durationDays;
  final int daysRemaining;

  @override
  Widget build(BuildContext context) {
    final remaining = daysRemaining.clamp(0, durationDays);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded,
              size: 12, color: AppColors.purpleLight),
          const SizedBox(width: 5),
          Text(
            '$remaining / ${durationDays}d',
            style: TextStyle(
              color: BrandColors.ink(context),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal stack of up to ~7 visible participant avatars with a
/// "+N" pill at the end when there are more total active participants
/// than fit in the row.
class _ParticipantAvatarStack extends StatelessWidget {
  const _ParticipantAvatarStack({
    required this.previews,
    required this.totalActive,
  });
  final List<ParticipantPreview> previews;
  final int totalActive;

  static const int _visible = 6;
  static const double _size = 22;
  static const double _overlap = 8;

  @override
  Widget build(BuildContext context) {
    final shown = previews.take(_visible).toList();
    final overflow = totalActive - shown.length;
    final children = <Widget>[];
    for (var i = 0; i < shown.length; i++) {
      children.add(Positioned(
        left: i * (_size - _overlap),
        child: NetworkAvatar(
          name: shown[i].name,
          avatarUrl: absoluteAvatarUrl(shown[i].avatarUrl),
          size: _size,
          borderColor: BrandColors.bgCard(context),
          borderWidth: 2,
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

class _OverflowChip extends StatelessWidget {
  const _OverflowChip({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: _ParticipantAvatarStack._size,
      height: _ParticipantAvatarStack._size,
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
                    AppColors.purple.withValues(alpha: 0.40),
                    AppColors.pink.withValues(alpha: 0.32),
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
                : AppColors.purple.withValues(alpha: 0.28),
          ),
          boxShadow: upvoted
              ? [
                  BoxShadow(
                    color: AppColors.pink.withValues(alpha: 0.32),
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
          color: AppColors.purple.withValues(alpha: 0.28),
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
  const _StatsBar({
    required this.activePct,
    required this.gaveUpPct,
    required this.accent,
  });
  final double activePct;
  final double gaveUpPct;
  final Color accent;

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
                  height: 7,
                  color: BrandColors.inkFaint(context)
                      .withValues(alpha: 0.22),
                ),
                Row(
                  children: [
                    Expanded(
                      flex: activePct.round().clamp(0, 100),
                      child: Container(
                        height: 7,
                        decoration: BoxDecoration(
                          gradient: AppColors.buttonGradient,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: gaveUpPct.round().clamp(0, 100),
                      child: Container(
                        height: 7,
                        color: AppColors.pink.withValues(alpha: 0.48),
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

/// Map category slug → category accent color. Reuses existing brand
/// tokens so the palette stays consistent.
Color _accentFor(String category) {
  switch (category.toLowerCase()) {
    case 'health':
      return AppColors.pinkLight;
    case 'fitness':
      return AppColors.purple;
    case 'mindfulness':
      return AppColors.blueAccent;
    case 'productivity':
      return AppColors.purpleLight;
    case 'learning':
      return AppColors.blueAccent;
    case 'social':
      return AppColors.pink;
    default:
      return AppColors.purpleLight;
  }
}

IconData _iconFor(String category) {
  switch (category.toLowerCase()) {
    case 'health':
      return Icons.favorite_rounded;
    case 'fitness':
      return Icons.directions_run_rounded;
    case 'mindfulness':
      return Icons.self_improvement_rounded;
    case 'productivity':
      return Icons.bolt_rounded;
    case 'learning':
      return Icons.menu_book_rounded;
    case 'social':
      return Icons.groups_rounded;
    default:
      return Icons.flag_rounded;
  }
}
