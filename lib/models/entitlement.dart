/// Server-reported plan details from `GET /api/subscription/status`.
///
/// The server decides everything here; the client only renders it. Every
/// field is optional on the wire so an older server (which sends none of
/// the new keys) parses into a sensible "same as before" value.
class PlanClass {
  PlanClass._();
  static const String free = 'free';
  static const String legacyUnlimited = 'legacy_unlimited';
  static const String premiumTrial = 'premium_trial';
  static const String premiumComplimentary = 'premium_complimentary';
  static const String premiumPaid = 'premium_paid';
}

/// Progress toward the two 1-month rewards, plus banked days.
class RewardsProgress {
  const RewardsProgress({
    this.referralProgress = 0,
    this.referralTarget = 0,
    this.challengeProgress = 0,
    this.challengeTarget = 0,
    this.bankedDays = 0,
  });

  final int referralProgress;
  final int referralTarget;
  final int challengeProgress;
  final int challengeTarget;
  final int bankedDays;

  static const RewardsProgress empty = RewardsProgress();

  /// True when the server sent a target we can draw a progress line for.
  bool get hasReferral => referralTarget > 0;
  bool get hasChallenge => challengeTarget > 0;
  bool get hasAnything => hasReferral || hasChallenge || bankedDays > 0;

  /// "3 of 5 friends joined" — null when the server sent no target.
  String? get referralLine =>
      hasReferral ? '$referralProgress of $referralTarget friends joined' : null;

  /// "7 of 20 challenges completed" — null when the server sent no target.
  String? get challengeLine => hasChallenge
      ? '$challengeProgress of $challengeTarget challenges completed'
      : null;

  /// Null-safe: anything that isn't a map (absent on an older server)
  /// gives [empty].
  factory RewardsProgress.fromJson(Object? raw) {
    if (raw is! Map) return empty;
    int n(String k) => (raw[k] as num?)?.toInt() ?? 0;
    return RewardsProgress(
      referralProgress: n('referral_progress'),
      referralTarget: n('referral_target'),
      challengeProgress: n('challenge_progress'),
      challengeTarget: n('challenge_target'),
      bankedDays: n('banked_days'),
    );
  }
}

/// The plan + AI-allowance fields added to the subscription status.
class EntitlementStatus {
  const EntitlementStatus({
    required this.planClass,
    this.trialEndsAt,
    this.trialUsed = false,
    this.premiumSource,
    this.habitLimitReason,
    this.aiChatDailyLimit = 0,
    this.aiChatUsedToday = 0,
    this.aiSuggestionDailyLimit = 0,
    this.aiSuggestionUsedToday = 0,
    this.rewards = RewardsProgress.empty,
  });

  static const EntitlementStatus free =
      EntitlementStatus(planClass: PlanClass.free);

  final String planClass;
  final DateTime? trialEndsAt;
  final bool trialUsed;

  /// stripe · promo · trial · referral · reward
  final String? premiumSource;

  /// free · legacy · premium · free_mode
  final String? habitLimitReason;

  /// 0 = no cap.
  final int aiChatDailyLimit;
  final int aiChatUsedToday;
  final int aiSuggestionDailyLimit;
  final int aiSuggestionUsedToday;
  final RewardsProgress rewards;

  bool get isTrial => planClass == PlanClass.premiumTrial;
  bool get isLegacy => planClass == PlanClass.legacyUnlimited;

  /// Whole days left on the trial (rounded up, never negative). Null when
  /// this isn't a trial or no end date was sent.
  int? trialDaysLeft({DateTime? now}) {
    final end = trialEndsAt;
    if (!isTrial || end == null) return null;
    final left = end.difference(now ?? DateTime.now());
    if (left.isNegative) return 0;
    return (left.inMinutes / (60 * 24)).ceil();
  }

  /// Suggestions the user can still request today; null when uncapped.
  int? get suggestionsRemaining {
    if (aiSuggestionDailyLimit <= 0) return null;
    final left = aiSuggestionDailyLimit - aiSuggestionUsedToday;
    return left < 0 ? 0 : left;
  }

  /// [isPremium] is the legacy `is_premium` flag, used to derive a plan
  /// class when the server doesn't send one.
  factory EntitlementStatus.fromJson(Map<String, dynamic> body,
      {bool isPremium = false}) {
    int n(String k) => (body[k] as num?)?.toInt() ?? 0;
    final pc = body['plan_class'];
    final trialIso = body['trial_ends_at'];
    return EntitlementStatus(
      planClass: pc is String && pc.isNotEmpty
          ? pc
          : (isPremium ? PlanClass.premiumPaid : PlanClass.free),
      trialEndsAt: trialIso is String ? DateTime.tryParse(trialIso) : null,
      trialUsed: body['trial_used'] == true,
      premiumSource: body['premium_source'] as String?,
      habitLimitReason: body['habit_limit_reason'] as String?,
      aiChatDailyLimit: n('ai_chat_daily_limit'),
      aiChatUsedToday: n('ai_chat_used_today'),
      aiSuggestionDailyLimit: n('ai_suggestion_daily_limit'),
      aiSuggestionUsedToday: n('ai_suggestion_used_today'),
      rewards: RewardsProgress.fromJson(body['rewards']),
    );
  }

  /// Short label for the account screen.
  String get planLabel {
    switch (planClass) {
      case PlanClass.legacyUnlimited:
        return 'Legacy — unlimited habits';
      case PlanClass.premiumTrial:
        return 'Premium trial';
      case PlanClass.premiumComplimentary:
        return 'Premium (reward)';
      case PlanClass.premiumPaid:
        return 'Premium';
      default:
        return 'Free';
    }
  }
}

/// One entry of the `rejected` list in the `POST /api/sync/push` reply.
class SyncRejection {
  const SyncRejection({
    required this.entityType,
    required this.entityId,
    required this.reason,
    this.limit,
  });

  final String entityType;
  final String entityId;
  final String reason;
  final int? limit;

  bool get isHabitLimit => entityType == 'habit' && reason == 'habit_limit';

  static SyncRejection? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final type = raw['entity_type'];
    final id = raw['entity_id'];
    if (type is! String || id is! String) return null;
    return SyncRejection(
      entityType: type,
      entityId: id,
      reason: (raw['reason'] as String?) ?? '',
      limit: (raw['limit'] as num?)?.toInt(),
    );
  }

  /// Parses the whole `rejected` list; absent or malformed gives empty.
  static List<SyncRejection> parseList(Object? raw) {
    if (raw is! List) return const [];
    return raw.map(tryParse).whereType<SyncRejection>().toList();
  }
}
