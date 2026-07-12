// Plain Dart models mirroring the backend `/api/challenges/*` shapes.
// Build 1 of 3 wired these up server-side; Build 2 just consumes them.

import 'package:flutter/painting.dart' show Color;

const _kAvatarHost = 'https://mood8.app';

/// Turn a backend-relative avatar path ("/api/avatars/12-abc.jpg") into
/// an absolute URL ready for `Image.network`. Pass-through for null /
/// already-absolute URLs.
String? absoluteAvatarUrl(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  if (raw.startsWith('http')) return raw;
  return '$_kAvatarHost$raw';
}

class ChallengeCreator {
  const ChallengeCreator({
    required this.id,
    required this.name,
    required this.creatorScore,
    required this.profileBadge,
    required this.avatarUrl,
    required this.challengeScore,
    required this.challengeTier,
  });

  final int? id;
  final String name;
  final int creatorScore;
  final String? profileBadge;
  final String? avatarUrl;
  /// Global Challenge Score for this creator (lifetime, all challenges).
  /// Older backends omit this; default 0. Surfaced as a score prefix
  /// chip next to the creator name in card previews and detail pages.
  final int challengeScore;
  final String challengeTier;

  factory ChallengeCreator.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ChallengeCreator(
        id: null,
        name: 'Anonymous',
        creatorScore: 0,
        profileBadge: null,
        avatarUrl: null,
        challengeScore: 0,
        challengeTier: 'Bronze',
      );
    }
    return ChallengeCreator(
      id: (json['id'] as num?)?.toInt(),
      name: (json['name'] as String?) ?? 'Anonymous',
      creatorScore: (json['creator_score'] as num?)?.toInt() ?? 0,
      profileBadge: json['profile_badge'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      challengeScore: (json['challenge_score'] as num?)?.toInt() ?? 0,
      challengeTier: (json['challenge_tier'] as String?) ?? 'Bronze',
    );
  }
}

/// Minimal user shape used by participant_preview on summary rows.
class ParticipantPreview {
  const ParticipantPreview({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.challengeScore,
    required this.challengeTier,
  });
  final int id;
  final String name;
  final String? avatarUrl;
  final int challengeScore;
  final String challengeTier;
  factory ParticipantPreview.fromJson(Map<String, dynamic> json) =>
      ParticipantPreview(
        id: (json['id'] as num).toInt(),
        name: (json['name'] as String?) ?? 'Anonymous',
        avatarUrl: json['avatar_url'] as String?,
        challengeScore: (json['challenge_score'] as num?)?.toInt() ?? 0,
        challengeTier: (json['challenge_tier'] as String?) ?? 'Bronze',
      );
}

/// Summary as returned by `/api/challenges/list` and `/mine`.
class ChallengeSummary {
  const ChallengeSummary({
    required this.id,
    required this.title,
    required this.category,
    required this.durationDays,
    required this.daysRemaining,
    required this.participantCount,
    required this.activeCount,
    required this.gaveUpCount,
    required this.completedCount,
    required this.activePct,
    required this.gaveUpPct,
    required this.status,
    required this.creator,
    required this.upvoteCount,
    required this.userUpvoted,
    required this.commentCount,
    required this.participantsPreview,
  });

  final int id;
  final String title;
  final String category;
  final int durationDays;
  final int daysRemaining;
  final int participantCount;
  final int activeCount;
  final int gaveUpCount;
  final int completedCount;
  final double activePct;
  final double gaveUpPct;
  final String status;
  final ChallengeCreator creator;
  final int upvoteCount;
  final bool userUpvoted;
  final int commentCount;
  final List<ParticipantPreview> participantsPreview;

