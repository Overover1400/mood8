import 'package:flutter_test/flutter_test.dart';
import 'package:mood8/services/adaptation_service.dart';

void main() {
  test('ask proposal parses windows and reduce options', () {
    final p = AdaptationProposal.fromJson({
      'id': 3,
      'habit_id': 'h1',
      'habit_title': 'Read',
      'kind': 'ask',
      'rationale': 'What is getting in the way?',
      'options': {
        'windows': {
          'morning': [5, 11],
          'afternoon': [12, 17],
          'night': [18, 23],
        },
        'can_reduce_amount': true,
        'can_reduce_duration': false,
      },
    });
    expect(p.isAsk, isTrue);
    expect(p.windows['night'], [18, 23]);
    expect(p.canReduceAmount, isTrue);
    expect(p.canReduceDuration, isFalse);
  });

  test('old-style proposal has no options and is not an ask', () {
    final p = AdaptationProposal.fromJson({
      'id': 4,
      'habit_id': 'h1',
      'habit_title': 'Read',
      'kind': 'time',
      'rationale': 'Move it to 07:00',
      'to': '07:00',
    });
    expect(p.isAsk, isFalse);
    expect(p.windows, isEmpty);
    expect(p.acceptLabel, 'Move it');
  });

  test('duration proposal gets its own accept label', () {
    final p = AdaptationProposal.fromJson({
      'id': 5,
      'kind': 'duration',
      'rationale': 'x',
      'from': '30',
      'to': '21',
    });
    expect(p.acceptLabel, 'Shorten it');
  });
}
