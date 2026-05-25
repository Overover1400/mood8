import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/badge_category.dart';
import '../models/chat_message.dart';
import '../models/earned_badge.dart';
import '../models/focus_area.dart';
import '../models/frequency.dart';
import '../models/gratitude_entry.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/habit_polarity.dart';
import '../models/habit_type.dart';
import '../models/insight.dart';
import '../models/insight_type.dart';
import '../models/mood_entry.dart';
import '../models/morning_intention.dart';
import '../models/pattern_alert.dart';
import '../models/reflection.dart';
import '../models/reminder_settings.dart';
import '../models/routine_category.dart';
import '../models/routine_item.dart';
import '../models/user_profile.dart';
import '../models/weekly_recap.dart';
import 'auth_service.dart';
import 'database_service.dart';

/// Two-way cloud sync over a generic JSONB store on the server. Every
/// supported entity has a [_EntityCodec] that knows how to:
///   • iterate its Hive box
///   • derive a stable id + last-edited timestamp
///   • round-trip the model to/from a JSON map
///
/// Conflict resolution is **last-write-wins by `updatedAt`**, server-side.
/// Deletions are tombstoned in a sidecar `sync_tombstones` Hive box (so
/// we don't need to touch every model with a `deleted` field) and pushed
/// as `deleted=true` rows. Server returns deletion rows on pull too,
/// which the client applies as Hive deletes.
class SyncService extends ChangeNotifier {
  SyncService._();
  static final SyncService _instance = SyncService._();
  factory SyncService() => _instance;

  static const String _baseUrl = 'https://mood8.app/api';
  static const Duration _timeout = Duration(seconds: 30);
  static const String _kLastSyncKey = 'mood8.sync.lastSyncIso';
  static const String _kInitialPushDoneKey =
      'mood8.sync.initialPushDone';
  static const String _kTombstoneBoxName = 'sync_tombstones';

  final http.Client _client = http.Client();
  final Uuid _uuid = const Uuid();

  Box<String> get _tombstones =>
      Hive.box<String>(_kTombstoneBoxName);

  /// Lazily-opened tombstone box. Call once on app boot from main().
  static Future<void> warmUp() async {
    if (!Hive.isBoxOpen(_kTombstoneBoxName)) {
      await Hive.openBox<String>(_kTombstoneBoxName);
    }
  }

  // ─── Status (light) ─────────────────────────────────────────────────

  Timer? _periodicTimer;
  Timer? _pushDebounce;
  bool _syncing = false;
  bool get isSyncing => _syncing;

  String? _bearer() => AuthService().token;

  Map<String, String> _authHeaders() => {
        'content-type': 'application/json',
        if (_bearer() != null) 'authorization': 'Bearer ${_bearer()}',
      };

  // ─── Tombstones ─────────────────────────────────────────────────────

  /// Records a soft-delete. Call this BEFORE removing the row from its
  /// own Hive box so we have the entity_type+id to send to the server.
  Future<void> recordTombstone(String entityType, String entityId) async {
    try {
      final key = '$entityType|$entityId';
      await _tombstones.put(key, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('[Sync] recordTombstone failed: $e');
    }
  }

  // ─── Push ───────────────────────────────────────────────────────────

  Future<void> pushChanges() async {
    if (_bearer() == null) return;
    if (_syncing) return;
    _syncing = true;
    try {
      final changes = <Map<String, dynamic>>[];
      final lastSync = await _lastSyncAt();
      // Walk every entity type. Push rows whose effective updatedAt is
      // newer than lastSync (or always on first run if lastSync is null).
      for (final codec in _codecs) {
        for (final pair in codec.iterateChanged(lastSync)) {
          changes.add({
            'entity_type': codec.entityType,
            'entity_id': pair.id,
            'payload': pair.json,
            'updated_at': pair.updatedAt.toUtc().toIso8601String(),
            'deleted': false,
          });
        }
      }
      // Tombstones.
      for (final k in _tombstones.keys.cast<String>()) {
        final iso = _tombstones.get(k);
        if (iso == null) continue;
        final parts = k.split('|');
        if (parts.length < 2) continue;
        changes.add({
          'entity_type': parts[0],
          'entity_id': parts[1],
          'payload': const <String, dynamic>{},
          'updated_at': iso,
          'deleted': true,
        });
      }
      if (changes.isEmpty) {
        debugPrint('[Sync] pushChanges → nothing to send');
        return;
      }
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/sync/push'),
            headers: _authHeaders(),
            body: jsonEncode({'changes': changes}),
          )
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('[Sync] push ${res.statusCode}: ${res.body}');
        return;
      }
      // On success, clear tombstones we just sent.
      for (final k in _tombstones.keys.cast<String>().toList()) {
        await _tombstones.delete(k);
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      debugPrint(
          '[Sync] pushed · accepted=${body['accepted']} · skipped=${body['skipped']}');
    } on TimeoutException {
      debugPrint('[Sync] push timeout');
    } catch (e) {
      debugPrint('[Sync] push error: $e');
    } finally {
      _syncing = false;
    }
  }

  // ─── Pull ───────────────────────────────────────────────────────────

