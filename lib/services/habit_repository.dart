import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/frequency.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/habit_polarity.dart';
import '../models/habit_type.dart';
import '../models/routine_category.dart';
import 'database_service.dart';
import 'sync_service.dart';

class HabitRepository {
  HabitRepository({DatabaseService? db})
      : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;
  final Uuid _uuid = const Uuid();

  Box<Habit> get _habitBox => _db.habitBox;
  Box<HabitLog> get _logBox => _db.habitLogBox;

  // ─── Shadow store (counter-loss bug fix) ─────────────────────────────
  //
  // Hive 2.x's IndexedDB backend on web has a hard reliability gap: each
  // `box.put` opens a brand-new readwrite transaction, and the Future
  // returned by `put` resolves as soon as the request succeeds — NOT
  // when the transaction commits. The transaction commits later, when
  // the microtask queue drains. If the user backgrounds the PWA in
  // that gap (or the browser freezes the tab), the transaction is
  // aborted and the write is lost. `box.flush()` is a literal no-op on
  // web (`Future.value()`), so the previous "await flush()" fix did
  // nothing there.
  //
  // The shadow store mirrors every counter / yes-no write to
  // SharedPreferences. On web that's `window.localStorage`, which is
  // synchronous — by the time `setInt` returns the data is in DOM
  // storage and survives a tab freeze. On Android / iOS we still get
  // a fast native write that's much harder to lose than Hive's queue.
  //
  // On app start we hydrate the shadow into Hive: any key whose
  // shadow value disagrees with (or is missing from) Hive gets
  // replayed via `logHabit` so the box matches the durable record.

  static const _kShadowPrefix = 'mood8.todayLog.';

  /// Cached SharedPreferences instance — keep a reference so the
  /// shadow write inside `logHabit` doesn't have to re-await
  /// `getInstance()` on every tap.
  SharedPreferences? _prefs;

