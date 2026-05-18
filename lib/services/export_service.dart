import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/mood_entry.dart';
import '../models/reflection.dart';
import '../models/routine_item.dart';
import '../models/user_profile.dart';
import 'database_service.dart';
import 'export_downloader.dart';

class ExportService {
  ExportService({DatabaseService? db})
      : _db = db ?? DatabaseService.instance;

  final DatabaseService _db;

  Map<String, dynamic> _userJson(UserProfile u) => {
        'name': u.name,
        'identities': u.identities,
        'focusAreas': u.focusAreas.map((e) => e.name).toList(),
        'chronotype': u.chronotype.name,
        'createdAt': u.createdAt.toIso8601String(),
      };

  Map<String, dynamic> _moodJson(MoodEntry e) => {
        'id': e.id,
        'timestamp': e.timestamp.toIso8601String(),
        'mood': e.mood,
        'energy': e.energy,
        'focus': e.focus,
        'note': e.note,
      };

  Map<String, dynamic> _routineJson(RoutineItem r) => {
        'id': r.id,
        'title': r.title,
        'time': r.time.toIso8601String(),
        'durationMinutes': r.durationMinutes,
        'category': r.category.name,
        'meta': r.meta,
        'isCompleted': r.isCompleted,
        'completedAt': r.completedAt?.toIso8601String(),
        'sortOrder': r.sortOrder,
      };

  Map<String, dynamic> _habitJson(Habit h) => {
        'id': h.id,
        'title': h.title,
        'description': h.description,
        'icon': h.icon,
        'type': h.habitType.name,
        'identity': h.identity,
        'category': h.category.name,
        'frequency': h.frequency.name,
        'frequencyDays': h.frequencyDays,
        'targetValue': h.targetValue,
        'targetUnit': h.targetUnit,
        'color': h.color,
        'createdAt': h.createdAt.toIso8601String(),
        'sortOrder': h.sortOrder,
        'isArchived': h.isArchived,
      };

  Map<String, dynamic> _logJson(HabitLog l) => {
        'id': l.id,
        'habitId': l.habitId,
        'date': l.date.toIso8601String(),
        'value': l.value,
        'targetValue': l.targetValue,
        'timestamp': l.timestamp.toIso8601String(),
        'note': l.note,
      };

  Map<String, dynamic> _reflectionJson(Reflection r) => {
        'id': r.id,
        'date': r.date.toIso8601String(),
        'reflection': r.reflection,
        'suggestion': r.suggestion,
        'generatedAt': r.generatedAt.toIso8601String(),
      };

