import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/frequency.dart';
import '../models/habit.dart';
import 'auth_service.dart';
import 'habit_reminder_service.dart';
import 'habit_repository.dart';

/// One proposed change to the user's plan.
///
/// The adaptation engine lives entirely on the server: it correlates
/// the user's check-ins with their completion history and decides when
/// a habit needs a different time, a smaller target, or a bigger one.
/// The client's only job is to render a single card and send back
/// accept or decline.
class AdaptationProposal {
  const AdaptationProposal({
    required this.id,
    required this.habitId,
    required this.habitTitle,
    required this.kind,
    required this.rationale,
    this.fromValue,
    this.toValue,
    this.windows = const {},
    this.canReduceAmount = false,
    this.canReduceDuration = false,
    this.canReduceFrequency = false,
    this.cyclesUsed = 0,
    this.maxCycles = 3,
  });

  final int id;
  final String habitId;
  final String habitTitle;
  /// ask · time · quantity · duration · increase · floor · pause
  ///
  /// `ask` is the first step of the card: the user has not said why
  /// they keep missing the habit yet, so there is no change to propose.
  ///
  /// `pause` means the habit has used all its approved adjustments and is
  /// still being missed. It changes nothing about the plan, it stops the
  /// nagging, so the client applies it without asking.
  final String kind;
  final String rationale;
  final String? fromValue;
  final String? toValue;

  /// Only for `ask`: hour ranges ([from, to], inclusive) per window
  /// name, and which kinds of "make it smaller" this habit supports.
  final Map<String, List<int>> windows;
  final bool canReduceAmount;
  final bool canReduceDuration;
  final bool canReduceFrequency;

  /// Only for `pause`: how many adjustments were used, out of how many.
  final int cyclesUsed;
  final int maxCycles;

  bool get isAsk => kind == 'ask';
  bool get isPause => kind == 'pause';

  factory AdaptationProposal.fromJson(Map<String, dynamic> j) {
    final opts = (j['options'] as Map?)?.cast<String, dynamic>() ?? const {};
    final wins = <String, List<int>>{};
    final rawWins = (opts['windows'] as Map?) ?? const {};
    rawWins.forEach((k, v) {
      final list = (v as List).map((e) => (e as num).toInt()).toList();
      if (list.length == 2) wins[k as String] = list;
    });
    return AdaptationProposal(
      id: (j['id'] as num).toInt(),
      habitId: (j['habit_id'] as String?) ?? '',
      habitTitle: (j['habit_title'] as String?) ?? 'this habit',
      kind: (j['kind'] as String?) ?? 'time',
      rationale: (j['rationale'] as String?) ?? '',
      fromValue: j['from'] as String?,
      toValue: j['to'] as String?,
      windows: wins,
      canReduceAmount: opts['can_reduce_amount'] == true,
      canReduceDuration: opts['can_reduce_duration'] == true,
      canReduceFrequency: opts['can_reduce_frequency'] == true,
      cyclesUsed: (j['cycles_used'] as num?)?.toInt() ?? 0,
      maxCycles: (j['max_cycles'] as num?)?.toInt() ?? 3,
    );
  }

  /// Label for the accept button — phrased as the action, not "OK".
  String get acceptLabel {
    switch (kind) {
      case 'time':
        return 'Move it';
      case 'quantity':
        return 'Make it smaller';
      case 'duration':
        return 'Shorten it';
      case 'frequency':
        return 'Fewer days';
      case 'increase':
        return 'Level up';
      case 'pause':
        return 'Got it';
      default:
        return 'Do it';
    }
  }

  String get declineLabel => kind == 'increase' ? 'Not yet' : 'Keep it';
}

/// One past adaptation with its measured outcome. Powers the
/// "we moved your workout to 6 PM — completion went 30% → 85%" list.
class AdaptationRecord {
  const AdaptationRecord({
    required this.habitTitle,
    required this.kind,
    required this.status,
    required this.rationale,
    this.fromValue,
    this.toValue,
    this.beforeRate,
    this.afterRate,
    this.delta,
    this.decidedAt,
  });

  final String habitTitle;
  final String kind;
  final String status;
  final String rationale;
  final String? fromValue;
  final String? toValue;
  final double? beforeRate;
  final double? afterRate;
  final double? delta;
  final DateTime? decidedAt;