  Future<int> pullChanges() async {
    if (_bearer() == null) return 0;
    try {
      final last = await _lastSyncAt();
      final qs = last != null ? '?since=${Uri.encodeQueryComponent(last.toIso8601String())}' : '';
      final res = await _client
          .get(
            Uri.parse('$_baseUrl/sync/pull$qs'),
            headers: _authHeaders(),
          )
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('[Sync] pull ${res.statusCode}: ${res.body}');
        return 0;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['changes'] as List?) ?? const [];
      final applied = await _applyServerChanges(list);
      final serverTime = body['server_time'] as String?;
      if (serverTime != null) await _setLastSyncIso(serverTime);
      debugPrint('[Sync] pulled · applied=$applied');
      return applied;
    } on TimeoutException {
      debugPrint('[Sync] pull timeout');
      return 0;
    } catch (e) {
      debugPrint('[Sync] pull error: $e');
      return 0;
    }
  }

  /// Pulls every non-deleted row for this user — used after fresh-install
  /// login. Wipes local boxes for each known entity type first so we
  /// don't leave behind stale records from a previous account.
  Future<int> fullRestore() async {
    if (_bearer() == null) return 0;
    try {
      final res = await _client
          .post(
            Uri.parse('$_baseUrl/sync/full-restore'),
            headers: _authHeaders(),
          )
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('[Sync] full-restore ${res.statusCode}: ${res.body}');
        return 0;
      }
      // Best-effort clear of synced boxes so a different account's stale
      // state on this device doesn't shadow what's coming from the server.
      for (final codec in _codecs) {
        try {
          await codec.clearBox();
        } catch (_) {}
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final list = (body['changes'] as List?) ?? const [];
      final applied = await _applyServerChanges(list);
      final serverTime = body['server_time'] as String?;
      if (serverTime != null) await _setLastSyncIso(serverTime);
      // After a successful full-restore we've also handled any historic
      // backfill, so mark the initial push as done.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kInitialPushDoneKey, true);
      debugPrint('[Sync] full-restored · applied=$applied');
      return applied;
    } on TimeoutException {
      debugPrint('[Sync] full-restore timeout');
      return 0;
    } catch (e) {
      debugPrint('[Sync] full-restore error: $e');
      return 0;
    }
  }

  Future<int> _applyServerChanges(List<dynamic> rows) async {
    var applied = 0;
    for (final raw in rows) {
      if (raw is! Map) continue;
      final r = Map<String, dynamic>.from(raw);
      final type = r['entity_type'] as String?;
      final id = r['entity_id'] as String?;
      final deleted = r['deleted'] as bool? ?? false;
      final payload = r['payload'] as Map?;
      if (type == null || id == null) continue;
      final codec = _codecByType[type];
      if (codec == null) {
        debugPrint('[Sync] unknown entity_type $type — skipping');
        continue;
      }
      try {
        if (deleted) {
          await codec.deleteById(id);
        } else if (payload != null) {
          await codec.upsertFromJson(
              id, Map<String, dynamic>.from(payload));
        }
        applied++;
      } catch (e, st) {
        debugPrint('[Sync] apply $type/$id failed: $e\n$st');
      }
    }
    return applied;
  }

  // ─── Lifecycle ──────────────────────────────────────────────────────

  /// Combined push + pull. Used periodically and on resume.
  Future<void> syncNow() async {
    await pushChanges();
    await pullChanges();
  }

  /// Returns true if Hive has any synced user data locally. Used to
  /// distinguish "fresh install" from "existing session" at login.
  bool hasLocalUserData() {
    for (final codec in _codecs) {
      if (codec.countRows() > 0) return true;
    }
    return false;
  }

  /// One-time migration for existing beta testers who already had local
  /// data before sync shipped. Uploads everything to the server, then
  /// marks the flag so we never do it again.
  Future<void> migrateInitialUploadIfNeeded() async {
    if (_bearer() == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kInitialPushDoneKey) ?? false) return;
      if (!hasLocalUserData()) {
        // Nothing local → not a migration, just a fresh signed-in user.
        await prefs.setBool(_kInitialPushDoneKey, true);
        return;
      }
      // Force "everything is newer than nothing" by clearing lastSync.
      await prefs.remove(_kLastSyncKey);
      await pushChanges();
      await prefs.setBool(_kInitialPushDoneKey, true);
      debugPrint('[Sync] initial upload migration complete');
    } catch (e) {
      debugPrint('[Sync] migrate initial upload failed: $e');
    }
  }

  void startPeriodicSync({Duration interval = const Duration(minutes: 2)}) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) => syncNow());
  }

  void stopPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Coalesce many rapid writes into a single push.
  void debouncedPush({
    Duration delay = const Duration(seconds: 5),
  }) {
    _pushDebounce?.cancel();
    _pushDebounce = Timer(delay, () {
      // ignore: discarded_futures
      pushChanges();
    });
  }

  // ─── lastSyncAt ─────────────────────────────────────────────────────

  Future<DateTime?> _lastSyncAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kLastSyncKey);
      if (raw == null) return null;
      return DateTime.tryParse(raw);
    } catch (_) {
      return null;
    }
  }

  Future<void> _setLastSyncIso(String iso) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLastSyncKey, iso);
    } catch (_) {}
  }

  // ─── Codec registry ─────────────────────────────────────────────────

  late final List<_EntityCodec> _codecs = [
    _MoodEntryCodec(),
    _RoutineItemCodec(),
    _UserProfileCodec(),
    _ReflectionCodec(),
    _ChatMessageCodec(),
    _HabitCodec(),
    _HabitLogCodec(),
    _InsightCodec(),
    _MorningIntentionCodec(),
    _GratitudeEntryCodec(),
    _EarnedBadgeCodec(),
    _WeeklyRecapCodec(),
    _PatternAlertCodec(),
    _ReminderSettingsCodec(),
  ];

  late final Map<String, _EntityCodec> _codecByType = {
    for (final c in _codecs) c.entityType: c,
  };

  /// Stamp `updatedAt = now()` on a synced model. Convenience for repos.
  DateTime stampNow() => DateTime.now();

  Uuid get uuid => _uuid;
}