  /// Initialise the shadow store and replay any pending writes into
  /// Hive. Call this once at app start, AFTER `DatabaseService.init`.
  /// Safe to call multiple times.
  Future<void> ensureShadowReady() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _repairCorruptedDates();
    await _hydrateShadow();
  }

  /// One-shot migration that undoes the historical UTC-shift bug:
  /// any HabitLog whose `date` is flagged UTC OR whose date's local
  /// midnight doesn't match itself gets snapped back to the local
  /// calendar day. Runs every cold start (cheap — only rewrites
  /// rows that actually need rewriting) so existing accounts heal
  /// the first time they open the patched app.
  Future<void> _repairCorruptedDates() async {
    var repaired = 0;
    for (final l in _logBox.values.toList()) {
      final d = l.date;
      // A correctly-stored log has date == DateTime(y, m, d) in local
      // time. If it's UTC or has a non-zero time component, the prior
      // sync bug landed it on the wrong calendar day for this user.
      if (d.isUtc ||
          d.hour != 0 ||
          d.minute != 0 ||
          d.second != 0 ||
          d.millisecond != 0) {
        final local = d.isUtc ? d.toLocal() : d;
        l.date = DateTime(local.year, local.month, local.day);
        await _logBox.put(l.id, l);
        repaired += 1;
      }
    }
    if (repaired > 0) {
      debugPrint('[HabitLog] repaired $repaired UTC-shifted date(s)');
    }
  }

  String _shadowKey(String habitId, DateTime dayKey) {
    final d = '${dayKey.year}-${dayKey.month}-${dayKey.day}';
    return '$_kShadowPrefix$habitId|$d';
  }

  Future<void> _writeShadow(
      String habitId, DateTime dayKey, int value) async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs ??= prefs;
    try {
      await prefs.setInt(_shadowKey(habitId, dayKey), value);
    } catch (e) {
      debugPrint('[HabitRepository] shadow write failed: $e');
    }
  }

  Future<void> _hydrateShadow() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final keys =
        prefs.getKeys().where((k) => k.startsWith(_kShadowPrefix)).toList();
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    for (final key in keys) {
      // Format: mood8.todayLog.<habitId>|<yyyy-m-d>
      final rest = key.substring(_kShadowPrefix.length);
      final sep = rest.lastIndexOf('|');
      if (sep <= 0) continue;
      final habitId = rest.substring(0, sep);
      final dateStr = rest.substring(sep + 1);
      final dateParts = dateStr.split('-');
      if (dateParts.length != 3) continue;
      DateTime dayKey;
      try {
        dayKey = DateTime(
          int.parse(dateParts[0]),
          int.parse(dateParts[1]),
          int.parse(dateParts[2]),
        );
      } catch (_) {
        continue;
      }
      // Old shadows past the retention window get reaped so prefs
      // don't grow unbounded.
      if (dayKey.isBefore(cutoff)) {
        await prefs.remove(key);
        continue;
      }
      final shadowValue = prefs.getInt(key);
      if (shadowValue == null) continue;
      final existing = _findLog(habitId, dayKey);
      if (existing == null || existing.value != shadowValue) {
        debugPrint(
            '[HabitRepository] hydrating shadow: habit=$habitId day=$dayKey '
            'shadow=$shadowValue hive=${existing?.value}');
        // Write the shadow value through Hive. Pass _skipShadow=true
        // so we don't re-write the shadow we just read from.
        try {
          await _writeLog(
              habitId: habitId,
              value: shadowValue,
              date: dayKey,
              skipShadow: true);
        } catch (e) {
          debugPrint('[HabitRepository] hydrate failed for $habitId: $e');
        }
      }
    }
  }

  // ─── Habits ───────────────────────────────────────────────────────────

  Future<Habit> addHabit({
    required String title,
    required String icon,
    required HabitType habitType,
    required String identity,
    required RoutineCategory category,
    required Frequency frequency,
    int? targetValue,
    String? targetUnit,
    String? description,
    List<int>? frequencyDays,
    int? color,
    int? sortOrder,
    HabitPolarity polarity = HabitPolarity.build,
    AvoidMode? avoidMode,
    int? avoidDurationDays,
    String? packageId,
    bool aiManaged = false,
    String? goalDescription,
    int? programDurationDays,
  }) async {
    final habit = Habit(
      id: _uuid.v4(),
      title: title,
      icon: icon,
      habitType: habitType,
      identity: identity,
      category: category,
      frequency: frequency,
      color: color ?? category.color.toARGB32(),
      createdAt: DateTime.now(),
      description: description,
      targetValue: targetValue,
      targetUnit: targetUnit,
      frequencyDays: frequencyDays,
      sortOrder: sortOrder ?? _habitBox.length,
      updatedAt: DateTime.now(),
      polarity: polarity,
      avoidMode: avoidMode,
      avoidDurationDays: avoidDurationDays,
      packageId: packageId,
      aiManaged: aiManaged,
      goalDescription: goalDescription,
      programDurationDays: programDurationDays,
    );
    try {
      await _habitBox.put(habit.id, habit);
      SyncService().debouncedPush();
      // TODO(v2): re-enable habit reminders — see Mood8 v2 reminders work.
    } catch (e, st) {
      debugPrint('HabitRepository.addHabit failed: $e\n$st');
      rethrow;
    }
    return habit;
  }

  /// Materialise every item in [package] as a real Habit row tagged
  /// with the package id. Skips items whose title is already present
  /// in the same package (so calling startPackage twice doesn't dupe).
  /// Returns the list of habits actually created.
  Future<List<Habit>> startPackage(dynamic package) async {
    // Loose-typed `package` so this file doesn't pull the data layer
    // into the repo public API. Callers pass a HabitPackage.
    final id = package.id as String;
    final items = package.items as List<dynamic>;
    final existing = _habitBox.values
        .where((h) => h.packageId == id)
        .map((h) => h.title)
        .toSet();
    final created = <Habit>[];
    for (final item in items) {
      if (existing.contains(item.title as String)) continue;
      final h = await addHabit(
        title: item.title as String,
        icon: item.icon as String,
        habitType: item.habitType,
        identity: item.identity as String,
        category: item.category,
        frequency: item.frequency,
        targetValue: item.targetValue as int?,
        targetUnit: item.targetUnit as String?,
        polarity: item.polarity,
        avoidMode: item.avoidMode,
        avoidDurationDays: item.avoidDurationDays as int?,
        packageId: id,
      );
      created.add(h);
    }
    return created;
  }

  /// Distinct package ids of currently-active habits — used by the
  /// Habits screen to render a fancy filter chip per running program.
  List<String> activePackageIds() {
    final ids = <String>{};
    for (final h in _habitBox.values) {
      if (!h.isArchived && h.packageId != null) ids.add(h.packageId!);
    }
    return ids.toList();
  }

  /// True when the user has at least one AI-managed habit — drives
  /// the "Mood8 AI Habits" filter chip on the Habits screen.
  bool hasAnyAiManagedHabit() {
    for (final h in _habitBox.values) {
      if (!h.isArchived && h.aiManaged) return true;
    }
    return false;
  }

  Future<void> updateHabit(Habit habit) async {
    try {
      habit.updatedAt = DateTime.now();
      await _habitBox.put(habit.id, habit);
      SyncService().debouncedPush();
      // TODO(v2): re-enable habit reminders — see Mood8 v2 reminders work.
    } catch (e, st) {
      debugPrint('HabitRepository.updateHabit failed: $e\n$st');
      rethrow;
    }
  }

  Future<void> deleteHabit(String id) async {
    try {
      // TODO(v2): re-enable habit reminders — see Mood8 v2 reminders work.
      // Tombstone the habit and every log that belongs to it BEFORE the
      // Hive delete so sync can propagate the soft-delete to other devices.
      await SyncService().recordTombstone('habit', id);
      await _habitBox.delete(id);
      final logsToDelete = _logBox.values
          .where((l) => l.habitId == id)
          .toList();
      for (final l in logsToDelete) {
        await SyncService().recordTombstone('habit_log', l.id);
      }
      if (logsToDelete.isNotEmpty) {
        await _logBox.deleteAll(logsToDelete.map((l) => l.id));
      }
      SyncService().debouncedPush();
    } catch (e, st) {
      debugPrint('HabitRepository.deleteHabit failed: $e\n$st');
      rethrow;
    }
  }

  Future<void> archiveHabit(String id) async {
    final h = _habitBox.get(id);
    if (h == null) return;
    h.isArchived = true;
    h.updatedAt = DateTime.now();
    await h.save();
    SyncService().debouncedPush();
    // TODO(v2): re-enable habit reminders — see Mood8 v2 reminders work.
  }

  List<Habit> getAllHabits() {
    return _habitBox.values.toList()
      ..sort((a, b) {
        final c = a.sortOrder.compareTo(b.sortOrder);
        if (c != 0) return c;
        return a.createdAt.compareTo(b.createdAt);
      });
  }

  List<Habit> getActiveHabits() =>
      getAllHabits().where((h) => !h.isArchived).toList();

  List<Habit> getHabitsForIdentity(String identity) =>
      getActiveHabits().where((h) => h.identity == identity).toList();

  List<Habit> getHabitsForDate(DateTime date) =>
      getActiveHabits().where((h) => h.isScheduledFor(date)).toList();

  Future<void> reorderHabits(int oldIndex, int newIndex) async {
    final list = getActiveHabits();
    if (oldIndex < 0 || oldIndex >= list.length) return;
    final adjustedNew = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final moved = list.removeAt(oldIndex);
    list.insert(adjustedNew.clamp(0, list.length), moved);
    final now = DateTime.now();
    for (var i = 0; i < list.length; i++) {
      list[i].sortOrder = i;
      list[i].updatedAt = now;
      await list[i].save();
    }
    SyncService().debouncedPush();
  }

  ValueListenable<Box<Habit>> watchHabits() => _habitBox.listenable();
  ValueListenable<Box<HabitLog>> watchLogs() => _logBox.listenable();

  // ─── Logs ─────────────────────────────────────────────────────────────

  Future<HabitLog> logHabit({
    required String habitId,
    required int value,
    DateTime? date,
    String? note,
  }) =>
      _writeLog(
        habitId: habitId,
        value: value,
        date: date,
        note: note,
        skipShadow: false,
      );

  /// Inner write — separated from [logHabit] so the shadow-hydration
  /// path can replay a write without bouncing back to the shadow.
  Future<HabitLog> _writeLog({
    required String habitId,
    required int value,
    DateTime? date,
    String? note,
    required bool skipShadow,
  }) async {
    final habit = _habitBox.get(habitId);
    final target = habit?.effectiveTarget ?? 1;
    final on = _dayKey(date ?? DateTime.now());

    // SHADOW WRITE FIRST. SharedPreferences uses window.localStorage
    // on web (synchronous) and a native API on Android/iOS — both
    // far more reliable for fast-write-then-background than Hive
    // 2.x's IndexedDB transaction model. Do this BEFORE the Hive
    // write so the shadow is durable even if Hive's await throws.
    if (!skipShadow) {
      await _writeShadow(habitId, on, value);
    }

    final existing = _findLog(habitId, on);
    if (existing != null) {
      existing.value = value;
      existing.targetValue = target;
      existing.timestamp = DateTime.now();
      existing.updatedAt = DateTime.now();
      if (note != null) existing.note = note;
      await _logBox.put(existing.id, existing);
      await _logBox.flush();
      debugPrint(
          '[HabitLog] WROTE update habit=$habitId day=${_dayKey(on)} value=$value (id=${existing.id})');
      SyncService().debouncedPush();
      return existing;
    }

    final log = HabitLog(
      id: _uuid.v4(),
      habitId: habitId,
      date: on,
      value: value,
      targetValue: target,
      timestamp: DateTime.now(),
      note: note,
      updatedAt: DateTime.now(),
    );
    try {
      await _logBox.put(log.id, log);
      await _logBox.flush();
      debugPrint(
          '[HabitLog] WROTE new habit=$habitId day=${_dayKey(on)} value=$value (id=${log.id})');
      SyncService().debouncedPush();
    } catch (e, st) {
      debugPrint('HabitRepository.logHabit failed: $e\n$st');
      rethrow;
    }
    return log;
  }

  Future<void> incrementLog({
    required String habitId,
    int by = 1,
    DateTime? date,
  }) async {
    final on = date ?? DateTime.now();
    final habit = _habitBox.get(habitId);
    final existing = _findLog(habitId, on);
    final current = existing?.value ?? 0;
    // Cap at effectiveTarget so duration / counter habits don't exceed
    // their target (e.g. 30/10m bug from mobile testing). Min stays at 0.
    final cap = habit?.effectiveTarget ?? (1 << 30);
    final next = (current + by).clamp(0, cap);
    if (next == current) return;
    await logHabit(habitId: habitId, value: next, date: on);
  }

  Future<void> toggleYesNoLog({
    required String habitId,
    DateTime? date,
  }) async {
    final on = date ?? DateTime.now();
    final existing = _findLog(habitId, on);
    final next = (existing?.value ?? 0) > 0 ? 0 : 1;
    await logHabit(habitId: habitId, value: next, date: on);
  }

  List<HabitLog> getLogsForHabit(
    String habitId, {
    DateTime? from,
    DateTime? to,
  }) {
    return _logBox.values.where((l) {
      if (l.habitId != habitId) return false;
      if (from != null && l.date.isBefore(_dayKey(from))) return false;
      if (to != null && l.date.isAfter(_dayKey(to))) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  HabitLog? getLogForDate(String habitId, DateTime date) {
    final found = _findLog(habitId, date);
    debugPrint(
        '[HabitLog] READ habit=$habitId day=${_dayKey(date)} value=${found?.value} (id=${found?.id})');
    return found;
  }

  int getStreakForHabit(String habitId) {
    final habit = _habitBox.get(habitId);
    if (habit == null) return 0;
    final dayKeys = <DateTime>{
      for (final l in _logBox.values)
        if (l.habitId == habitId && l.isCompleted) _dayKey(l.date),
    };
    // A frozen day keeps the streak alive without a log.
    final frozenKeys = <DateTime>{
      for (final d in habit.frozenDates) _dayKey(d),
    };
    if (dayKeys.isEmpty && frozenKeys.isEmpty) return 0;
    bool counts(DateTime d) => dayKeys.contains(d) || frozenKeys.contains(d);

    var streak = 0;
    var cursor = _dayKey(DateTime.now());
    if (!counts(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!counts(cursor)) return 0;
    }
    while (counts(cursor)) {
      // Frozen days protect but don't add to the visible streak number.
      if (dayKeys.contains(cursor)) streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int getBestStreak(String habitId) {
    final dayKeys = <DateTime>{
      for (final l in _logBox.values)
        if (l.habitId == habitId && l.isCompleted) _dayKey(l.date),
    };
    if (dayKeys.isEmpty) return 0;
    final sorted = dayKeys.toList()..sort();
    var best = 1;
    var current = 1;
    for (var i = 1; i < sorted.length; i++) {
      final diff = sorted[i].difference(sorted[i - 1]).inDays;
      if (diff == 1) {
        current += 1;
        if (current > best) best = current;
      } else {
        current = 1;
      }
    }
    return best;
  }

  double getCompletionRate(String habitId, int days) {
    final habit = _habitBox.get(habitId);
    if (habit == null || days <= 0) return 0;
    final today = _dayKey(DateTime.now());
    var scheduled = 0;
    var completed = 0;
    for (var i = 0; i < days; i++) {
      final date = today.subtract(Duration(days: i));
      if (!habit.isScheduledFor(date)) continue;
      scheduled += 1;
      final log = _findLog(habitId, date);
      if (log != null && log.isCompleted) completed += 1;
    }
    if (scheduled == 0) return 0;
    return completed / scheduled;
  }

  List<HabitLog> getLast30Days(String habitId) {
    final cutoff = _dayKey(DateTime.now())
        .subtract(const Duration(days: 29));
    return getLogsForHabit(habitId, from: cutoff);
  }

  HabitLog? _findLog(String habitId, DateTime date) {
    final key = _dayKey(date);
    for (final l in _logBox.values) {
      if (l.habitId == habitId && _sameDay(l.date, key)) return l;
    }
    return null;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime _dayKey(DateTime d) => DateTime(d.year, d.month, d.day);
}