  bool get hasOutcome => beforeRate != null && afterRate != null;

  factory AdaptationRecord.fromJson(Map<String, dynamic> j) =>
      AdaptationRecord(
        habitTitle: (j['habit_title'] as String?) ?? '',
        kind: (j['kind'] as String?) ?? '',
        status: (j['status'] as String?) ?? '',
        rationale: (j['rationale'] as String?) ?? '',
        fromValue: j['from'] as String?,
        toValue: j['to'] as String?,
        beforeRate: (j['before_rate'] as num?)?.toDouble(),
        afterRate: (j['after_rate'] as num?)?.toDouble(),
        delta: (j['delta'] as num?)?.toDouble(),
        decidedAt: j['decided_at'] is String
            ? DateTime.tryParse(j['decided_at'] as String)
            : null,
      );
}

/// Put an accepted proposal's value into [h] (in memory; the caller saves).
/// `time` replaces the habit's reminder slots with the one proposed time and
/// switches reminders on, so the Edit screen shows exactly that time.
/// Returns false when the proposal can't be applied to this habit.
bool applyProposalToHabit(Habit h, AdaptationProposal p) {
  final to = p.toValue;
  if (to == null) return false;
  switch (p.kind) {
    case 'time':
      final m = minuteOfDay(to);
      if (m == null) return false;
      h.reminderMinutes = [m];
      h.remindersEnabled = true;
      return true;
    case 'quantity' || 'increase':
      final n = int.tryParse(to);
      if (n == null || n < 1) return false;
      h.targetValue = n;
      return true;
    case 'duration':
      final n = int.tryParse(to);
      if (n == null || n < 1) return false;
      if (h.programDurationDays != null) {
        h.programDurationDays = n;
      } else {
        h.avoidDurationDays = n;
      }
      return true;
    case 'frequency':
      final f = parseFrequencyProposal(to);
      if (f == null) return false;
      h.frequency = f.$1;
      h.frequencyDays = f.$2;
      return true;
    default:
      return false;
  }
}

/// "weekdays" or "custom:1,3,5" (weekday numbers, 0 = Sunday) from the
/// server's `frequency` proposal. Null when it isn't one of those.
(Frequency, List<int>?)? parseFrequencyProposal(String to) {
  if (to == 'weekdays') return (Frequency.weekdays, null);
  if (to == 'daily') return (Frequency.daily, null);
  if (to.startsWith('custom:')) {
    final days = [
      for (final s in to.substring(7).split(','))
        if (int.tryParse(s.trim()) != null) int.parse(s.trim())
    ];
    if (days.isEmpty || days.any((d) => d < 0 || d > 6)) return null;
    return (Frequency.custom, days);
  }
  return null;
}

/// Whether [h] currently holds [p]'s value (what Edit would show).
bool proposalIsApplied(Habit h, AdaptationProposal p) {
  final to = p.toValue;
  if (to == null) return false;
  switch (p.kind) {
    case 'time':
      final m = minuteOfDay(to);
      return m != null && h.remindersEnabled && h.reminderMinutes.length == 1 &&
          h.reminderMinutes.first == m;
    case 'quantity' || 'increase':
      return h.targetValue == int.tryParse(to);
    case 'duration':
      final n = int.tryParse(to);
      return n != null &&
          (h.programDurationDays ?? h.avoidDurationDays) == n;
    case 'frequency':
      final f = parseFrequencyProposal(to);
      if (f == null || h.frequency != f.$1) return false;
      final have = [...?h.frequencyDays]..sort();
      final want = [...?f.$2]..sort();
      return have.length == want.length &&
          [for (var i = 0; i < have.length; i++) have[i] == want[i]]
              .every((x) => x);
    default:
      return false;
  }
}

/// "HH:MM" -> minute of day, or null.
int? minuteOfDay(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length != 2) return null;
  final hh = int.tryParse(parts[0]);
  final mm = int.tryParse(parts[1]);
  if (hh == null || mm == null || hh < 0 || hh > 23 || mm < 0 || mm > 59) {
    return null;
  }
  return hh * 60 + mm;
}

