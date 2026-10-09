import 'package:flutter_test/flutter_test.dart';

import 'package:mood8/models/frequency.dart';
import 'package:mood8/models/habit_type.dart';
import 'package:mood8/models/personalization.dart';
import 'package:mood8/models/routine_category.dart';
import 'package:mood8/widgets/suggested_habits_sheet.dart';

Map<String, dynamic> _payload() => {
      'suggestions': [
        {
          'key': 'scholar.read',
          'title': 'Read',
          'icon': '📚',
          'type': 'duration',
          'category': 'mindful',
          'frequency': 'daily',
          'target': 25,
          'unit': 'minutes',
          'time': '19:00',
          'difficulty': 2,
          'identity': 'Scholar',
          'why': 'Fits your Scholar identity.',
          'source': 'identity',
        },
        {
          'key': 'scholar.review',
          'title': 'Review today\'s notes',
          'type': 'yesNo',
          'category': 'work',
          'frequency': 'daily',
          'target': 1,
        },
      ],
      'follow_up': {
        'key': 'energy_peak',
        'question': 'When do you have the most energy?',
        'multi': false,
        'options': [
          {'value': 'morning', 'label': 'Morning'},
          {'value': 'evening'},
        ],
      },
      'basis': {
        'identity': 'Scholar',
        'goal_areas': ['learning'],
        'behaviour': true,
        'fresh_energy': 'low',
        'similar_users': 'insufficient_data',
        'level': 1,
      },
      'slots_left': 2,
    };

void main() {
  test('parses a full payload', () {
    final r = PersonalizationResult.fromJson(_payload());
    expect(r.suggestions, hasLength(2));
    final read = r.suggestions.first;
    expect(read.type, HabitType.duration);
    expect(read.category, RoutineCategory.mindful);
    expect(read.frequency, Frequency.daily);
    expect(read.amountLabel, '25 minutes');
    expect(read.reminderMinute, 19 * 60);
    expect(r.followUp!.key, 'energy_peak');
    expect(r.followUp!.options.map((o) => o.label), ['Morning', 'evening']);
    expect(r.slotsLeft, 2);
    expect(r.isEmpty, isFalse);
  });

  test('tolerates missing fields and unknown enum strings', () {
    final r = PersonalizationResult.fromJson({
      'suggestions': [
        {'title': 'X', 'type': 'weird', 'category': 'nope', 'frequency': '??'},
        {'type': 'yesNo'}, // no title: dropped
        'garbage',
      ],
    });
    expect(r.suggestions, hasLength(1));
    final s = r.suggestions.single;
    expect(s.type, HabitType.yesNo);
    expect(s.category, RoutineCategory.health);
    expect(s.frequency, Frequency.daily);
    expect(s.reminderMinute, isNull);
    expect(r.followUp, isNull);
    expect(r.slotsLeft, isNull);
    expect(PersonalizationResult.fromJson({}).isEmpty, isTrue);
  });

  test('a malformed follow-up is ignored, not fatal', () {
    expect(FollowUpQuestion.tryParse({'key': 'a'}), isNull);
    expect(
        FollowUpQuestion.tryParse(
            {'key': 'a', 'question': 'q', 'options': []}),
        isNull);
    expect(FollowUpQuestion.tryParse('x'), isNull);
  });

  test('basis line only claims what the server used', () {
    final r = PersonalizationResult.fromJson(_payload());
    expect(r.basisLine,
        'Based on your Scholar identity, your focus on learning, your recent habits and your low energy lately');
    expect(r.basisLine.contains('similar'), isFalse);

    final used = PersonalizationResult.fromJson({
      'suggestions': [],
      'basis': {'similar_users': 'used'},
    });
    expect(used.basisLine, 'Based on people with a similar rhythm');

    expect(PersonalizationResult.fromJson({}).basisLine,
        'Based on a few general starting points');
  });

  test('suggestions the user already has are filtered (case-insensitive)', () {
    final r = PersonalizationResult.fromJson(_payload());
    final left = r.without(['  read ', 'Something else']);
    expect(left.map((s) => s.title), ['Review today\'s notes']);
    expect(r.without(const []), hasLength(2));
  });

  test('maps a suggestion to habit-creation arguments', () {
    final r = PersonalizationResult.fromJson(_payload());
    final a = argsForSuggestion(r.suggestions.first);
    expect(a.title, 'Read');
    expect(a.habitType, HabitType.duration);
    expect(a.targetValue, 25);
    expect(a.targetUnit, 'minutes');
    expect(a.reminderMinutes, [19 * 60]);
    expect(a.identity, 'Scholar');

    final yn = argsForSuggestion(r.suggestions.last);
    expect(yn.habitType, HabitType.yesNo);
    expect(yn.targetValue, 1);
    expect(yn.targetUnit, isNull);
    expect(yn.reminderMinutes, isEmpty);
  });

  test('bad times never produce a reminder', () {
    PersonalizedSuggestion at(String t) => PersonalizedSuggestion(
        key: 'k',
        title: 't',
        icon: 'i',
        type: HabitType.yesNo,
        category: RoutineCategory.work,
        frequency: Frequency.daily,
        why: '',
        time: t);
    expect(at('25:00').reminderMinute, isNull);
    expect(at('7').reminderMinute, isNull);
    expect(at('07:05').reminderMinute, 425);
  });
}
