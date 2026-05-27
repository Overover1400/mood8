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
    // Compact + glowing redesign: tighter padding, smaller title row,
    // creator + duration condensed into one row beside the avatar
    // stack, single bottom row for engagement. Same content as before,
    // ~45% less vertical footprint. The accent-coloured halo glow
    // gives it the "premium feel" without leaning on a busy gradient.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accent.withValues(alpha: 0.16),
                BrandColors.bgCard(context).withValues(alpha: 0.92),
                BrandColors.bg(context).withValues(alpha: 0.78),
              ],
              stops: const [0.0, 0.55, 1.0],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: accent.withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              // Soft accent halo — the "glow" the brief asked for.
              // Spread negative so it sits as an aura around the card,
              // not as a heavy drop shadow.
              BoxShadow(
                color: accent.withValues(alpha: 0.32),
                blurRadius: 18,
                spreadRadius: -6,
                offset: const Offset(0, 6),
              ),
              // A second purple layer keyed to the brand keeps every
              // card in the list visually unified even though each
              // category recolours the primary halo.
              BoxShadow(
                color: AppColors.purple.withValues(alpha: 0.18),
                blurRadius: 22,
                spreadRadius: -10,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1 — title + category icon + duration pill.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _CategoryBubble(
                    category: challenge.category,
                    color: accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          challenge.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.bricolageGrotesque(
                            color: BrandColors.ink(context),
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _CategoryChip(
                          label: prettyCategory(challenge.category),
                          color: accent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  _DurationPill(
                    durationDays: challenge.durationDays,
                    daysRemaining: challenge.daysRemaining,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Row 2 — creator chip (avatar + name + badge inline).
              _CreatorRow(creator: challenge.creator),
              const SizedBox(height: 8),
              // Row 3 — stats bar.
              _StatsBar(
                activePct: challenge.activePct,
                gaveUpPct: challenge.gaveUpPct,
                accent: accent,
              ),
              const SizedBox(height: 8),
              // Row 4 — avatar stack on the left, engagement on the
              // right, so the card ends in one clean horizontal beat
              // instead of two stacked rows. Compact avatars (22px,
              // 8px overlap) keep faces visible without taking height.
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: challenge.participantsPreview.isNotEmpty
                        ? _ParticipantAvatarStack(
                            previews: challenge.participantsPreview,
                            totalActive: challenge.activeCount,
                          )
                        : Row(
                            children: [
                              Icon(Icons.group_rounded,
                                  size: 12,
                                  color: BrandColors.inkDim(context)),
                              const SizedBox(width: 6),
                              Text(
                                'Be the first to join',
                                style: TextStyle(
                                  color: BrandColors.inkSoft(context),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                  ),
                  _EngagementRow(
                    challenge: challenge,
                    onToggleUpvote: onToggleUpvote,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact single-line creator strip — avatar + "by Name" + badge in
/// one horizontal row. Replaces the old two-line "by X / badge below"
/// stack which was eating ~24px of vertical space per card.
class _CreatorRow extends StatelessWidget {
  const _CreatorRow({required this.creator});
  final ChallengeCreator creator;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        NetworkAvatar(
          name: creator.name,
          avatarUrl: absoluteAvatarUrl(creator.avatarUrl),
          size: 20,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            'by ${creator.name}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: BrandColors.inkSoft(context),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        UserBadgeChip(
          badge: creator.profileBadge,
          creatorScore: creator.creatorScore,
          compact: true,
        ),
      ],
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
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.60),
            color.withValues(alpha: 0.14),
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.50)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: -2,
          ),
        ],
      ),
      child: Icon(
        _iconFor(category),
        color: Colors.white,
        size: 16,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.36),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule_rounded,
              size: 10, color: AppColors.purpleLight),
          const SizedBox(width: 4),
          Text(
            '$remaining/${durationDays}d',
            style: TextStyle(
              color: BrandColors.ink(context),
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal overlapping avatar stack — up to 10 visible faces with
/// a "+N" pill on the end when there are more active participants
/// than fit in the row. Sized so the row reads at a glance (28-pixel
/// avatars, 10-pixel overlap so neighbours nudge but don't cover
/// each other) and falls back to gradient-initial fallbacks via
/// [NetworkAvatar] when a participant has no uploaded photo.
class _ParticipantAvatarStack extends StatelessWidget {
  const _ParticipantAvatarStack({
    required this.previews,
    required this.totalActive,
  });
  final List<ParticipantPreview> previews;
  final int totalActive;

  static const int _visible = 8;
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
    return SizedBox(
      height: _size + 2,
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
          color: AppColors.purple.withValues(alpha: 0.35),
          width: 2,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: BrandColors.inkSoft(context),
          fontSize: 10,
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
      mainAxisSize: MainAxisSize.min,
      children: [
        _UpvoteButton(
          upvoted: challenge.userUpvoted,
          count: challenge.upvoteCount,
          onTap: onToggleUpvote,
        ),
        if (challenge.commentCount > 0) ...[
          const SizedBox(width: 6),
          _CommentChip(count: challenge.commentCount),
        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
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
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: upvoted
                ? AppColors.pinkLight.withValues(alpha: 0.55)
                : AppColors.purple.withValues(alpha: 0.28),
          ),
          boxShadow: upvoted
              ? [
                  BoxShadow(
                    color: AppColors.pink.withValues(alpha: 0.32),
                    blurRadius: 12,
                    spreadRadius: -3,
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
              size: 12,
              color: upvoted ? Colors.white : BrandColors.inkSoft(context),
            ),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                color: upvoted ? Colors.white : BrandColors.inkSoft(context),
                fontSize: 11,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 11, color: BrandColors.inkSoft(context)),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              color: BrandColors.inkSoft(context),
              fontSize: 11,
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
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              children: [
                Container(
                  height: 5,
                  color: BrandColors.inkFaint(context)
                      .withValues(alpha: 0.22),
                ),
                Row(
                  children: [
                    Expanded(
                      flex: activePct.round().clamp(0, 100),
                      child: Container(
                        height: 5,
                        decoration: BoxDecoration(
                          gradient: AppColors.buttonGradient,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: gaveUpPct.round().clamp(0, 100),
                      child: Container(
                        height: 5,
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
        const SizedBox(width: 10),
        Text(
          '${activePct.toStringAsFixed(0)}% active',
          style: TextStyle(
            color: BrandColors.inkSoft(context),
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
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