/// Pause [h] because the adaptation engine ran out of adjustments.
/// Idempotent, and it never overrides another flow: a habit the user
/// already archived, or one parked behind a stepping stone, is left as
/// it is. Returns true when [h] was changed (and needs saving).
bool markPausedByAdaptation(Habit h, {DateTime? now}) {
  if (h.isArchived || h.parkedBehind != null) return false;
  h.isArchived = true;
  h.pausedReason = kPausedAdaptCycles;
  h.pausedAt = now ?? DateTime.now();
  return true;
}

/// Undo [markPausedByAdaptation] on restart. Returns true when [h] was
/// an adaptation pause (and so needs saving + the server told).
bool clearAdaptationPause(Habit h) {
  if (h.pausedReason != kPausedAdaptCycles) return false;
  h.isArchived = false;
  h.pausedReason = null;
  h.pausedAt = null;
  return true;
}

class AdaptationService {
  AdaptationService._();
  static final AdaptationService _instance = AdaptationService._();
  factory AdaptationService() => _instance;

  static const String _baseUrl = 'https://mood8.app/api';
  static const Duration _timeout = Duration(seconds: 15);
  static const String _kPendingRestartsKey = 'mood8.adapt.pendingRestarts';

  final http.Client _client = http.Client();

  Map<String, String> get _headers {
    final t = AuthService().token;
    return {
      'content-type': 'application/json',
      if (t != null) 'authorization': 'Bearer $t',
    };
  }

  bool get _signedIn => AuthService().token != null;

