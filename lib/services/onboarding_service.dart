import 'package:flutter/foundation.dart';

import '../models/focus_area.dart';
import '../models/frequency.dart';
import '../models/habit_type.dart';
import '../models/routine_category.dart';
import '../models/user_profile.dart';
import 'database_service.dart';
import 'habit_repository.dart';
import 'mood_repository.dart';
import 'routine_repository.dart';
import 'user_repository.dart';

class StarterRoutine {
  const StarterRoutine({
    required this.title,
    required this.morningHour,
    required this.balancedHour,
    required this.nightHour,
    required this.minute,
    required this.durationMinutes,
    required this.category,
    required this.meta,
  });

  final String title;
  final int morningHour;
  final int balancedHour;
  final int nightHour;
  final int minute;
  final int durationMinutes;
  final RoutineCategory category;
  final String meta;

  int hourFor(Chronotype c) {
    switch (c) {
      case Chronotype.morningPerson:
        return morningHour;
      case Chronotype.balanced:
        return balancedHour;
      case Chronotype.nightOwl:
        return nightHour;
    }
  }
}

class OnboardingService {
  OnboardingService({
    DatabaseService? db,
    UserRepository? users,
    RoutineRepository? routines,
    MoodRepository? moods,
    HabitRepository? habits,
  })  : _db = db ?? DatabaseService.instance,
        _users = users ?? UserRepository(),
        _routines = routines ?? RoutineRepository(),
        _moods = moods ?? MoodRepository(),
        _habits = habits ?? HabitRepository();

  final DatabaseService _db;
  final UserRepository _users;
  final RoutineRepository _routines;
  final MoodRepository _moods;
  final HabitRepository _habits;

  Future<UserProfile> complete({
    required String name,
    required List<String> identities,
    required List<FocusArea> focusAreas,
    required Chronotype chronotype,
    double? mood,
    double? energy,
    double? focus,
  }) async {
    final profile = UserProfile(
      name: name.trim().isEmpty ? 'Friend' : name.trim(),
      identities: identities,
      focusAreas: focusAreas,
      hasCompletedOnboarding: true,
      createdAt: DateTime.now(),
      chronotype: chronotype,
    );

    await _users.saveUser(profile);

    final seeds = generateStarterRoutines(profile);
    await _db.routineBox.clear();
    for (final seed in seeds) {
      await _routines.addRoutine(
        title: seed.title,
        time: _todayAt(seed.hourFor(chronotype), seed.minute),
        durationMinutes: seed.durationMinutes,
        category: seed.category,
        meta: seed.meta,
      );
    }

    await _db.habitBox.clear();
    await _db.habitLogBox.clear();
    final habitSeeds = generateStarterHabits(profile);
    for (final seed in habitSeeds) {
      await _habits.addHabit(
        title: seed.title,
        icon: seed.icon,
        habitType: seed.type,
        identity: seed.identity,
        category: seed.category,
        frequency: seed.frequency,
        targetValue: seed.target,
        targetUnit: seed.unit,
      );
    }

    if (mood != null && energy != null && focus != null) {
      await _moods.addEntry(
        mood: mood * 10,
        energy: energy * 10,
        focus: focus * 10,
      );
    }

    return profile;
  }

  Future<void> reset() async {
    try {
      await _users.clear();
      await _db.routineBox.clear();
      await _db.habitBox.clear();
      await _db.habitLogBox.clear();
    } catch (e, st) {
      debugPrint('OnboardingService.reset failed: $e\n$st');
      rethrow;
    }
  }

  List<StarterHabit> generateStarterHabits(UserProfile p) {
    final picks = <StarterHabit>[];
    final seen = <String>{};
    void add(StarterHabit h) {
      final key = '${h.identity}|${h.title}';
      if (seen.add(key)) picks.add(h);
    }

    for (final id in p.identities) {
      for (final h in _habitsByIdentity[id] ?? const <StarterHabit>[]) {
        add(h);
      }
    }
    if (p.focusAreas.contains(FocusArea.health)) {
      add(const StarterHabit(
        title: 'Drink water',
        icon: '💧',
        type: HabitType.counter,
        identity: 'General',
        category: RoutineCategory.health,
        frequency: Frequency.daily,
        target: 8,
        unit: 'glasses',
      ));
    }
    if (picks.isEmpty) picks.addAll(_defaultHabitPack);
    return picks.take(6).toList();
  }

