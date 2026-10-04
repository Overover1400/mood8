import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mood8/models/frequency.dart';
import 'package:mood8/models/habit.dart';
import 'package:mood8/models/habit_polarity.dart';
import 'package:mood8/models/habit_type.dart';
import 'package:mood8/models/routine_category.dart';

Habit _habit({bool? share}) => Habit(
      id: 'h1',
      title: 'Read',
      icon: '📖',
      habitType: HabitType.yesNo,
      identity: 'reader',
      category: RoutineCategory.work,
      frequency: Frequency.daily,
      color: 0xFFA855F7,
      createdAt: DateTime(2026, 10, 1),
      shareInChallenges: share ?? false,
    );

void main() {
  late Directory dir;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('hive_share_');
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

  test('private by default', () {
    expect(_habit().shareInChallenges, isFalse);
  });

  test('flag survives a Hive write/read', () async {
    final box = await Hive.openBox<Habit>('habits_rt');
    await box.put('on', _habit(share: true));
    await box.put('off', _habit(share: false));
    await box.close();
    final again = await Hive.openBox<Habit>('habits_rt');
    expect(again.get('on')!.shareInChallenges, isTrue);
    expect(again.get('off')!.shareInChallenges, isFalse);
  });
}