// ─── Codec interface ───────────────────────────────────────────────────

class _Change {
  _Change({required this.id, required this.updatedAt, required this.json});
  final String id;
  final DateTime updatedAt;
  final Map<String, dynamic> json;
}

abstract class _EntityCodec {
  String get entityType;

  /// Returns rows whose effective updatedAt is strictly > [since].
  /// If [since] is null, returns everything (initial upload).
  Iterable<_Change> iterateChanged(DateTime? since);

  /// Idempotent upsert: write [id] from a server JSON map.
  Future<void> upsertFromJson(String id, Map<String, dynamic> json);

  /// Apply a server-side delete.
  Future<void> deleteById(String id);

  /// Number of rows currently in the local box.
  int countRows();

  /// Wipe the local box (used before [fullRestore] hydration).
  Future<void> clearBox();
}

// ─── Helpers ───────────────────────────────────────────────────────────

DateTime _coalesce(DateTime? a, [DateTime? b, DateTime? c]) =>
    a ?? b ?? c ?? DateTime.now();

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

String _iso(DateTime d) => d.toUtc().toIso8601String();

/// Serialise a HabitLog day-key as a TZ-free date string ("yyyy-MM-dd"),
/// so a round-trip through the server doesn't shift the day for
/// non-UTC users. Use this only for fields that are semantically a
/// CALENDAR DAY (not an instant) — e.g. `HabitLog.date`.
String _dateOnlyString(DateTime d) {
  final local = d.isUtc ? d.toLocal() : d;
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// Inverse of [_dateOnlyString]. Accepts the new date-only payload
/// AND legacy full-ISO payloads (so rows written before this fix
/// hydrate correctly): for legacy strings, normalise to the local
/// calendar day to undo the prior UTC-conversion bug.
DateTime? _parseDateOnly(dynamic v) {
  if (v is! String || v.isEmpty) return null;
  final dateMatch = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(v);
  if (dateMatch != null) {
    return DateTime(
      int.parse(dateMatch.group(1)!),
      int.parse(dateMatch.group(2)!),
      int.parse(dateMatch.group(3)!),
    );
  }
  final parsed = DateTime.tryParse(v);
  if (parsed == null) return null;
  return _localMidnight(parsed);
}

/// Extract the LOCAL calendar day from any DateTime (UTC-flagged or
/// not) and return midnight in local time. The undo-the-UTC-shift
/// step for legacy payloads.
DateTime _localMidnight(DateTime d) {
  final local = d.isUtc ? d.toLocal() : d;
  return DateTime(local.year, local.month, local.day);
}

// ─── MoodEntry codec ───────────────────────────────────────────────────

class _MoodEntryCodec implements _EntityCodec {
  @override
  String get entityType => 'mood_entry';
  Box<MoodEntry> get _box => DatabaseService.instance.moodBox;

  @override
  int countRows() => _box.length;

  @override
  Future<void> clearBox() async => _box.clear();

  @override
  Iterable<_Change> iterateChanged(DateTime? since) sync* {
    for (final e in _box.values) {
      final upd = _coalesce(e.updatedAt, e.timestamp);
      if (since == null || upd.isAfter(since)) {
        yield _Change(id: e.id, updatedAt: upd, json: {
          'id': e.id,
          'timestamp': _iso(e.timestamp),
          'mood': e.mood,
          'energy': e.energy,
          'focus': e.focus,
          'note': e.note,
          'updatedAt': _iso(upd),
        });
      }
    }
  }

  @override
  Future<void> upsertFromJson(String id, Map<String, dynamic> json) async {
    final entry = MoodEntry(
      id: id,
      timestamp:
          _parseDate(json['timestamp']) ?? DateTime.now(),
      mood: (json['mood'] as num?)?.toDouble() ?? 5.0,
      energy: (json['energy'] as num?)?.toDouble() ?? 5.0,
      focus: (json['focus'] as num?)?.toDouble() ?? 5.0,
      note: json['note'] as String?,
      updatedAt: _parseDate(json['updatedAt']),
    );
    await _box.put(id, entry);
  }

  @override
  Future<void> deleteById(String id) async => _box.delete(id);
}

// ─── RoutineItem codec ─────────────────────────────────────────────────

class _RoutineItemCodec implements _EntityCodec {
  @override
  String get entityType => 'routine_item';
  Box<RoutineItem> get _box => DatabaseService.instance.routineBox;

  @override
  int countRows() => _box.length;

  @override
  Future<void> clearBox() async => _box.clear();

  @override
  Iterable<_Change> iterateChanged(DateTime? since) sync* {
    for (final r in _box.values) {
      final upd = _coalesce(r.updatedAt, r.completedAt, r.time);
      if (since == null || upd.isAfter(since)) {
        yield _Change(id: r.id, updatedAt: upd, json: {
          'id': r.id,
          'title': r.title,
          'time': _iso(r.time),
          'durationMinutes': r.durationMinutes,
          'category': r.category.name,
          'meta': r.meta,
          'isCompleted': r.isCompleted,
          'completedAt':
              r.completedAt != null ? _iso(r.completedAt!) : null,
          'sortOrder': r.sortOrder,
          'frozenDates': r.frozenDates.map(_iso).toList(),
          'updatedAt': _iso(upd),
        });
      }
    }
  }

  @override
  Future<void> upsertFromJson(String id, Map<String, dynamic> json) async {
    final cat = RoutineCategory.values.firstWhere(
      (c) => c.name == (json['category'] ?? 'work'),
      orElse: () => RoutineCategory.work,
    );
    final frozenList = (json['frozenDates'] as List?)
            ?.map((e) => _parseDate(e))
            .whereType<DateTime>()
            .toList() ??
        const <DateTime>[];
    final item = RoutineItem(
      id: id,
      title: json['title'] as String? ?? '',
      time: _parseDate(json['time']) ?? DateTime.now(),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 30,
      category: cat,
      meta: json['meta'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
      completedAt: _parseDate(json['completedAt']),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      frozenDates: frozenList,
      updatedAt: _parseDate(json['updatedAt']),
    );
    await _box.put(id, item);
  }

  @override
  Future<void> deleteById(String id) async => _box.delete(id);
}

// ─── UserProfile codec ─────────────────────────────────────────────────

class _UserProfileCodec implements _EntityCodec {
  @override
  String get entityType => 'user_profile';
  Box<UserProfile> get _box => DatabaseService.instance.userBox;
  static const String _key = 'me';

  @override
  int countRows() => _box.length;

  @override
  Future<void> clearBox() async => _box.clear();

  @override
  Iterable<_Change> iterateChanged(DateTime? since) sync* {
    final p = _box.get(_key);
    if (p == null) return;
    final upd = _coalesce(p.updatedAt, p.createdAt);
    if (since == null || upd.isAfter(since)) {
      yield _Change(id: _key, updatedAt: upd, json: {
        'name': p.name,
        'identities': p.identities,
        'focusAreas': p.focusAreas.map((f) => f.name).toList(),
        'hasCompletedOnboarding': p.hasCompletedOnboarding,
        'createdAt': _iso(p.createdAt),
        'chronotype': p.chronotype.name,
        'freezesAvailable': p.freezesAvailable,
        'lastFreezeReplenish': p.lastFreezeReplenish != null
            ? _iso(p.lastFreezeReplenish!)
            : null,
        'totalFreezesUsed': p.totalFreezesUsed,
        'tutorialCompleted': p.tutorialCompleted,
        'updatedAt': _iso(upd),
      });
    }
  }

  @override
  Future<void> upsertFromJson(String id, Map<String, dynamic> json) async {
    final focusAreaNames = (json['focusAreas'] as List?)?.cast<String>() ??
        const <String>[];
    final focusAreas = <FocusArea>[
      for (final n in focusAreaNames)
        FocusArea.values.firstWhere(
          (f) => f.name == n,
          orElse: () => FocusArea.health,
        ),
    ];
    final chrono = Chronotype.values.firstWhere(
      (c) => c.name == (json['chronotype'] ?? 'balanced'),
      orElse: () => Chronotype.balanced,
    );
    final existing = _box.get(_key);
    final profile = UserProfile(
      name: json['name'] as String? ?? 'friend',
      identities:
          (json['identities'] as List?)?.cast<String>() ?? const <String>[],
      focusAreas: focusAreas,
      hasCompletedOnboarding:
          json['hasCompletedOnboarding'] as bool? ?? true,
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      chronotype: chrono,
      freezesAvailable: (json['freezesAvailable'] as num?)?.toInt(),
      lastFreezeReplenish: _parseDate(json['lastFreezeReplenish']),
      totalFreezesUsed: (json['totalFreezesUsed'] as num?)?.toInt(),
      updatedAt: _parseDate(json['updatedAt']),
      // Sticky: once true on either side, stays true. The server is
      // canonical only as a "yes already seen" signal — we don't want
      // to un-complete the tutorial for a user whose local state has
      // it true but whose server row hasn't received the push yet.
      tutorialCompleted: (json['tutorialCompleted'] as bool? ?? false) ||
          (existing?.tutorialCompleted ?? false),
    );
    await _box.put(_key, profile);
    // After a remote pull marks the user as tutorial-completed,
    // hydrate the device-local SharedPreferences cache so the next
    // app launch on this device skips the tutorial too.
    if (profile.tutorialCompleted) {
      await _hydrateTutorialPref();
    }
  }

  Future<void> _hydrateTutorialPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('tutorial_completed', true);
    } catch (_) {/* best-effort */}
  }

  @override
  Future<void> deleteById(String id) async => _box.delete(_key);
}

