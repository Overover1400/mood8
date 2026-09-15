import 'package:shared_preferences/shared_preferences.dart';

import 'habit_repository.dart';
import 'mood_repository.dart';

/// Spec 6 — progressive feature unlocking.
///
/// The app does not show everything on day one. Each surface appears at
/// the moment it has something to say:
///
/// | Day 1              | check-in + habits, nothing else |
/// | ~7 days of data    | Progress — now there's a chart worth looking at |
/// | ~7 days of a habit | Challenges — "ready to do this with friends?" |
/// | ~14 days of data   | Coach — it can point at real patterns, not generics |
///
/// Two reasons this matters. The interface is never cluttered, and every
/// feature arrives with a reason attached instead of as an unexplained
/// icon. The empty screen is the enemy: a Progress tab with no data, a
/// Challenges tab with no challenges and a Coach with nothing specific to
/// say all make the app look broken on the day the user decides whether
/// to keep it.
///
/// Hard requirement from the spec: a power user can unlock everything
/// from Settings. Nobody is ever trapped behind the tutorial.
class FeatureUnlockService {
  FeatureUnlockService._();
  static final FeatureUnlockService _instance = FeatureUnlockService._();
  factory FeatureUnlockService() => _instance;

  static const String kUnlockAllKey = 'mood8.unlockAllFeatures';
  static const String _kGrandfatheredKey = 'mood8.unlockGrandfathered';

  static const int progressDays = 7;
  static const int coachDays = 14;
  static const int challengeHabitDays = 7;

  bool _unlockAll = false;
  bool _loaded = false;

  bool get unlockAllEnabled => _unlockAll;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _unlockAll = p.getBool(kUnlockAllKey) ?? false;

      // Grandfathering, decided once and then remembered.
      //
      // Progressive unlocking is for people meeting the app for the
      // first time. Applying it retroactively would take Progress,
      // Challenges and Coach *away* from someone already using them —
      // the app visibly losing features after an update, which reads as
      // a bug or a paywall. So on the first launch after upgrading, any
      // user who already has data keeps everything.
      if (!(p.getBool(_kGrandfatheredKey) ?? false)) {
        final existing = _hasPriorData();
        await p.setBool(_kGrandfatheredKey, true);
        if (existing) {
          _unlockAll = true;
          await p.setBool(kUnlockAllKey, true);
        }
      }
    } catch (_) {
      // Fail open: on a storage error, show everything. Hiding features
      // because a preference read failed is the worse outcome.
      _unlockAll = true;
    }
    _loaded = true;
  }

  /// Did this install already have a history before gating existed?
  bool _hasPriorData() {
    try {
      if (HabitRepository().getAllHabits().isNotEmpty) return true;
      if (MoodRepository().getAllEntries().isNotEmpty) return true;
    } catch (_) {
      // Boxes not open yet — treat as a fresh install.
    }
    return false;
  }

  Future<void> setUnlockAll(bool v) async {
    _unlockAll = v;
    _loaded = true;
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool(kUnlockAllKey, v);
    } catch (_) {
      // A failed write only costs the user the persisted preference;
      // the in-memory flag still applies for this session.
    }
  }

  /// Distinct days the user has checked in. Days, not entries — two
  /// check-ins on one day is one day of data to correlate against.
  int checkinDayCount() {
    final seen = <String>{};
    for (final e in MoodRepository().getAllEntries()) {
      seen.add('${e.timestamp.year}-${e.timestamp.month}-${e.timestamp.day}');
    }
    return seen.length;
  }

  /// Days since the oldest non-archived habit was created. "One habit
  /// held for a week" is the readiness signal for group challenges —
  /// inviting friends to something you're still failing at alone is how
  /// a challenge empties out by day four.
  int oldestHabitAgeDays() {
    final habits =
        HabitRepository().getAllHabits().where((h) => !h.isArchived);
    if (habits.isEmpty) return 0;
    final now = DateTime.now();
    var best = 0;
    for (final h in habits) {
      final d = now.difference(h.createdAt).inDays;
      if (d > best) best = d;
    }
    return best;
  }

  bool get progressUnlocked =>
      _unlockAll || checkinDayCount() >= progressDays;

  bool get coachUnlocked => _unlockAll || checkinDayCount() >= coachDays;

  bool get challengesUnlocked =>
      _unlockAll || oldestHabitAgeDays() >= challengeHabitDays;

  /// What the user is told when they tap something not yet open. Always
  /// phrased as a countdown to something arriving, never as a refusal.
  String progressLockReason() {
    final left = progressDays - checkinDayCount();
    return left <= 1
        ? 'Progress opens tomorrow — one more check-in to go.'
        : 'Progress opens after $progressDays days of check-ins. '
            '$left to go.';
  }

  String coachLockReason() {
    final left = coachDays - checkinDayCount();
    return left <= 1
        ? 'Coach opens tomorrow — one more check-in to go.'
        : 'Coach opens after $coachDays days of check-ins, so it can '
            'talk about your patterns instead of generic advice. '
            '$left to go.';
  }

  String challengesLockReason() {
    final left = challengeHabitDays - oldestHabitAgeDays();
    return left <= 1
        ? 'Challenges open tomorrow — keep one habit going.'
        : 'Challenges open once you’ve kept a habit for a week. '
            '$left days to go.';
  }

  /// True before [load] has run — callers that must not gate on a stale
  /// default can check this.
  bool get isLoaded => _loaded;
}