  String exportToJson() {
    final user = _db.userBox.get('me');
    final payload = {
      'exportedAt': DateTime.now().toIso8601String(),
      'app': 'Mood8',
      'schema': 1,
      'user': user == null ? null : _userJson(user),
      'moodEntries': _db.moodBox.values.map(_moodJson).toList(),
      'routines': _db.routineBox.values.map(_routineJson).toList(),
      'habits': _db.habitBox.values.map(_habitJson).toList(),
      'habitLogs': _db.habitLogBox.values.map(_logJson).toList(),
      'reflections': _db.reflectionBox.values.map(_reflectionJson).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  String exportToCsv() {
    final buf = StringBuffer();
    buf.writeln('# Mood8 export — ${DateTime.now().toIso8601String()}');

    buf.writeln('\n## mood_entries');
    buf.writeln('id,timestamp,mood,energy,focus,note');
    for (final e in _db.moodBox.values) {
      buf.writeln([
        e.id,
        e.timestamp.toIso8601String(),
        e.mood,
        e.energy,
        e.focus,
        _csvCell(e.note ?? ''),
      ].join(','));
    }

    buf.writeln('\n## routines');
    buf.writeln(
        'id,title,time,durationMinutes,category,meta,isCompleted,completedAt');
    for (final r in _db.routineBox.values) {
      buf.writeln([
        r.id,
        _csvCell(r.title),
        r.time.toIso8601String(),
        r.durationMinutes,
        r.category.name,
        _csvCell(r.meta),
        r.isCompleted,
        r.completedAt?.toIso8601String() ?? '',
      ].join(','));
    }

    buf.writeln('\n## habits');
    buf.writeln(
        'id,title,type,identity,category,frequency,targetValue,targetUnit,createdAt,isArchived');
    for (final h in _db.habitBox.values) {
      buf.writeln([
        h.id,
        _csvCell(h.title),
        h.habitType.name,
        _csvCell(h.identity),
        h.category.name,
        h.frequency.name,
        h.targetValue ?? '',
        _csvCell(h.targetUnit ?? ''),
        h.createdAt.toIso8601String(),
        h.isArchived,
      ].join(','));
    }

    buf.writeln('\n## habit_logs');
    buf.writeln('id,habitId,date,value,targetValue,timestamp');
    for (final l in _db.habitLogBox.values) {
      buf.writeln([
        l.id,
        l.habitId,
        l.date.toIso8601String(),
        l.value,
        l.targetValue,
        l.timestamp.toIso8601String(),
      ].join(','));
    }

    buf.writeln('\n## reflections');
    buf.writeln('id,date,generatedAt,reflection,suggestion');
    for (final r in _db.reflectionBox.values) {
      buf.writeln([
        r.id,
        r.date.toIso8601String(),
        r.generatedAt.toIso8601String(),
        _csvCell(r.reflection),
        _csvCell(r.suggestion ?? ''),
      ].join(','));
    }

    return buf.toString();
  }

  /// Downloads (web) or shares (mobile) a JSON snapshot of the whole DB.
  Future<bool> downloadJson() async {
    try {
      final content = exportToJson();
      final bytes = Uint8List.fromList(utf8.encode(content));
      return await ExportDownloader().downloadBytes(
        bytes: bytes,
        filename: suggestedFilename('json'),
        mimeType: 'application/json',
      );
    } catch (e, st) {
      debugPrint('ExportService.downloadJson failed: $e\n$st');
      return false;
    }
  }

  /// Downloads/shares a ZIP containing one CSV per Hive table.
  Future<bool> downloadCsvBundle() async {
    try {
      final files = _csvFilesByTable();
      final archive = Archive();
      for (final entry in files.entries) {
        final bytes = utf8.encode(entry.value);
        archive.addFile(ArchiveFile(entry.key, bytes.length, bytes));
      }
      final zip = ZipEncoder().encode(archive);
      if (zip == null) return false;
      return await ExportDownloader().downloadBytes(
        bytes: Uint8List.fromList(zip),
        filename: suggestedFilename('zip'),
        mimeType: 'application/zip',
      );
    } catch (e, st) {
      debugPrint('ExportService.downloadCsvBundle failed: $e\n$st');
      return false;
    }
  }

  Map<String, String> _csvFilesByTable() {
    final stamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    final root = 'mood8-$stamp';
    return {
      '$root/mood_entries.csv': _moodCsv(),
      '$root/routines.csv': _routinesCsv(),
      '$root/habits.csv': _habitsCsv(),
      '$root/habit_logs.csv': _habitLogsCsv(),
      '$root/reflections.csv': _reflectionsCsv(),
    };
  }

  String _moodCsv() {
    final buf = StringBuffer('id,timestamp,mood,energy,focus,note\n');
    for (final e in _db.moodBox.values) {
      buf.writeln([
        e.id,
        e.timestamp.toIso8601String(),
        e.mood,
        e.energy,
        e.focus,
        _csvCell(e.note ?? ''),
      ].join(','));
    }
    return buf.toString();
  }

  String _routinesCsv() {
    final buf = StringBuffer(
        'id,title,time,durationMinutes,category,meta,isCompleted,completedAt\n');
    for (final r in _db.routineBox.values) {
      buf.writeln([
        r.id,
        _csvCell(r.title),
        r.time.toIso8601String(),
        r.durationMinutes,
        r.category.name,
        _csvCell(r.meta),
        r.isCompleted,
        r.completedAt?.toIso8601String() ?? '',
      ].join(','));
    }
    return buf.toString();
  }

  String _habitsCsv() {
    final buf = StringBuffer(
        'id,title,type,identity,category,frequency,targetValue,targetUnit,createdAt,isArchived\n');
    for (final h in _db.habitBox.values) {
      buf.writeln([
        h.id,
        _csvCell(h.title),
        h.habitType.name,
        _csvCell(h.identity),
        h.category.name,
        h.frequency.name,
        h.targetValue ?? '',
        _csvCell(h.targetUnit ?? ''),
        h.createdAt.toIso8601String(),
        h.isArchived,
      ].join(','));
    }
    return buf.toString();
  }

  String _habitLogsCsv() {
    final buf =
        StringBuffer('id,habitId,date,value,targetValue,timestamp\n');
    for (final l in _db.habitLogBox.values) {
      buf.writeln([
        l.id,
        l.habitId,
        l.date.toIso8601String(),
        l.value,
        l.targetValue,
        l.timestamp.toIso8601String(),
      ].join(','));
    }
    return buf.toString();
  }

  String _reflectionsCsv() {
    final buf =
        StringBuffer('id,date,generatedAt,reflection,suggestion\n');
    for (final r in _db.reflectionBox.values) {
      buf.writeln([
        r.id,
        r.date.toIso8601String(),
        r.generatedAt.toIso8601String(),
        _csvCell(r.reflection),
        _csvCell(r.suggestion ?? ''),
      ].join(','));
    }
    return buf.toString();
  }

  Future<void> copyToClipboard(String content) async {
    try {
      await Clipboard.setData(ClipboardData(text: content));
    } catch (e, st) {
      debugPrint('ExportService.copyToClipboard failed: $e\n$st');
      rethrow;
    }
  }

  String suggestedFilename(String extension) {
    final stamp = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    return 'mood8-$stamp.$extension';
  }

  StorageStats stats() {
    return StorageStats(
      moodEntries: _db.moodBox.length,
      routines: _db.routineBox.length,
      habits: _db.habitBox.length,
      habitLogs: _db.habitLogBox.length,
      reflections: _db.reflectionBox.length,
      chatMessages: _db.chatBox.length,
      insights: _db.insightBox.length,
    );
  }

  Future<void> clearAllData() async {
    try {
      await _db.userBox.clear();
      await _db.moodBox.clear();
      await _db.routineBox.clear();
      await _db.habitBox.clear();
      await _db.habitLogBox.clear();
      await _db.reflectionBox.clear();
      await _db.chatBox.clear();
      await _db.insightBox.clear();
    } catch (e, st) {
      debugPrint('ExportService.clearAllData failed: $e\n$st');
      rethrow;
    }
  }

  static String _csvCell(String s) {
    if (!s.contains(',') && !s.contains('"') && !s.contains('\n')) return s;
    return '"${s.replaceAll('"', '""')}"';
  }
}

class StorageStats {
  const StorageStats({
    required this.moodEntries,
    required this.routines,
    required this.habits,
    required this.habitLogs,
    required this.reflections,
    required this.chatMessages,
    required this.insights,
  });

  final int moodEntries;
  final int routines;
  final int habits;
  final int habitLogs;
  final int reflections;
  final int chatMessages;
  final int insights;

  int get total =>
      moodEntries +
      routines +
      habits +
      habitLogs +
      reflections +
      chatMessages +
      insights;

  String get headline {
    return '$moodEntries check-ins · $routines routines · $habits habits';
  }
}