// ─── Reflection codec ──────────────────────────────────────────────────

class _ReflectionCodec implements _EntityCodec {
  @override
  String get entityType => 'reflection';
  Box<Reflection> get _box => DatabaseService.instance.reflectionBox;

  @override
  int countRows() => _box.length;

  @override
  Future<void> clearBox() async => _box.clear();

  @override
  Iterable<_Change> iterateChanged(DateTime? since) sync* {
    for (final r in _box.values) {
      final upd = _coalesce(r.updatedAt, r.generatedAt);
      if (since == null || upd.isAfter(since)) {
        yield _Change(id: r.id, updatedAt: upd, json: {
          'id': r.id,
          'date': _iso(r.date),
          'reflection': r.reflection,
          'suggestion': r.suggestion,
          'generatedAt': _iso(r.generatedAt),
          'identityScores': r.identityScores,
          'updatedAt': _iso(upd),
        });
      }
    }
  }

  @override
  Future<void> upsertFromJson(String id, Map<String, dynamic> json) async {
    Map<String, double>? scores;
    final raw = json['identityScores'];
    if (raw is Map) {
      scores = <String, double>{};
      raw.forEach((k, v) {
        if (k is String && v is num) scores![k] = v.toDouble();
      });
    }
    final r = Reflection(
      id: id,
      date: _parseDate(json['date']) ?? DateTime.now(),
      reflection: json['reflection'] as String? ?? '',
      generatedAt:
          _parseDate(json['generatedAt']) ?? DateTime.now(),
      suggestion: json['suggestion'] as String?,
      identityScores: scores,
      updatedAt: _parseDate(json['updatedAt']),
    );
    await _box.put(id, r);
  }