  factory ChallengeSummary.fromJson(Map<String, dynamic> json) {
    return ChallengeSummary(
      id: (json['id'] as num).toInt(),
      title: (json['title'] as String?) ?? '',
      category: (json['category'] as String?) ?? '',
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 0,
      daysRemaining: (json['days_remaining'] as num?)?.toInt() ?? 0,
      participantCount:
          (json['participant_count'] as num?)?.toInt() ?? 0,
      activeCount: (json['active_count'] as num?)?.toInt() ?? 0,
      gaveUpCount: (json['gave_up_count'] as num?)?.toInt() ?? 0,
      completedCount: (json['completed_count'] as num?)?.toInt() ?? 0,
      activePct: ((json['active_pct'] as num?) ?? 0).toDouble(),
      gaveUpPct: ((json['gave_up_pct'] as num?) ?? 0).toDouble(),
      status: (json['status'] as String?) ?? 'active',
      creator: ChallengeCreator.fromJson(
        json['creator'] as Map<String, dynamic>?,
      ),
      upvoteCount: (json['upvote_count'] as num?)?.toInt() ?? 0,
      userUpvoted: json['user_upvoted'] as bool? ?? false,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
      participantsPreview: ((json['participants_preview'] as List?) ??
              const [])
          .map((p) => ParticipantPreview.fromJson(
              p as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Convenience: clone with mutated upvote fields for optimistic UI.
  ChallengeSummary copyWith({
    int? upvoteCount,
    bool? userUpvoted,
    int? commentCount,
  }) =>
      ChallengeSummary(
        id: id,
        title: title,
        category: category,
        durationDays: durationDays,
        daysRemaining: daysRemaining,
        participantCount: participantCount,
        activeCount: activeCount,
        gaveUpCount: gaveUpCount,
        completedCount: completedCount,
        activePct: activePct,
        gaveUpPct: gaveUpPct,
        status: status,
        creator: creator,
        upvoteCount: upvoteCount ?? this.upvoteCount,
        userUpvoted: userUpvoted ?? this.userUpvoted,
        commentCount: commentCount ?? this.commentCount,
        participantsPreview: participantsPreview,
      );
}

class ChallengeParticipant {
  const ChallengeParticipant({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.profileBadge,
    required this.rankIndex,
    required this.rankName,
    required this.status,
    required this.missedRankups,
    required this.joinedAfterStart,
    required this.joinedAt,
    required this.removedAt,
    required this.checkedInToday,
    required this.challengeScore,
    required this.challengeTier,
  });

  final int userId;
  final String name;
  final String? avatarUrl;
  final String? profileBadge;
  final int rankIndex;
  final String rankName;
  final String status; // active / removed / completed
  final int missedRankups;
  final bool joinedAfterStart;
  final DateTime? joinedAt;
  final DateTime? removedAt;
  /// True when this participant has a check-in for today (UTC). Powers
  /// the "did it today" avatar row on the detail screen. Older backends
  /// omit the field; missing → false which reads correctly as "not
  /// yet done today".
  final bool checkedInToday;
  /// Global Challenge Score (lifetime, across every challenge). The
  /// participants roster surfaces this as a compact tier-colored
  /// chip next to the name so people can see who they're up against.
  /// Older backends omit these; missing → 0 / "Bronze".
  final int challengeScore;
  final String challengeTier;

  factory ChallengeParticipant.fromJson(Map<String, dynamic> json) {
    return ChallengeParticipant(
      userId: (json['id'] as num).toInt(),
      name: (json['name'] as String?) ?? 'Anonymous',
      avatarUrl: json['avatar_url'] as String?,
      profileBadge: json['profile_badge'] as String?,
      rankIndex: (json['rank_index'] as num?)?.toInt() ?? 0,
      rankName: (json['rank_name'] as String?) ?? 'Recruit',
      status: (json['status'] as String?) ?? 'active',
      missedRankups: (json['missed_rankups'] as num?)?.toInt() ?? 0,
      joinedAfterStart: json['joined_after_start'] as bool? ?? false,
      joinedAt: json['joined_at'] is String
          ? _parseServerUtc(json['joined_at'])
          : null,
      removedAt: json['removed_at'] is String
          ? _parseServerUtc(json['removed_at'])
          : null,
      checkedInToday: json['checked_in_today'] as bool? ?? false,
      challengeScore: (json['challenge_score'] as num?)?.toInt() ?? 0,
      challengeTier: (json['challenge_tier'] as String?) ?? 'Bronze',
    );
  }
}

/// Viewer-specific state for a challenge.
class ChallengeMe {
  const ChallengeMe({
    required this.participantId,
    required this.status,
    required this.rankIndex,
    required this.rankName,
    required this.missedRankups,
    required this.checkedInToday,
    required this.checkedInOnTime,
  });

  final int participantId;
  final String status;
  final int rankIndex;
  final String rankName;
  final int missedRankups;
  final bool checkedInToday;
  final bool? checkedInOnTime;

  factory ChallengeMe.fromJson(Map<String, dynamic> json) {
    return ChallengeMe(
      participantId: (json['participant_id'] as num).toInt(),
      status: (json['status'] as String?) ?? 'active',
      rankIndex: (json['rank_index'] as num?)?.toInt() ?? 0,
      rankName: (json['rank_name'] as String?) ?? 'Recruit',
      missedRankups: (json['missed_rankups'] as num?)?.toInt() ?? 0,
      checkedInToday: json['checked_in_today'] as bool? ?? false,
      checkedInOnTime: json['checked_in_on_time'] as bool?,
    );
  }
}

/// Full detail as returned by `/api/challenges/{id}`.
class ChallengeDetail {
  const ChallengeDetail({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.durationDays,
    required this.dailyDeadlineMinutesUtc,
    required this.startDate,
    required this.endDate,
    required this.daysRemaining,
    required this.maxParticipants,
    required this.status,
    required this.aiReviewStatus,
    required this.aiReviewReason,
    required this.createdAt,
    required this.creator,
    required this.participants,
    required this.summary,
    required this.me,
    required this.isCreator,
    required this.upvoteCount,
    required this.userUpvoted,
    required this.commentCount,
  });

  final int id;
  final String title;
  final String description;
  final String category;
  final int durationDays;
  final int dailyDeadlineMinutesUtc;
  final DateTime startDate;
  final DateTime endDate;
  final int daysRemaining;
  final int? maxParticipants;
  final String status;
  final String aiReviewStatus;
  final String? aiReviewReason;
  final DateTime createdAt;
  final ChallengeCreator creator;
  final List<ChallengeParticipant> participants;
  final ChallengeSummary summary;
  final ChallengeMe? me;
  final bool isCreator;
  final int upvoteCount;
  final bool userUpvoted;
  final int commentCount;

  factory ChallengeDetail.fromJson(Map<String, dynamic> json) {
    return ChallengeDetail(
      id: (json['id'] as num).toInt(),
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? '',
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 0,
      dailyDeadlineMinutesUtc:
          (json['daily_deadline_minutes'] as num?)?.toInt() ?? 0,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      daysRemaining: (json['days_remaining'] as num?)?.toInt() ?? 0,
      maxParticipants: (json['max_participants'] as num?)?.toInt(),
      status: json['status'] as String? ?? 'active',
      aiReviewStatus: json['ai_review_status'] as String? ?? 'approved',
      aiReviewReason: json['ai_review_reason'] as String?,
      createdAt: _parseServerUtc(json['created_at']),
      creator: ChallengeCreator.fromJson(
        json['creator'] as Map<String, dynamic>?,
      ),
      participants: (json['participants'] as List?)
              ?.map((p) =>
                  ChallengeParticipant.fromJson(p as Map<String, dynamic>))
              .toList() ??
          const [],
      summary: ChallengeSummary.fromJson(
        json['stats'] as Map<String, dynamic>,
      ),
      me: json['me'] == null
          ? null
          : ChallengeMe.fromJson(json['me'] as Map<String, dynamic>),
      isCreator: json['is_creator'] as bool? ?? false,
      upvoteCount: (json['upvote_count'] as num?)?.toInt() ?? 0,
      userUpvoted: json['user_upvoted'] as bool? ?? false,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One comment as returned by `/api/challenges/{id}/comments`.
class ChallengeComment {
  const ChallengeComment({
    required this.id,
    required this.challengeId,
    required this.userId,
    required this.userName,
    required this.userAvatarUrl,
    required this.userProfileBadge,
    required this.userChallengeScore,
    required this.userChallengeTier,
    required this.text,
    required this.createdAt,
  });

  final int id;
  final int challengeId;
  final int userId;
  final String userName;
  final String? userAvatarUrl;
  final String? userProfileBadge;
  final int userChallengeScore;
  final String userChallengeTier;
  final String text;
  final DateTime createdAt;

  factory ChallengeComment.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map<String, dynamic>?) ?? const {};
    return ChallengeComment(
      id: (json['id'] as num).toInt(),
      challengeId: (json['challenge_id'] as num).toInt(),
      userId: (user['id'] as num?)?.toInt() ?? 0,
      userName: (user['name'] as String?) ?? 'Anonymous',
      userAvatarUrl: user['avatar_url'] as String?,
      userProfileBadge: user['profile_badge'] as String?,
      userChallengeScore: (user['challenge_score'] as num?)?.toInt() ?? 0,
      userChallengeTier: (user['challenge_tier'] as String?) ?? 'Bronze',
      text: (json['text'] as String?) ?? '',
      createdAt: _parseServerUtc(json['created_at']),
    );
  }
}

/// Parses a server-emitted ISO-8601 datetime string as UTC. The
/// backend serializer stamps a trailing `Z` so DateTime.tryParse
/// already returns a UTC-flagged DateTime, but for legacy rows
/// (or a client build lagging behind the server rollout) we force
/// `.toUtc()` too — treating naive strings as UTC is what the
/// storage layer intended all along. Empty / missing / malformed
/// falls back to `DateTime.now().toUtc()` so relative-time math
/// still produces "just now" instead of an infinite duration.
DateTime _parseServerUtc(dynamic value) {
  if (value is! String || value.isEmpty) {
    return DateTime.now().toUtc();
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return DateTime.now().toUtc();
  // If the string had a zone marker, .isUtc reflects that. If it
  // was naive, treat it as UTC too — the server always emits UTC.
  return parsed.isUtc ? parsed : DateTime.utc(
        parsed.year,
        parsed.month,
        parsed.day,
        parsed.hour,
        parsed.minute,
        parsed.second,
        parsed.millisecond,
        parsed.microsecond,
      );
}

/// One row from `/api/challenges/{id}/join-requests`.
class JoinRequest {
  const JoinRequest({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userAvatarUrl,
    required this.creatorScore,
    required this.profileBadge,
    required this.challengeScore,
    required this.challengeTier,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String userName;
  final String? userAvatarUrl;
  final int creatorScore;
  final String? profileBadge;
  final int challengeScore;
  final String challengeTier;
  final DateTime createdAt;

  factory JoinRequest.fromJson(Map<String, dynamic> json) {
    final user = (json['user'] as Map<String, dynamic>?) ?? const {};
    return JoinRequest(
      id: (json['id'] as num).toInt(),
      userId: (user['id'] as num?)?.toInt() ?? 0,
      userName: (user['name'] as String?) ?? 'Anonymous',
      userAvatarUrl: user['avatar_url'] as String?,
      creatorScore: (user['creator_score'] as num?)?.toInt() ?? 0,
      profileBadge: user['profile_badge'] as String?,
      challengeScore: (user['challenge_score'] as num?)?.toInt() ?? 0,
      challengeTier: (user['challenge_tier'] as String?) ?? 'Bronze',
      createdAt: _parseServerUtc(json['created_at']),
    );
  }
}

/// Result of POST /api/challenges/create. The server returns
/// `{published: true, challenge_id}` on AI approval or
/// `{published: false, reason}` on AI rejection.
class ChallengeCreateResult {
  const ChallengeCreateResult({
    required this.published,
    required this.challengeId,
    required this.reason,
  });

  final bool published;
  final int? challengeId;
  final String? reason;

  factory ChallengeCreateResult.fromJson(Map<String, dynamic> json) {
    return ChallengeCreateResult(
      published: json['published'] as bool? ?? false,
      challengeId: (json['challenge_id'] as num?)?.toInt(),
      reason: json['reason'] as String?,
    );
  }
}

/// Result of POST /api/challenges/{id}/checkin.
class CheckinResult {
  const CheckinResult({
    required this.checkedIn,
    required this.wasOnTime,
    required this.rankIndex,
    required this.rankName,
    required this.missedRankups,
    required this.idempotent,
    required this.scoreAwarded,
  });

  final bool checkedIn;
  final bool wasOnTime;
  final int rankIndex;
  final String rankName;
  final int missedRankups;
  final bool idempotent;
  /// Challenge_score points awarded by THIS check-in. 0 for late
  /// check-ins, for creator-of-challenge check-ins that halved to 0,
  /// or for check-ins on <3-participant challenges. The client
  /// surfaces this in the on-time celebration ("+2 Challenge Score").
  final int scoreAwarded;

  factory CheckinResult.fromJson(Map<String, dynamic> json) {
    return CheckinResult(
      checkedIn: json['checked_in'] as bool? ?? false,
      wasOnTime: json['was_on_time'] as bool? ?? false,
      rankIndex: (json['rank_index'] as num?)?.toInt() ?? 0,
      rankName: (json['rank_name'] as String?) ?? 'Recruit',
      missedRankups: (json['missed_rankups'] as num?)?.toInt() ?? 0,
      idempotent: json['idempotent'] as bool? ?? false,
      scoreAwarded: (json['score_awarded'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─── Global Challenge Ranking ────────────────────────────────────────

/// One row in the /api/ranking/leaderboard top list.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.position,
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.profileBadge,
    required this.challengeScore,
    required this.tier,
  });

  final int position;
  final int userId;
  final String name;
  final String? avatarUrl;
  final String? profileBadge;
  final int challengeScore;
  final String tier;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        position: (json['position'] as num).toInt(),
        userId: (json['user_id'] as num).toInt(),
        name: (json['name'] as String?) ?? 'Anonymous',
        avatarUrl: json['avatar_url'] as String?,
        profileBadge: json['profile_badge'] as String?,
        challengeScore: (json['challenge_score'] as num?)?.toInt() ?? 0,
        tier: (json['tier'] as String?) ?? 'Bronze',
      );
}

/// Requester's own {rank, score, tier} — always present in the
/// leaderboard response even when they're below top 100 or opted out.
class LeaderboardMe {
  const LeaderboardMe({
    required this.position,
    required this.score,
    required this.tier,
    required this.isTop100,
    required this.hiddenFromLeaderboard,
    required this.nextTierName,
    required this.nextTierPointsNeeded,
  });

  final int position;
  final int score;
  final String tier;
  final bool isTop100;
  final bool hiddenFromLeaderboard;
  final String? nextTierName;
  final int? nextTierPointsNeeded;

  factory LeaderboardMe.fromJson(Map<String, dynamic> json) {
    final next = json['next_tier'] as Map<String, dynamic>?;
    return LeaderboardMe(
      position: (json['position'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toInt() ?? 0,
      tier: (json['tier'] as String?) ?? 'Bronze',
      isTop100: json['is_top_100'] as bool? ?? false,
      hiddenFromLeaderboard:
          json['hidden_from_leaderboard'] as bool? ?? false,
      nextTierName: next == null ? null : next['name'] as String?,
      nextTierPointsNeeded:
          next == null ? null : (next['points_needed'] as num?)?.toInt(),
    );
  }
}

class Leaderboard {
  const Leaderboard({
    required this.top,
    required this.me,
  });
  final List<LeaderboardEntry> top;
  final LeaderboardMe me;

  factory Leaderboard.fromJson(Map<String, dynamic> json) => Leaderboard(
        top: ((json['top'] as List?) ?? const [])
            .map((e) =>
                LeaderboardEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        me: LeaderboardMe.fromJson(
          (json['me'] as Map<String, dynamic>?) ?? const {},
        ),
      );
}

/// Convenience: brand colours per tier. Kept in the model so the
/// Ranking screen + tier chips everywhere share one lookup.
Color tierColor(String tier) {
  switch (tier) {
    case 'Silver':
      return const Color(0xFFC0C0C0);
    case 'Gold':
      return const Color(0xFFFFD700);
    case 'Platinum':
      return const Color(0xFFE5E4E2);
    case 'Diamond':
      return const Color(0xFFB9F2FF);
    case 'Legend League':
      return const Color(0xFFF472B6);
    case 'Bronze':
    default:
      return const Color(0xFFCD7F32);
  }
}

/// Canonical, ordered list of categories the client uses for filter
/// chips and the create form. Keep in sync with what creators send to
/// `category` — the backend doesn't restrict this, it's UX-only.
const List<String> kChallengeCategories = [
  'health',
  'fitness',
  'mindfulness',
  'productivity',
  'learning',
  'social',
  'other',
];

String prettyCategory(String c) {
  if (c.isEmpty) return '';
  return c[0].toUpperCase() + c.substring(1);
}

/// Convert a local TimeOfDay to UTC minutes-from-midnight. The backend
/// stores the daily deadline as UTC minutes; the user picks in their
/// local timezone so this is the single boundary that does the swap.
int localTimeToUtcMinutes(int localHour, int localMinute) {
  final now = DateTime.now();
  final local = DateTime(now.year, now.month, now.day, localHour, localMinute);
  final utc = local.toUtc();
  return utc.hour * 60 + utc.minute;
}

/// Inverse: convert UTC minutes-from-midnight back to a local
/// (hour, minute) pair for display.
({int hour, int minute}) utcMinutesToLocal(int utcMinutes) {
  final today = DateTime.now().toUtc();
  final utc = DateTime.utc(
    today.year, today.month, today.day,
    utcMinutes ~/ 60, utcMinutes % 60,
  );
  final local = utc.toLocal();
  return (hour: local.hour, minute: local.minute);
}