  /// Today's card, if the engine has one. Returns null for signed-out
  /// users, on any error, and on the (common) days with nothing to say.
  Future<AdaptationProposal?> todaysProposal() async {
    if (!_signedIn) return null;
    // ignore: discarded_futures
    _flushPendingRestarts();
    try {
      final res = await _client
          .get(Uri.parse('$_baseUrl/adapt/proposal?v=3'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final p = body['proposal'];
      if (p == null) return null;
      return AdaptationProposal.fromJson(p as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[adapt] proposal fetch failed: $e');
      return null;
    }
  }

  Future<bool> accept(int id) => _decide(id, 'accept');

  /// Answer the card's "why?" question. [reason] is no_time · no_mood ·
  /// too_hard; [window] (morning · afternoon · night) goes with the
  /// first two, [reduce] (duration · amount) with too_hard. Returns the
  /// concrete proposal the server built from the answer, or null.
  Future<AdaptationProposal?> answer(
    int id, {
    required String reason,
    String? window,
    String? reduce,
    String? note,
  }) async {
    if (!_signedIn) return null;
    try {
      final res = await _client
          .post(Uri.parse('$_baseUrl/adapt/$id/answer'),
              headers: _headers,
              body: jsonEncode({
                'reason': reason,
                'window': ?window,
                'reduce': ?reduce,
                if (note != null && note.isNotEmpty) 'note': note,
              }))
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final p = body['proposal'];
      if (p == null) return null;
      return AdaptationProposal.fromJson(p as Map<String, dynamic>);
    } catch (e) {
      debugPrint('[adapt] answer failed: $e');
      return null;
    }
  }

  /// Write an accepted proposal into the habit itself. The server only
  /// records the decision; the habit lives on the device, so without
  /// this an accepted card would change nothing. Returns true only when
  /// the habit was changed AND reads back changed.
  Future<bool> applyToHabit(AdaptationProposal p) async {
    try {
      final repo = HabitRepository();
      Habit? h;
      for (final x in repo.getAllHabits()) {
        if (x.id == p.habitId) {
          h = x;
          break;
        }
      }
      if (h == null || !applyProposalToHabit(h, p)) return false;
      await repo.updateHabit(h);
      // Read it back: the card must never say "updated" for a habit that
      // still shows the old value in Edit.
      for (final x in repo.getAllHabits()) {
        if (x.id == p.habitId) return proposalIsApplied(x, p);
      }
      return false;
    } catch (e) {
      debugPrint('[adapt] apply failed: $e');
      return false;
    }
  }

  Future<bool> decline(int id) => _decide(id, 'decline');

  /// Apply a `pause` proposal on this device: archive the habit (history
  /// kept), record why and when, and switch its reminders off. Safe to
  /// call again for the same proposal. Returns false only when the habit
  /// can't be found. The caller then confirms with [accept].
  Future<bool> applyPause(AdaptationProposal p) async {
    try {
      final repo = HabitRepository();
      Habit? h;
      for (final x in repo.getAllHabits()) {
        if (x.id == p.habitId) {
          h = x;
          break;
        }
      }
      if (h == null) return false;
      if (markPausedByAdaptation(h)) await repo.updateHabit(h);
      // Belt and braces: updateHabit reschedules (= cancels, archived),
      // but a paused habit must never keep a reminder.
      await HabitReminderService().cancelFor(h);
      return true;
    } catch (e) {
      debugPrint('[adapt] applyPause failed: $e');
      return false;
    }
  }

  /// Tell the server the user restarted a paused habit, which resets its
  /// adjustment counter. If it can't be sent now it is retried on the next
  /// [todaysProposal].
  Future<bool> restartHabit(String habitId) async {
    if (!_signedIn) {
      await _queueRestart(habitId);
      return false;
    }
    try {
      final res = await _client
          .post(
              Uri.parse(
                  '$_baseUrl/adapt/habits/${Uri.encodeComponent(habitId)}/restart'),
              headers: _headers)
          .timeout(_timeout);
      if (res.statusCode >= 200 && res.statusCode < 300) return true;
      // 4xx = the server doesn't know the habit / an older server without
      // the endpoint: nothing to retry. 5xx / rate limits are worth it.
      if (res.statusCode >= 500 || res.statusCode == 429) {
        await _queueRestart(habitId);
      }
      return false;
    } catch (e) {
      debugPrint('[adapt] restart failed: $e');
      await _queueRestart(habitId);
      return false;
    }
  }

  Future<void> _queueRestart(String habitId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = (prefs.getStringList(_kPendingRestartsKey) ?? const [])
          .toSet()
        ..add(habitId);
      await prefs.setStringList(_kPendingRestartsKey, ids.toList());
    } catch (_) {}
  }

  bool _flushing = false;

  Future<void> _flushPendingRestarts() async {
    if (_flushing) return;
    _flushing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final ids = prefs.getStringList(_kPendingRestartsKey) ?? const [];
      if (ids.isEmpty) return;
      await prefs.remove(_kPendingRestartsKey);
      for (final id in ids) {
        // Re-queues itself on a retryable failure.
        await restartHabit(id);
      }
    } catch (_) {
    } finally {
      _flushing = false;
    }
  }

  Future<bool> _decide(int id, String what) async {
    if (!_signedIn) return false;
    try {
      final res = await _client
          .post(Uri.parse('$_baseUrl/adapt/$id/$what'), headers: _headers)
          .timeout(_timeout);
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      debugPrint('[adapt] $what failed: $e');
      return false;
    }
  }

  /// Fixed-option reason, one tap, sent after a second miss.
  ///
  /// [reason] may be `other`, with a short [note]. [missDate]
  /// (`yyyy-MM-dd`) is the missed day the answer is about.
  Future<void> reportMissReason({
    required String habitId,
    required String reason,
    String? note,
    String? missDate,
  }) async {
    if (!_signedIn) return;
    try {
      await _client
          .post(Uri.parse('$_baseUrl/habits/miss-reason'),
              headers: _headers,
              body: jsonEncode({
                'habit_id': habitId,
                'reason': reason,
                if (note != null && note.isNotEmpty) 'note': note,
                'miss_date': ?missDate,
              }))
          .timeout(_timeout);
    } catch (e) {
      debugPrint('[adapt] miss reason failed: $e');
    }
  }

  Future<List<AdaptationRecord>> history() async {
    if (!_signedIn) return const [];
    try {
      final res = await _client
          .get(Uri.parse('$_baseUrl/adapt/history'), headers: _headers)
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) return const [];
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return ((body['adaptations'] as List?) ?? const [])
          .map((e) => AdaptationRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[adapt] history failed: $e');
      return const [];
    }
  }

  /// Save the six onboarding answers. These seed the cold-start engine,
  /// which is what makes day one useful before any personal data exists.
  Future<void> saveOnboarding(Map<String, dynamic> answers) async {
    if (!_signedIn) return;
    try {
      await _client
          .post(Uri.parse('$_baseUrl/onboarding'),
              headers: _headers, body: jsonEncode(answers))
          .timeout(_timeout);
    } catch (e) {
      debugPrint('[adapt] onboarding save failed: $e');
    }
  }
}