  @override
  Future<void> deleteById(String id) async => _box.delete(id);
}

// ─── ChatMessage codec ─────────────────────────────────────────────────

class _ChatMessageCodec implements _EntityCodec {
  @override
  String get entityType => 'chat_message';
  Box<ChatMessage> get _box => DatabaseService.instance.chatBox;

  @override
  int countRows() => _box.length;

  @override
  Future<void> clearBox() async => _box.clear();

  @override
  Iterable<_Change> iterateChanged(DateTime? since) sync* {
    for (final m in _box.values) {
      final upd = _coalesce(m.updatedAt, m.timestamp);
      if (since == null || upd.isAfter(since)) {
        yield _Change(id: m.id, updatedAt: upd, json: {
          'id': m.id,
          'role': m.role,
          'content': m.content,
          'timestamp': _iso(m.timestamp),
          'conversationId': m.conversationId,
          'updatedAt': _iso(upd),
        });
      }
    }
  }

  @override
  Future<void> upsertFromJson(String id, Map<String, dynamic> json) async {
    final m = ChatMessage(
      id: id,
      role: json['role'] as String? ?? 'assistant',
      content: json['content'] as String? ?? '',
      timestamp: _parseDate(json['timestamp']) ?? DateTime.now(),
      conversationId: json['conversationId'] as String? ?? 'default',
      updatedAt: _parseDate(json['updatedAt']),
    );
    await _box.put(id, m);
  }

  @override
  Future<void> deleteById(String id) async => _box.delete(id);
}

// ─── Habit codec ───────────────────────────────────────────────────────

class _HabitCodec implements _EntityCodec {
  @override
  String get entityType => 'habit';
  Box<Habit> get _box => DatabaseService.instance.habitBox;

  @override
  int countRows() => _box.length;

  @override
  Future<void> clearBox() async => _box.clear();

  @override
  Iterable<_Change> iterateChanged(DateTime? since) sync* {
    for (final h in _box.values) {
      final upd = _coalesce(h.updatedAt, h.createdAt);
      if (since == null || upd.isAfter(since)) {
        yield _Change(id: h.id, updatedAt: upd, json: {
          'id': h.id,
          'title': h.title,
          'description': h.description,
          'icon': h.icon,
          'habitType': h.habitType.name,
          'targetValue': h.targetValue,
          'targetUnit': h.targetUnit,
          'identity': h.identity,
          'category': h.category.name,
          'frequency': h.frequency.name,
          'frequencyDays': h.frequencyDays,
          'color': h.color,
          'createdAt': _iso(h.createdAt),
          'sortOrder': h.sortOrder,
          'isArchived': h.isArchived,
          'frozenDates': h.frozenDates.map(_iso).toList(),
          'updatedAt': _iso(upd),
          'polarity': h.polarity.name,
          'avoidMode': h.avoidMode?.name,
          'avoidDurationDays': h.avoidDurationDays,
          'packageId': h.packageId,
        });
      }
    }
  }

  @override
  Future<void> upsertFromJson(String id, Map<String, dynamic> json) async {
    final ht = HabitType.values.firstWhere(
      (t) => t.name == (json['habitType'] ?? 'yesNo'),
      orElse: () => HabitType.yesNo,
    );
    final cat = RoutineCategory.values.firstWhere(
      (c) => c.name == (json['category'] ?? 'work'),
      orElse: () => RoutineCategory.work,
    );
    final freq = Frequency.values.firstWhere(
      (f) => f.name == (json['frequency'] ?? 'daily'),
      orElse: () => Frequency.daily,
    );
    final frozenList = (json['frozenDates'] as List?)
            ?.map((e) => _parseDate(e))
            .whereType<DateTime>()
            .toList() ??
        const <DateTime>[];
    final polarity = HabitPolarity.values.firstWhere(
      (p) => p.name == (json['polarity'] ?? 'build'),
      orElse: () => HabitPolarity.build,
    );
    final avoidModeName = json['avoidMode'] as String?;
    final avoidMode = avoidModeName == null
        ? null
        : AvoidMode.values.firstWhere(
            (m) => m.name == avoidModeName,
            orElse: () => AvoidMode.quit,
          );
    final h = Habit(
      id: id,
      title: json['title'] as String? ?? '',
      icon: json['icon'] as String? ?? '✅',
      habitType: ht,
      identity: json['identity'] as String? ?? '',
      category: cat,
      frequency: freq,
      color: (json['color'] as num?)?.toInt() ?? 0xFFA855F7,
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      description: json['description'] as String?,
      targetValue: (json['targetValue'] as num?)?.toInt(),
      targetUnit: json['targetUnit'] as String?,
      frequencyDays:
          (json['frequencyDays'] as List?)?.cast<int>(),
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      isArchived: json['isArchived'] as bool? ?? false,
      frozenDates: frozenList,
      updatedAt: _parseDate(json['updatedAt']),
      polarity: polarity,
      avoidMode: avoidMode,
      avoidDurationDays: (json['avoidDurationDays'] as num?)?.toInt(),
      packageId: json['packageId'] as String?,
    );
    await _box.put(id, h);
  }

