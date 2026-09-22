import 'package:flutter_test/flutter_test.dart';

import 'package:mood8/models/frequency.dart';
import 'package:mood8/models/habit.dart';
import 'package:mood8/models/habit_log.dart';
import 'package:mood8/models/habit_type.dart';
import 'package:mood8/models/routine_category.dart';
import 'package:mood8/services/schedule_drift_service.dart';

/// A habit scheduled at [scheduledMinute] with a reminder set.
Habit _habit({int scheduledMinute = 600}) => Habit(
      id: 'h1',
      title: 'Study language',
      icon: '📖',
      habitType: HabitType.yesNo,
      identity: 'Learner',
      category: RoutineCategory.creative,
      frequency: Frequency.daily,
      color: 0xFFA855F7,
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      remindersEnabled: true,
      reminderMinutes: [scheduledMinute],
    );

/// [count] completions, each [daysAgo] apart, logged at [hour]:[minute].
List<HabitLog> _logs({
  required int count,
  required int hour,
  int minute = 0,
  int spreadMinutes = 0,
}) {
  final now = DateTime.now();
  return List.generate(count, (i) {
    final day = now.subtract(Duration(days: i + 1));
    // Alternate either side of the target so the median lands on it.
    final jitter = spreadMinutes == 0
        ? 0
        : (i.isEven ? spreadMinutes : -spreadMinutes);
    final ts = DateTime(day.year, day.month, day.day, hour, minute)
        .add(Duration(minutes: jitter));
    return HabitLog(
      id: 'l$i',
      habitId: 'h1',
      date: DateTime(day.year, day.month, day.day),
      value: 1,
      targetValue: 1,
      timestamp: ts,
    );
  });
}

void main() {
  final svc = ScheduleDriftService();

  group('ScheduleDriftService', () {
    test('detects the 10:00-scheduled habit actually done at 12:00', () {
      // The exact reported case: set for 10:00, ticked around noon all week.
      final d = svc.detectFor(_habit(scheduledMinute: 600),
          _logs(count: 7, hour: 12));

      expect(d, isNotNull);
      expect(d!.scheduledMinute, 600);
      expect(d.actualMinute, 720);
      expect(d.driftMinutes, 120);
      expect(d.isLater, isTrue);
      expect(d.sampleSize, 7);
      expect(ScheduleDriftService.formatMinute(d.actualMinute), '12:00');
    });

    test('stays quiet when the habit is done close to its scheduled time',
        () {
      // 10:00 scheduled, done ~10:20 — ordinary scatter, not a pattern.
      final d = svc.detectFor(_habit(scheduledMinute: 600),
          _logs(count: 7, hour: 10, minute: 20));
      expect(d, isNull);
    });

    test('stays quiet below the evidence threshold', () {
      // A big drift but only 3 completions: not yet a rhythm.
      final d = svc.detectFor(_habit(scheduledMinute: 600),
          _logs(count: 3, hour: 12));
      expect(d, isNull);
    });

    test('ignores completions scattered across the whole day', () {
      // ±5h spread: there is no single "time they do it" to move to, so a
      // median would be a meaningless number to act on.
      final d = svc.detectFor(
        _habit(scheduledMinute: 600),
        _logs(count: 8, hour: 12, spreadMinutes: 5 * 60),
      );
      expect(d, isNull);
    });

    test('detects drift to earlier as well as later', () {
      // Scheduled 20:00, actually done at 17:00.
      final d = svc.detectFor(_habit(scheduledMinute: 20 * 60),
          _logs(count: 6, hour: 17));
      expect(d, isNotNull);
      expect(d!.driftMinutes, -180);
      expect(d.isLater, isFalse);
    });

    test('ignores a habit with no reminder set', () {
      final h = _habit();
      h.reminderMinutes = [];
      expect(svc.detectFor(h, _logs(count: 7, hour: 12)), isNull);
    });

    test('ignores an archived habit', () {
      final h = _habit();
      h.isArchived = true;
      expect(svc.detectFor(h, _logs(count: 7, hour: 12)), isNull);
    });

    test('only counts logs inside the trailing window', () {
      final old = _logs(count: 7, hour: 12)
          .map((l) => HabitLog(
                id: l.id,
                habitId: l.habitId,
                date: l.date,
                value: l.value,
                targetValue: l.targetValue,
                // Push every completion outside the 21-day window.
                timestamp: l.timestamp.subtract(const Duration(days: 60)),
              ))
          .toList();
      expect(svc.detectFor(_habit(), old), isNull);
    });
  });
}
