import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mood8/models/entitlement.dart';
import 'package:mood8/models/frequency.dart';
import 'package:mood8/models/habit.dart';
import 'package:mood8/models/habit_polarity.dart';
import 'package:mood8/models/habit_type.dart';
import 'package:mood8/models/routine_category.dart';
import 'package:mood8/services/adaptation_service.dart';
import 'package:mood8/services/sync_service.dart';

Habit _habit(String id, {bool archived = false, String? parkedBehind}) =>
    Habit(
      id: id,
      title: 'Read',
      icon: '📖',
      habitType: HabitType.yesNo,
      identity: 'reader',
      category: RoutineCategory.work,
      frequency: Frequency.daily,
      color: 0xFFA855F7,
      createdAt: DateTime(2026, 10, 1),
      isArchived: archived,
      parkedBehind: parkedBehind,
      remindersEnabled: true,
      reminderMinutes: [540],
    );

void main() {
  late Directory dir;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('hive_pause_');
    Hive.init(dir.path);
    Hive
      ..registerAdapter(HabitAdapter())
      ..registerAdapter(HabitTypeAdapter())
      ..registerAdapter(FrequencyAdapter())
      ..registerAdapter(RoutineCategoryAdapter())
      ..registerAdapter(HabitPolarityAdapter())
      ..registerAdapter(AvoidModeAdapter());
  });

  tearDownAll(() async {
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  group('pause proposal', () {
    test('parses kind pause with cycles', () {
      final p = AdaptationProposal.fromJson({
        'id': 9,
        'habit_id': 'h1',
        'habit_title': 'Read',
        'kind': 'pause',
        'rationale': 'We tried 3 adjustments.',
        'from': null,
        'to': null,
        'cycles_used': 3,
        'max_cycles': 3,
      });
      expect(p.isPause, isTrue);
      expect(p.isAsk, isFalse);
      expect(p.cyclesUsed, 3);
      expect(p.maxCycles, 3);
      expect(p.acceptLabel, 'Got it');
    });

    test('other kinds default cycles', () {
      final p = AdaptationProposal.fromJson({
        'id': 1,
        'habit_id': 'h1',
        'kind': 'time',
        'rationale': 'x',
      });
      expect(p.isPause, isFalse);
      expect(p.cyclesUsed, 0);
      expect(p.maxCycles, 3);
    });
  });

  group('pause / restart state', () {
    test('pausing archives, records why and when, and is idempotent', () {
      final h = _habit('a');
      final at = DateTime(2026, 10, 9, 8);
      expect(markPausedByAdaptation(h, now: at), isTrue);
      expect(h.isArchived, isTrue);
      expect(h.pausedReason, kPausedAdaptCycles);
      expect(h.pausedAt, at);
      expect(h.isPausedByAdaptation, isTrue);
      // Second time: nothing to do, timestamp untouched.
      expect(markPausedByAdaptation(h, now: DateTime(2027)), isFalse);
      expect(h.pausedAt, at);
    });

    test('never overrides a manual archive or a parked habit', () {
      final manual = _habit('m', archived: true);
      expect(markPausedByAdaptation(manual), isFalse);
      expect(manual.pausedReason, isNull);
      final parked = _habit('p', parkedBehind: 'easier');
      expect(markPausedByAdaptation(parked), isFalse);
      expect(parked.isArchived, isFalse);
      expect(parked.pausedReason, isNull);
    });

    test('restart un-archives and clears the pause; others untouched', () {
      final h = _habit('a');
      markPausedByAdaptation(h);
      expect(clearAdaptationPause(h), isTrue);
      expect(h.isArchived, isFalse);
      expect(h.pausedReason, isNull);
      expect(h.pausedAt, isNull);
      expect(h.isPausedByAdaptation, isFalse);
      // Reminders survive for rescheduling.
      expect(h.remindersEnabled, isTrue);
      expect(h.reminderMinutes, [540]);
      // A habit that was not paused by adaptation is not "cleared".
      final parked = _habit('p', archived: true, parkedBehind: 'x');
      expect(clearAdaptationPause(parked), isFalse);
      expect(parked.isArchived, isTrue);
    });

    test('pause fields survive a Hive write/read', () async {
      final box = await Hive.openBox<Habit>('habits_pause_rt');
      final h = _habit('a');
      markPausedByAdaptation(h, now: DateTime(2026, 10, 9, 8));
      await box.put('a', h);
      await box.put('plain', _habit('plain'));
      await box.close();
      final again = await Hive.openBox<Habit>('habits_pause_rt');
      expect(again.get('a')!.pausedReason, kPausedAdaptCycles);
      expect(again.get('a')!.pausedAt, DateTime(2026, 10, 9, 8));
      expect(again.get('a')!.isArchived, isTrue);
      expect(again.get('plain')!.pausedReason, isNull);
      expect(again.get('plain')!.pausedAt, isNull);
    });
  });

  group('sync habit_limit rejection', () {
    test('archives the rejected habit, keeps it, stamps it for re-push',
        () async {
      final box = await Hive.openBox<Habit>('habits_reject');
      final fresh = _habit('new');
      final old = DateTime(2026, 10, 1);
      fresh.updatedAt = old;
      await box.put('new', fresh);
      await box.put('keep', _habit('keep'));

      final archivedIds = <String>[];
      final n = await SyncService().applyHabitLimitRejections(
        [
          const SyncRejection(
              entityType: 'habit',
              entityId: 'new',
              reason: 'habit_limit',
              limit: 3),
          // Not a habit_limit reason, a different entity, and an id we
          // don't have: all ignored.
          const SyncRejection(
              entityType: 'habit', entityId: 'keep', reason: 'other'),
          const SyncRejection(
              entityType: 'mood', entityId: 'new', reason: 'habit_limit'),
          const SyncRejection(
              entityType: 'habit', entityId: 'gone', reason: 'habit_limit'),
        ],
        habitBox: box,
        onArchived: (h) => archivedIds.add(h.id),
        pushAfter: false,
      );

      expect(n, 1);
      expect(archivedIds, ['new']);
      expect(box.get('new')!.isArchived, isTrue); // kept, not deleted
      expect(box.get('new')!.updatedAt!.isAfter(old), isTrue);
      expect(box.get('keep')!.isArchived, isFalse);
      expect(box.length, 2);

      // Already archived (e.g. a repeated reply): no second archive.
      final again = await SyncService().applyHabitLimitRejections(
        [
          const SyncRejection(
              entityType: 'habit', entityId: 'new', reason: 'habit_limit')
        ],
        habitBox: box,
        onArchived: (_) {},
        pushAfter: false,
      );
      expect(again, 0);
    });
  });
}