  @override
  Future<void> deleteById(String id) async => _box.delete(id);
}

// ─── HabitLog codec ────────────────────────────────────────────────────

class _HabitLogCodec implements _EntityCodec {
  @override
  String get entityType => 'habit_log';
  Box<HabitLog> get _box => DatabaseService.instance.habitLogBox;

  @override
  int countRows() => _box.length;

  @override
  Future<void> clearBox() async => _box.clear();

  @override
  Iterable<_Change> iterateChanged(DateTime? since) sync* {
    for (final l in _box.values) {
      final upd = _coalesce(l.updatedAt, l.timestamp);
      if (since == null || upd.isAfter(since)) {
        yield _Change(id: l.id, updatedAt: upd, json: {
          'id': l.id,
          'habitId': l.habitId,
          // CRITICAL: emit the LOCAL date as a date-only string. The
          // previous `_iso(l.date)` converted the local-midnight
          // DateTime to UTC, so a user in UTC+3 sent "<yesterday>T21:00Z"
          // for today's log. On pull, `DateTime.tryParse` rebuilt a UTC
          // DateTime whose year/month/day components landed on YESTERDAY,
          // and `_findLog(today)` couldn't match it — every counter
          // appeared to reset to 0 on every app start. Storing as the
          // local date string sidesteps any TZ math entirely.
          'date': _dateOnlyString(l.date),
          'value': l.value,
          'targetValue': l.targetValue,
          'note': l.note,
          'timestamp': _iso(l.timestamp),
          'updatedAt': _iso(upd),
        });
      }
    }
  }

  @override
  Future<void> upsertFromJson(String id, Map<String, dynamic> json) async {
    final newDate =
        _parseDateOnly(json['date']) ?? _localMidnight(DateTime.now());
    final newUpdatedAt = _parseDate(json['updatedAt']);
    // Last-write-wins guard. The previous codec unconditionally
    // overwrote the local row with whatever the server returned —
    // that's what let pull corrupt today's row even when local was
    // fresher. Only replace if the server's stamp is strictly newer.
    final existing = _box.get(id);
    if (existing != null && newUpdatedAt != null) {
      final localStamp = existing.updatedAt ?? existing.timestamp;
      if (!newUpdatedAt.isAfter(localStamp)) {
        return;
      }
    }
    final l = HabitLog(
      id: id,
      habitId: json['habitId'] as String? ?? '',
      date: newDate,
      value: (json['value'] as num?)?.toInt() ?? 0,
      targetValue: (json['targetValue'] as num?)?.toInt() ?? 1,
      timestamp: _parseDate(json['timestamp']) ?? DateTime.now(),
      note: json['note'] as String?,
      updatedAt: newUpdatedAt,
    );
    await _box.put(id, l);
  }

  @override
  Future<void> deleteById(String id) async => _box.delete(id);
}

// ─── Insight codec ─────────────────────────────────────────────────────

class _InsightCodec implements _EntityCodec {
  @override
  String get entityType => 'insight';
  Box<Insight> get _box => DatabaseService.instance.insightBox;

  @override
  int countRows() => _box.length;

  @override
  Future<void> clearBox() async => _box.clear();

  @override
  Iterable<_Change> iterateChanged(DateTime? since) sync* {
    for (final i in _box.values) {
      final upd = _coalesce(i.updatedAt, i.discoveredAt);
      if (since == null || upd.isAfter(since)) {
        yield _Change(id: i.id, updatedAt: upd, json: {
          'id': i.id,
          'type': i.type.name,
          'title': i.title,
          'description': i.description,
          'confidence': i.confidence,
          'effectSize': i.effectSize,
          'sampleSize': i.sampleSize,
          'relatedHabitId': i.relatedHabitId,
          'relatedIdentity': i.relatedIdentity,
          'actionable': i.actionable,
          'actionText': i.actionText,
          'aiExplanation': i.aiExplanation,
          'discoveredAt': _iso(i.discoveredAt),
          'dismissed': i.dismissed,
          'updatedAt': _iso(upd),
        });
      }
    }
  }

  @override
  Future<void> upsertFromJson(String id, Map<String, dynamic> json) async {
    final type = InsightType.values.firstWhere(
      (t) => t.name == (json['type'] ?? 'moodHabitCorrelation'),
      orElse: () => InsightType.habitImpact,
    );
    final i = Insight(
      id: id,
      type: type,
      title: json['title'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      effectSize: (json['effectSize'] as num?)?.toDouble() ?? 0.0,
      sampleSize: (json['sampleSize'] as num?)?.toInt() ?? 0,
      discoveredAt:
          _parseDate(json['discoveredAt']) ?? DateTime.now(),
      description: json['description'] as String?,
      relatedHabitId: json['relatedHabitId'] as String?,
      relatedIdentity: json['relatedIdentity'] as String?,
      actionable: json['actionable'] as bool? ?? false,
      actionText: json['actionText'] as String?,
      aiExplanation: json['aiExplanation'] as String?,
      dismissed: json['dismissed'] as bool? ?? false,
      updatedAt: _parseDate(json['updatedAt']),
    );
    await _box.put(id, i);
  }

  @override
  Future<void> deleteById(String id) async => _box.delete(id);
}

// ─── MorningIntention codec ────────────────────────────────────────────

class _MorningIntentionCodec implements _EntityCodec {
  @override
  String get entityType => 'morning_intention';
  Box<MorningIntention> get _box =>
      DatabaseService.instance.intentionBox;

