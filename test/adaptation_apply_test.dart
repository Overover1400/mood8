import 'package:flutter_test/flutter_test.dart';
import 'package:mood8/models/frequency.dart';
import 'package:mood8/models/habit.dart';
import 'package:mood8/models/habit_type.dart';
import 'package:mood8/models/routine_category.dart';
import 'package:mood8/services/adaptation_service.dart';

Habit _h({List<int>? slots, bool on = false, int? target, int? program}) =>
    Habit(
      id: 'h1',
      title: 'Read',
      icon: '📖',
      habitType: HabitType.duration,
      identity: 'Scholar',
      category: RoutineCategory.mindful,
      frequency: Frequency.daily,
      color: 0xFFA855F7,
      createdAt: DateTime(2026, 10, 1),
      remindersEnabled: on,
      reminderMinutes: slots,
      targetValue: target,
      programDurationDays: program,
    );

AdaptationProposal _p(String kind, String? to) => AdaptationProposal(
    id: 1, habitId: 'h1', habitTitle: 'Read', kind: kind, rationale: '', toValue: to);

void main() {
  test('an accepted time change replaces the reminder hours Edit shows', () {
    final h = _h(slots: [8 * 60, 20 * 60], on: true);
    final p = _p('time', '07:00');
    expect(proposalIsApplied(h, p), isFalse);
    expect(applyProposalToHabit(h, p), isTrue);
    expect(h.reminderMinutes, [420]);
    expect(h.remindersEnabled, isTrue);
    expect(proposalIsApplied(h, p), isTrue);
  });

  test('a habit without reminders gets the proposed time switched on', () {
    final h = _h();
    expect(h.remindersEnabled, isFalse);
    applyProposalToHabit(h, _p('time', '19:30'));
    expect(h.reminderMinutes, [19 * 60 + 30]);
    expect(h.remindersEnabled, isTrue);
  });

  test('amount and duration changes land in the fields Edit reads', () {
    final h = _h(target: 20, program: 30);
    expect(applyProposalToHabit(h, _p('quantity', '10')), isTrue);
    expect(h.targetValue, 10);
    expect(applyProposalToHabit(h, _p('duration', '21')), isTrue);
    expect(h.programDurationDays, 21);
    expect(proposalIsApplied(h, _p('duration', '21')), isTrue);
    expect(proposalIsApplied(h, _p('duration', '30')), isFalse);
  });

  test('bad values are rejected and leave the habit alone', () {
    final h = _h(slots: [540], on: true);
    for (final p in [
      _p('time', '25:00'),
      _p('time', '7'),
      _p('time', null),
      _p('quantity', '0'),
      _p('quantity', 'x'),
      _p('mystery', '1'),
    ]) {
      expect(applyProposalToHabit(h, p), isFalse, reason: '${p.kind} ${p.toValue}');
    }
    expect(h.reminderMinutes, [540]);
  });

  test('minuteOfDay', () {
    expect(minuteOfDay('00:00'), 0);
    expect(minuteOfDay('23:59'), 1439);
    expect(minuteOfDay('24:00'), isNull);
    expect(minuteOfDay('09:60'), isNull);
  });
}