  List<StarterRoutine> generateStarterRoutines(UserProfile p) {
    final picks = <StarterRoutine>[];
    final seen = <String>{};

    void add(StarterRoutine r) {
      if (seen.add(r.title)) picks.add(r);
    }

    for (final id in p.identities) {
      for (final r in _byIdentity[id] ?? const <StarterRoutine>[]) {
        add(r);
      }
    }
    for (final area in p.focusAreas) {
      for (final r in _byFocus[area] ?? const <StarterRoutine>[]) {
        add(r);
      }
    }

    if (picks.isEmpty) picks.addAll(_defaultPack);

    final capped = picks.take(5).toList()
      ..sort((a, b) =>
          a.hourFor(p.chronotype).compareTo(b.hourFor(p.chronotype)));
    return capped;
  }

  static DateTime _todayAt(int hour, int minute) {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  static const _morningWorkout = StarterRoutine(
    title: 'Movement block',
    morningHour: 7,
    balancedHour: 8,
    nightHour: 10,
    minute: 0,
    durationMinutes: 45,
    category: RoutineCategory.health,
    meta: '45 min · move the body',
  );

  static const _deepWork = StarterRoutine(
    title: 'Deep work block',
    morningHour: 9,
    balancedHour: 10,
    nightHour: 20,
    minute: 0,
    durationMinutes: 90,
    category: RoutineCategory.work,
    meta: '90 min · peak focus',
  );

  static const _creativeSession = StarterRoutine(
    title: 'Creative session',
    morningHour: 11,
    balancedHour: 15,
    nightHour: 21,
    minute: 0,
    durationMinutes: 45,
    category: RoutineCategory.creative,
    meta: '45 min · make something',
  );

  static const _meditation = StarterRoutine(
    title: 'Meditation',
    morningHour: 6,
    balancedHour: 13,
    nightHour: 22,
    minute: 30,
    durationMinutes: 15,
    category: RoutineCategory.mindful,
    meta: '15 min · breathe and reset',
  );

  static const _walk = StarterRoutine(
    title: 'Walk & sunlight',
    morningHour: 12,
    balancedHour: 13,
    nightHour: 18,
    minute: 30,
    durationMinutes: 20,
    category: RoutineCategory.health,
    meta: '20 min · zone 2',
  );

  static const _reading = StarterRoutine(
    title: 'Reading block',
    morningHour: 8,
    balancedHour: 19,
    nightHour: 22,
    minute: 0,
    durationMinutes: 30,
    category: RoutineCategory.mindful,
    meta: '30 min · learn deeply',
  );

  static const _connectCall = StarterRoutine(
    title: 'Reach out',
    morningHour: 9,
    balancedHour: 12,
    nightHour: 19,
    minute: 30,
    durationMinutes: 20,
    category: RoutineCategory.creative,
    meta: '20 min · one person, one message',
  );

  static const _eveningReset = StarterRoutine(
    title: 'Evening reset',
    morningHour: 21,
    balancedHour: 21,
    nightHour: 23,
    minute: 0,
    durationMinutes: 20,
    category: RoutineCategory.rest,
    meta: 'journal · stretch · plan',
  );

  static const _planTomorrow = StarterRoutine(
    title: 'Plan tomorrow',
    morningHour: 20,
    balancedHour: 20,
    nightHour: 22,
    minute: 30,
    durationMinutes: 10,
    category: RoutineCategory.work,
    meta: '10 min · set 3 priorities',
  );

  static const Map<String, List<StarterRoutine>> _byIdentity = {
    'Athlete': [_morningWorkout, _walk],
    'Creator': [_deepWork, _creativeSession],
    'Mindful': [_meditation, _eveningReset],
    'Scholar': [_reading, _deepWork],
    'Connector': [_connectCall, _walk],
    'Leader': [_planTomorrow, _deepWork],
    'Entrepreneur': [_deepWork, _planTomorrow],
    'Parent': [_connectCall, _eveningReset],
  };

  static const Map<FocusArea, List<StarterRoutine>> _byFocus = {
    FocusArea.work: [_deepWork, _planTomorrow],
    FocusArea.health: [_morningWorkout, _walk],
    FocusArea.creativity: [_creativeSession],
    FocusArea.mindfulness: [_meditation, _eveningReset],
    FocusArea.relationships: [_connectCall],
    FocusArea.learning: [_reading],
  };

  static const _defaultPack = [
    _meditation,
    _deepWork,
    _walk,
    _eveningReset,
  ];

  static const Map<String, List<StarterHabit>> _habitsByIdentity = {
    'Athlete': [
      StarterHabit(
        title: 'Workout',
        icon: '💪',
        type: HabitType.duration,
        identity: 'Athlete',
        category: RoutineCategory.health,
        frequency: Frequency.daily,
        target: 30,
        unit: 'minutes',
      ),
    ],
    'Creator': [
      StarterHabit(
        title: 'Make something',
        icon: '🎨',
        type: HabitType.yesNo,
        identity: 'Creator',
        category: RoutineCategory.creative,
        frequency: Frequency.daily,
        target: 1,
        unit: null,
      ),
    ],
    'Mindful': [
      StarterHabit(
        title: 'Meditation',
        icon: '🧘',
        type: HabitType.duration,
        identity: 'Mindful',
        category: RoutineCategory.mindful,
        frequency: Frequency.daily,
        target: 10,
        unit: 'minutes',
      ),
    ],
    'Scholar': [
      StarterHabit(
        title: 'Read',
        icon: '📚',
        type: HabitType.duration,
        identity: 'Scholar',
        category: RoutineCategory.mindful,
        frequency: Frequency.daily,
        target: 30,
        unit: 'minutes',
      ),
    ],
    'Connector': [
      StarterHabit(
        title: 'Reach out to someone',
        icon: '❤️',
        type: HabitType.yesNo,
        identity: 'Connector',
        category: RoutineCategory.creative,
        frequency: Frequency.daily,
        target: 1,
        unit: null,
      ),
    ],
    'Leader': [
      StarterHabit(
        title: 'Plan tomorrow',
        icon: '🌟',
        type: HabitType.yesNo,
        identity: 'Leader',
        category: RoutineCategory.work,
        frequency: Frequency.daily,
        target: 1,
        unit: null,
      ),
    ],
    'Entrepreneur': [
      StarterHabit(
        title: 'Ship something',
        icon: '🚀',
        type: HabitType.yesNo,
        identity: 'Entrepreneur',
        category: RoutineCategory.work,
        frequency: Frequency.weekdays,
        target: 1,
        unit: null,
      ),
    ],
    'Parent': [
      StarterHabit(
        title: 'Quality time',
        icon: '👨‍👩‍👧',
        type: HabitType.duration,
        identity: 'Parent',
        category: RoutineCategory.creative,
        frequency: Frequency.daily,
        target: 30,
        unit: 'minutes',
      ),
    ],
  };

  static const _defaultHabitPack = [
    StarterHabit(
      title: 'Drink water',
      icon: '💧',
      type: HabitType.counter,
      identity: 'General',
      category: RoutineCategory.health,
      frequency: Frequency.daily,
      target: 8,
      unit: 'glasses',
    ),
    StarterHabit(
      title: 'Move',
      icon: '🚶',
      type: HabitType.duration,
      identity: 'General',
      category: RoutineCategory.health,
      frequency: Frequency.daily,
      target: 20,
      unit: 'minutes',
    ),
  ];
}

class StarterHabit {
  const StarterHabit({
    required this.title,
    required this.icon,
    required this.type,
    required this.identity,
    required this.category,
    required this.frequency,
    required this.target,
    required this.unit,
  });

  final String title;
  final String icon;
  final HabitType type;
  final String identity;
  final RoutineCategory category;
  final Frequency frequency;
  final int target;
  final String? unit;
}