  @override
  int countRows() => _box.length;

  @override
  Future<void> clearBox() async => _box.clear();

  @override
  Iterable<_Change> iterateChanged(DateTime? since) sync* {
    for (final m in _box.values) {
      final upd = _coalesce(m.updatedAt, m.createdAt);
      if (since == null || upd.isAfter(since)) {
        yield _Change(id: m.id, updatedAt: upd, json: {
          'id': m.id,
          'date': _iso(m.date),
          'text': m.text,
          'createdAt': _iso(m.createdAt),
          'wasSkipped': m.wasSkipped,
          'updatedAt': _iso(upd),
        });
      }
    }
  }

  @override
  Future<void> upsertFromJson(String id, Map<String, dynamic> json) async {
    final m = MorningIntention(
      id: id,
      date: _parseDate(json['date']) ?? DateTime.now(),
      text: json['text'] as String? ?? '',
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      wasSkipped: json['wasSkipped'] as bool? ?? false,
      updatedAt: _parseDate(json['updatedAt']),
    );
    await _box.put(id, m);
  }

  @override
  Future<void> deleteById(String id) async => _box.delete(id);
}

// ─── GratitudeEntry codec ──────────────────────────────────────────────

class _GratitudeEntryCodec implements _EntityCodec {
  @override
  String get entityType => 'gratitude_entry';
  Box<GratitudeEntry> get _box =>
      DatabaseService.instance.gratitudeBox;

  @override
  int countRows() => _box.length;

  @override
  Future<void> clearBox() async => _box.clear();

  @override
  Iterable<_Change> iterateChanged(DateTime? since) sync* {
    for (final g in _box.values) {
      final upd = _coalesce(g.updatedAt, g.createdAt);
      if (since == null || upd.isAfter(since)) {
        yield _Change(id: g.id, updatedAt: upd, json: {
          'id': g.id,
          'date': _iso(g.date),
          'items': g.items,
          'createdAt': _iso(g.createdAt),
          'updatedAt': _iso(upd),
        });
      }
    }
  }

  @override
  Future<void> upsertFromJson(String id, Map<String, dynamic> json) async {
    final g = GratitudeEntry(
      id: id,
      date: _parseDate(json['date']) ?? DateTime.now(),
      items: (json['items'] as List?)?.cast<String>() ?? const <String>[],
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updatedAt']),
    );
    await _box.put(id, g);
  }

  @override
  Future<void> deleteById(String id) async => _box.delete(id);
}

// ─── EarnedBadge codec ─────────────────────────────────────────────────

class _EarnedBadgeCodec implements _EntityCodec {
  @override
  String get entityType => 'earned_badge';
  Box<EarnedBadge> get _box => DatabaseService.instance.badgeBox;

  @override
  int countRows() => _box.length;

  @override
  Future<void> clearBox() async => _box.clear();

  @override
  Iterable<_Change> iterateChanged(DateTime? since) sync* {
    for (final b in _box.values) {
      final upd = _coalesce(b.updatedAt, b.unlockedAt);
      if (since == null || upd.isAfter(since)) {
        yield _Change(id: b.id, updatedAt: upd, json: {
          'id': b.id,
          'badgeKey': b.badgeKey,
          'title': b.title,
          'description': b.description,
          'iconCode': b.iconCode,
          'colorHex': b.colorHex,
          'unlockedAt': _iso(b.unlockedAt),
          'category': b.category.name,
          'updatedAt': _iso(upd),
        });
      }
    }
  }

  @override
  Future<void> upsertFromJson(String id, Map<String, dynamic> json) async {
    final cat = BadgeCategory.values.firstWhere(
      (c) => c.name == (json['category'] ?? 'streak'),
      orElse: () => BadgeCategory.streak,
    );
    final b = EarnedBadge(
      id: id,
      badgeKey: json['badgeKey'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      iconCode: (json['iconCode'] as num?)?.toInt() ?? 0,
      colorHex: (json['colorHex'] as num?)?.toInt() ?? 0xFFA855F7,
      unlockedAt: _parseDate(json['unlockedAt']) ?? DateTime.now(),
      category: cat,
      updatedAt: _parseDate(json['updatedAt']),
    );
    await _box.put(id, b);
  }

  @override
  Future<void> deleteById(String id) async => _box.delete(id);
}

// ─── WeeklyRecap codec ─────────────────────────────────────────────────

class _WeeklyRecapCodec implements _EntityCodec {
  @override
  String get entityType => 'weekly_recap';
  Box<WeeklyRecap> get _box =>
      DatabaseService.instance.weeklyRecapBox;

  @override
  int countRows() => _box.length;

  @override
  Future<void> clearBox() async => _box.clear();

  @override
  Iterable<_Change> iterateChanged(DateTime? since) sync* {
    for (final r in _box.values) {
      final upd = _coalesce(r.updatedAt, r.generatedAt);
      if (since == null || upd.isAfter(since)) {
        yield _Change(id: r.id, updatedAt: upd, json: {
          'id': r.id,
          'weekStart': _iso(r.weekStart),
          'weekEnd': _iso(r.weekEnd),
          'narrative': r.narrative,
          'patterns': r.patterns,
          'lookingAhead': r.lookingAhead,
          'moodSummary': r.moodSummary,
          'gratitudeThemes': r.gratitudeThemes,
          'stats': r.stats,
          'generatedAt': _iso(r.generatedAt),
          'emailSent': r.emailSent,
          'updatedAt': _iso(upd),
        });
      }
    }
  }

