import 'package:flutter_test/flutter_test.dart';
import 'package:mood8/models/entitlement.dart';
import 'package:mood8/models/subscription.dart';
import 'package:mood8/screens/premium_screen.dart';
import 'package:mood8/services/ai_service.dart';
import 'package:mood8/services/subscription_service.dart';
import 'package:mood8/widgets/trial_chip.dart';

void main() {
  group('EntitlementStatus.fromJson', () {
    test('parses every new field', () {
      final s = EntitlementStatus.fromJson({
        'is_premium': true,
        'plan_class': 'premium_trial',
        'trial_ends_at': '2026-10-20T12:00:00Z',
        'trial_used': true,
        'premium_source': 'trial',
        'habit_limit_reason': 'premium',
        'ai_chat_daily_limit': 5,
        'ai_chat_used_today': 2,
        'ai_suggestion_daily_limit': 3,
        'ai_suggestion_used_today': 1,
        'rewards': {
          'referral_progress': 3,
          'referral_target': 5,
          'challenge_progress': 7,
          'challenge_target': 20,
          'banked_days': 4,
        },
      });
      expect(s.planClass, PlanClass.premiumTrial);
      expect(s.isTrial, isTrue);
      expect(s.trialEndsAt, DateTime.utc(2026, 10, 20, 12));
      expect(s.trialUsed, isTrue);
      expect(s.premiumSource, 'trial');
      expect(s.aiChatDailyLimit, 5);
      expect(s.aiSuggestionUsedToday, 1);
      expect(s.suggestionsRemaining, 2);
      expect(s.rewards.referralLine, '3 of 5 friends joined');
      expect(s.rewards.challengeLine, '7 of 20 challenges completed');
      expect(s.rewards.bankedDays, 4);
    });

    test('an older server (none of the new keys) behaves as before', () {
      final free = EntitlementStatus.fromJson({'is_premium': false});
      expect(free.planClass, PlanClass.free);
      expect(free.trialEndsAt, isNull);
      expect(free.suggestionsRemaining, isNull);
      expect(free.rewards.hasAnything, isFalse);
      final paid =
          EntitlementStatus.fromJson({'is_premium': true}, isPremium: true);
      expect(paid.planClass, PlanClass.premiumPaid);
    });

    test('nulls and junk are tolerated', () {
      final s = EntitlementStatus.fromJson({
        'plan_class': null,
        'trial_ends_at': null,
        'rewards': 'nope',
        'ai_chat_daily_limit': null,
      });
      expect(s.planClass, PlanClass.free);
      expect(s.rewards, same(RewardsProgress.empty));
      expect(s.aiChatDailyLimit, 0);
    });

    test('trial days left rounds up and never goes negative', () {
      final s = EntitlementStatus(
        planClass: PlanClass.premiumTrial,
        trialEndsAt: DateTime.utc(2026, 10, 20, 12),
      );
      expect(s.trialDaysLeft(now: DateTime.utc(2026, 10, 17, 12)), 3);
      expect(s.trialDaysLeft(now: DateTime.utc(2026, 10, 17, 13)), 3);
      expect(s.trialDaysLeft(now: DateTime.utc(2026, 10, 20, 11)), 1);
      expect(s.trialDaysLeft(now: DateTime.utc(2026, 10, 21)), 0);
      // Not a trial -> no countdown.
      const paid = EntitlementStatus(planClass: PlanClass.premiumPaid);
      expect(paid.trialDaysLeft(), isNull);
    });
  });

  group('habit limit from /status', () {
    test('server number wins, explicit null means unlimited', () {
      expect(
          SubscriptionService.habitLimitFromStatus({'habit_limit': 3},
              isPremium: false),
          3);
      expect(
          SubscriptionService.habitLimitFromStatus({'habit_limit': null},
              isPremium: false),
          isNull);
      expect(
          SubscriptionService.habitLimitFromStatus({'habit_limit': 7.0},
              isPremium: false),
          7);
    });

    test('field missing (old server): free falls back to 3', () {
      expect(
          SubscriptionService.habitLimitFromStatus({}, isPremium: false), 3);
      expect(
          SubscriptionService.habitLimitFromStatus({}, isPremium: true),
          isNull);
    });
  });

  group('plan card copy', () {
    test('titles', () {
      EntitlementStatus e(String pc) => EntitlementStatus(planClass: pc);
      expect(planCardTitle(SubscriptionTier.free, e(PlanClass.free)), 'Free');
      expect(planCardTitle(SubscriptionTier.free, e(PlanClass.legacyUnlimited)),
          'Legacy — unlimited habits');
      expect(
          planCardTitle(SubscriptionTier.premium, e(PlanClass.premiumTrial)),
          'Premium trial');
      expect(
          planCardTitle(
              SubscriptionTier.premium, e(PlanClass.premiumComplimentary)),
          'Premium (reward)');
      expect(planCardTitle(SubscriptionTier.premium, e(PlanClass.premiumPaid)),
          'Premium');
    });

    test('legacy says it is not Premium; trial shows an end date', () {
      expect(
          planCardSubtitle(SubscriptionTier.free, null,
              const EntitlementStatus(planClass: PlanClass.legacyUnlimited)),
          'Unlimited habits; this is not Premium.');
      final end = DateTime.now().add(const Duration(days: 4, hours: 3));
      final sub = planCardSubtitle(
        SubscriptionTier.premium,
        null,
        EntitlementStatus(
            planClass: PlanClass.premiumTrial, trialEndsAt: end),
      );
      expect(sub, startsWith('Ends '));
      expect(sub, endsWith('5 days left'));
    });

    test('trial chip copy', () {
      expect(TrialChip.labelFor(null), isNull);
      expect(TrialChip.labelFor(0), 'Premium trial: ends today');
      expect(TrialChip.labelFor(1), 'Premium trial: 1 day left');
      expect(TrialChip.labelFor(6), 'Premium trial: 6 days left');
    });
  });

  group('sync push rejections', () {
    test('parses the rejected list; absent or junk gives empty', () {
      final list = SyncRejection.parseList([
        {
          'entity_type': 'habit',
          'entity_id': 'h1',
          'reason': 'habit_limit',
          'limit': 3,
        },
        {'entity_type': 'mood', 'entity_id': 'm1', 'reason': 'other'},
        'junk',
        {'entity_id': 'x'},
      ]);
      expect(list.length, 2);
      expect(list.first.isHabitLimit, isTrue);
      expect(list.first.limit, 3);
      expect(list.last.isHabitLimit, isFalse);
      expect(SyncRejection.parseList(null), isEmpty);
      expect(SyncRejection.parseList({'a': 1}), isEmpty);
    });
  });

  group('coach reply', () {
    test('suggestion limit fields', () {
      final r = CoachChatReply.fromJson({
        'reply': 'Hi',
        'proposed_habits': null,
        'suggestions_used': 3,
        'suggestions_limit': 3,
        'suggestion_limit_reached': true,
      });
      expect(r.proposed, isNull);
      expect(r.suggestionLimitReached, isTrue);
      expect(r.suggestionsLeft, 0);
    });

    test('older server: no cap, nothing reached', () {
      final r = CoachChatReply.fromJson({'reply': 'Hi'});
      expect(r.suggestionLimitReached, isFalse);
      expect(r.suggestionsLimit, 0);
      expect(r.suggestionsLeft, isNull);
    });

    test('remaining suggestions when capped', () {
      final r = CoachChatReply.fromJson({
        'reply': 'Hi',
        'suggestions_used': 1,
        'suggestions_limit': 3,
        'suggestion_limit_reached': false,
      });
      expect(r.suggestionsLeft, 2);
    });
  });
}
