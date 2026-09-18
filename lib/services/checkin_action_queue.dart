import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mood_repository.dart';

/// Spec 2.1 — answering the check-in from the notification itself.
///
/// Android gives us up to three action buttons per notification, which is
/// enough for one question ("How's your energy?" → Low / Okay / Good) but
/// nowhere near enough for three 1–5 sliders. So the notification captures
/// the single most valuable signal and the full check-in stays in the app.
///
/// ## Why this queue exists instead of writing Hive directly
///
/// The button handler runs in a **separate background isolate** — a
/// different Dart VM isolate from the running app, spawned by the plugin
/// when the notification is tapped with the app closed. Hive gives no
/// cross-isolate write safety: if the app happened to be open and both
/// isolates wrote the same box, the file can be corrupted. Losing a
/// user's entire habit history to a notification tap is not a trade worth
/// making for one data point.
///
/// So the background isolate only appends a small JSON record to
/// SharedPreferences (which *is* safe here — each write is an atomic
/// platform-channel call), and the app's own isolate drains that queue
/// into Hive on next launch. The answer keeps the timestamp of the tap,
/// not of the drain, so the data stays accurate even if the user doesn't
/// open the app for two days.
class CheckinActionQueue {
  CheckinActionQueue._();
  static final CheckinActionQueue _instance = CheckinActionQueue._();
  factory CheckinActionQueue() => _instance;

  static const String _kQueueKey = 'mood8.checkin.pendingAnswers';

  /// Action ids wired to the notification buttons. Format:
  /// `ci_<part>_<value1to5>`.
  static const String morningPrefix = 'ci_energy_';
  static const String eveningPrefix = 'ci_day_';

  /// Append one answer. Safe to call from a background isolate.
  ///
  /// Static and self-contained on purpose: the background isolate does
  /// not share this class's instance state with the app isolate.
  static Future<void> enqueue({
    required String part,
    required int value,
    required DateTime at,
  }) async {
    try {
      final p = await SharedPreferences.getInstance();
      // Re-read immediately before writing: the app isolate may have
      // drained the queue since this isolate started.
      await p.reload();
      final list = p.getStringList(_kQueueKey) ?? <String>[];
      list.add(jsonEncode({
        'part': part,
        'value': value,
        'at': at.toIso8601String(),
      }));
      await p.setStringList(_kQueueKey, list);
    } catch (e) {
      debugPrint('CheckinActionQueue.enqueue failed: $e');
    }
  }

  /// Drain every queued answer into Hive. Call once at startup, after
  /// the boxes are open.
  ///
  /// Returns how many answers were applied.
  Future<int> drain() async {
    var applied = 0;
    try {
      final p = await SharedPreferences.getInstance();
      await p.reload();
      final list = p.getStringList(_kQueueKey) ?? <String>[];
      if (list.isEmpty) return 0;
      // Clear first. A crash mid-drain loses at most one tick of mood
      // data; leaving the queue in place risks replaying answers onto
      // later days forever, which would poison the adaptation engine.
      await p.setStringList(_kQueueKey, <String>[]);

      final moods = MoodRepository();
      for (final raw in list) {
        try {
          final m = jsonDecode(raw) as Map<String, dynamic>;
          final part = m['part'] as String?;
          final value = (m['value'] as num?)?.toInt();
          final at = DateTime.tryParse(m['at'] as String? ?? '');
          if (part == null || value == null || at == null) continue;
          await _apply(moods, part: part, value: value, at: at);
          applied++;
        } catch (e) {
          debugPrint('CheckinActionQueue: bad record skipped: $e');
        }
      }
    } catch (e) {
      debugPrint('CheckinActionQueue.drain failed: $e');
    }
    return applied;
  }

  /// Writes one queued answer as a check-in on the day it was tapped.
  ///
  /// The notification only asked one question, so the other two sliders
  /// are left at the neutral midpoint rather than invented. A fabricated
  /// mood score would be worse than a missing one — the whole product
  /// rests on these numbers meaning something.
  Future<void> _apply(
    MoodRepository moods, {
    required String part,
    required int value,
    required DateTime at,
  }) async {
    // 1–5 on screen → 0–10 stored, matching the in-app sliders.
    final scaled = ((value - 1) / 4.0 * 10).clamp(0.0, 10.0);
    const neutral = 5.0;

    final existing = _entryFor(moods, at, part);
    if (existing != null) {
      // The user already checked in properly for this half of the day;
      // their full answer wins over the one-button version.
      return;
    }

    await moods.addEntry(
      mood: neutral,
      energy: part == 'morning' ? scaled : neutral,
      focus: neutral,
      timestamp: at,
      partOfDay: part,
      dayRating: part == 'evening' ? scaled : null,
    );
  }

  dynamic _entryFor(MoodRepository moods, DateTime day, String part) {
    for (final e in moods.getEntriesForDate(day)) {
      if ((e.partOfDay ?? 'morning') == part) return e;
    }
    return null;
  }
}

/// Handles one notification-button tap, from either isolate.
///
/// Lives here rather than in the plugin wrapper so the background entry
/// point stays free of Hive and of any app singleton — everything it
/// touches is a plain platform-channel call that works in a cold isolate.
Future<void> handleCheckinActionId(String actionId) async {
  // A background isolate starts with no plugins registered.
  DartPluginRegistrant.ensureInitialized();
  final parsed = parseCheckinActionId(actionId);
  if (parsed == null) return;
  await CheckinActionQueue.enqueue(
    part: parsed.$1,
    value: parsed.$2,
    at: DateTime.now(),
  );
}

/// `ci_energy_3` → `('morning', 3)`. Null when the id isn't ours.
(String, int)? parseCheckinActionId(String actionId) {
  String? part;
  if (actionId.startsWith(CheckinActionQueue.morningPrefix)) {
    part = 'morning';
  } else if (actionId.startsWith(CheckinActionQueue.eveningPrefix)) {
    part = 'evening';
  }
  if (part == null) return null;
  final v = int.tryParse(actionId.split('_').last);
  if (v == null || v < 1 || v > 5) return null;
  return (part, v);
}