  @override
  Future<void> upsertFromJson(String id, Map<String, dynamic> json) async {
    final r = WeeklyRecap(
      id: id,
      weekStart: _parseDate(json['weekStart']) ?? DateTime.now(),
      weekEnd: _parseDate(json['weekEnd']) ?? DateTime.now(),
      narrative: json['narrative'] as String? ?? '',
      patterns: (json['patterns'] as List?)?.cast<String>(),
      lookingAhead: json['lookingAhead'] as String? ?? '',
      moodSummary: json['moodSummary'] as String? ?? '',
      gratitudeThemes:
          (json['gratitudeThemes'] as List?)?.cast<String>(),
      stats: (json['stats'] as Map?)?.cast<String, dynamic>(),
      generatedAt:
          _parseDate(json['generatedAt']) ?? DateTime.now(),
      emailSent: json['emailSent'] as bool? ?? false,
      updatedAt: _parseDate(json['updatedAt']),
    );
    await _box.put(id, r);
  }

  @override
  Future<void> deleteById(String id) async => _box.delete(id);
}

// ─── PatternAlert codec ────────────────────────────────────────────────

class _PatternAlertCodec implements _EntityCodec {
  @override
  String get entityType => 'pattern_alert';
  Box<PatternAlert> get _box =>
      DatabaseService.instance.patternAlertBox;

  @override
  int countRows() => _box.length;

  @override
  Future<void> clearBox() async => _box.clear();

  @override
  Iterable<_Change> iterateChanged(DateTime? since) sync* {
    for (final a in _box.values) {
      final upd = _coalesce(a.updatedAt, a.detectedAt);
      if (since == null || upd.isAfter(since)) {
        yield _Change(id: a.id, updatedAt: upd, json: {
          'id': a.id,
          'category': a.category.name,
          'title': a.title,
          'body': a.body,
          'actionLabel': a.actionLabel,
          'actionRoute': a.actionRoute,
          'severity': a.severity.name,
          'detectedAt': _iso(a.detectedAt),
          'dismissedAt':
              a.dismissedAt != null ? _iso(a.dismissedAt!) : null,
          'viewedAt': a.viewedAt != null ? _iso(a.viewedAt!) : null,
          'relevanceScore': a.relevanceScore,
          'dedupeKey': a.dedupeKey,
          'updatedAt': _iso(upd),
        });
      }
    }
  }

  @override
  Future<void> upsertFromJson(String id, Map<String, dynamic> json) async {
    final cat = PatternCategory.values.firstWhere(
      (c) => c.name == (json['category'] ?? 'growth'),
      orElse: () => PatternCategory.growth,
    );
    final sev = PatternSeverity.values.firstWhere(
      (s) => s.name == (json['severity'] ?? 'neutral'),
      orElse: () => PatternSeverity.neutral,
    );
    final a = PatternAlert(
      id: id,
      category: cat,
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      severity: sev,
      detectedAt: _parseDate(json['detectedAt']) ?? DateTime.now(),
      relevanceScore:
          (json['relevanceScore'] as num?)?.toDouble() ?? 0.5,
      actionLabel: json['actionLabel'] as String?,
      actionRoute: json['actionRoute'] as String?,
      dismissedAt: _parseDate(json['dismissedAt']),
      viewedAt: _parseDate(json['viewedAt']),
      dedupeKey: json['dedupeKey'] as String?,
      updatedAt: _parseDate(json['updatedAt']),
    );
    await _box.put(id, a);
  }

  @override
  Future<void> deleteById(String id) async => _box.delete(id);
}

// ─── ReminderSettings codec ────────────────────────────────────────────

class _ReminderSettingsCodec implements _EntityCodec {
  @override
  String get entityType => 'reminder_settings';
  Box<ReminderSettings> get _box =>
      DatabaseService.instance.reminderSettingsBox;
  static const String _key = ReminderSettings.boxKey;

  @override
  int countRows() => _box.length;

  @override
  Future<void> clearBox() async => _box.clear();

  @override
  Iterable<_Change> iterateChanged(DateTime? since) sync* {
    final s = _box.get(_key);
    if (s == null) return;
    final upd = _coalesce(s.updatedAt);
    if (since == null || upd.isAfter(since)) {
      yield _Change(id: _key, updatedAt: upd, json: {
        'enabled': s.enabled,
        'reminderTimes': s.reminderTimes,
        'smartSkip': s.smartSkip,
        'quietHoursEnabled': s.quietHoursEnabled,
        'quietStart': s.quietStart,
        'quietEnd': s.quietEnd,
        'updatedAt': _iso(upd),
      });
    }
  }

  @override
  Future<void> upsertFromJson(String id, Map<String, dynamic> json) async {
    final s = ReminderSettings(
      enabled: json['enabled'] as bool?,
      reminderTimes:
          (json['reminderTimes'] as List?)?.cast<int>(),
      smartSkip: json['smartSkip'] as bool?,
      quietHoursEnabled: json['quietHoursEnabled'] as bool?,
      quietStart: (json['quietStart'] as num?)?.toInt(),
      quietEnd: (json['quietEnd'] as num?)?.toInt(),
      updatedAt: _parseDate(json['updatedAt']),
    );
    await _box.put(_key, s);
  }

  @override
  Future<void> deleteById(String id) async => _box.delete(_key);
}
