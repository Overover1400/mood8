import 'package:flutter_test/flutter_test.dart';
import 'package:mood8/models/focus_area.dart';
import 'package:mood8/models/frequency.dart';
import 'package:mood8/models/habit.dart';
import 'package:mood8/models/habit_log.dart';
import 'package:mood8/models/habit_type.dart';
import 'package:mood8/models/personalization.dart';
import 'package:mood8/models/routine_category.dart';
import 'package:mood8/models/user_profile.dart';
import 'package:mood8/services/miss_reason_service.dart';
import 'package:mood8/services/profile_mirror.dart';

UserProfile _user() => UserProfile(
      name: 'A',
      identities: ['Scholar', 'Leader'],
      focusAreas: [FocusArea.learning],
      hasCompletedOnboarding: true,
      createdAt: DateTime(2026, 10, 1),
      chronotype: Chronotype.balanced,
    );

Habit _habit({Frequency f = Frequency.daily, List<int>? days}) => Habit(
      id: 'h1',
      title: 'Read',
      icon: 'x',
      habitType: HabitType.yesNo,
      identity: 'Scholar',
      category: RoutineCategory.mindful,
      frequency: f,
      frequencyDays: days,
      color: 0,
      createdAt: DateTime(2026, 9, 1),
    );

HabitLog _log(DateTime d) => HabitLog(
      id: d.toIso8601String(),
      habitId: 'h1',
      date: d,
      timestamp: d,
      value: 1,
      targetValue: 1,
    );

void main() {
  test('profile payload keeps options and the current answer', () {
    final qs = ProfileQuestion.parseList({
      'questions': [
        {
          'key': 'energy_peak',
          'question': 'When?',
          'multi': false,
          'options': [
            {'value': 'morning', 'label': 'Morning'},
            {'value': 'evening', 'label': 'Evening'},
          ],
          'value': 'evening',
        },
        {
          'key': 'goal_areas',
          'question': 'Areas?',
          'multi': true,
          'options': [
            {'value': 'health', 'label': 'Health'},
            {'value': 'work', 'label': 'Work'},
          ],
          'value': ['health', 'work'],
        },
        {
          'key': 'identity',
          'question': 'Who?',
          'options': [
            {'value': 'Scholar', 'label': 'Scholar'}
          ],
          'value': null,
        },
        {'key': 'broken'},
      ],
    });
    expect(qs.map((q) => q.key), ['energy_peak', 'goal_areas', 'identity']);
    expect(qs[0].selected, ['evening']);
    expect(qs[0].selectedLabel, 'Evening');
    expect(qs[1].multi, isTrue);
    expect(qs[1].selected, ['health', 'work']);
    expect(qs[2].selected, isEmpty);
    expect(qs[2].selectedLabel, isNull);
    expect(ProfileQuestion.parseList(null), isEmpty);
  });

  test('an edited identity and goals are mirrored on the device', () {
    final p = _user();
    expect(applyProfileAnswer(p, 'identity', 'Athlete'), isTrue);
    expect(p.identities, ['Athlete', 'Scholar', 'Leader']);
    expect(applyProfileAnswer(p, 'identity', 'Scholar'), isTrue);
    expect(p.identities.first, 'Scholar');
    expect(applyProfileAnswer(p, 'identity', 'Scholar'), isFalse);

    expect(applyProfileAnswer(p, 'goal_areas', ['health', 'work', 'nope']),
        isTrue);
    expect(p.focusAreas, [FocusArea.health, FocusArea.work]);
    expect(applyProfileAnswer(p, 'goal_areas', ['nope']), isFalse);
    expect(p.focusAreas, [FocusArea.health, FocusArea.work]);
  });

  test('answers only the server uses leave the device profile alone', () {
    final p = _user();
    expect(applyProfileAnswer(p, 'energy_peak', 'evening'), isFalse);
    expect(applyProfileAnswer(p, 'failure_reason', 'too_hard'), isFalse);
    expect(applyProfileAnswer(p, 'identity', ''), isFalse);
  });

  test('the reason belongs to the latest missed day', () {
    final now = DateTime(2026, 10, 9, 12);
    final h = _habit();
    // done yesterday and the day before -> the latest miss is 3 days back
    final logs = [
      _log(DateTime(2026, 10, 8)),
      _log(DateTime(2026, 10, 7)),
    ];
    expect(MissReasonService.latestMissedDay(h, logs, now: now),
        DateTime(2026, 10, 6));
    expect(MissReasonService.latestMissedDay(h, const [], now: now),
        DateTime(2026, 10, 8));
  });

  test('days off are not misses when picking the occurrence', () {
    final h = _habit(f: Frequency.weekdays);
    // Mon 12 Oct 2026: yesterday and the day before are Sun/Sat -> Fri 9th
    final now = DateTime(2026, 10, 12, 9);
    expect(MissReasonService.latestMissedDay(h, const [], now: now),
        DateTime(2026, 10, 9));
  });

  test('a habit with nothing missed has no occurrence', () {
    final now = DateTime(2026, 10, 9, 12);
    final h = _habit();
    final logs = [
      for (var i = 1; i <= 7; i++) _log(DateTime(2026, 10, 9 - i)),
    ];
    expect(MissReasonService.latestMissedDay(h, logs, now: now), isNull);
  });
}
