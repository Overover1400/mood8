import 'package:hive/hive.dart';

import 'focus_area.dart';

part 'user_profile.g.dart';

@HiveType(typeId: 5)
enum Chronotype {
  @HiveField(0)
  morningPerson,
  @HiveField(1)
  balanced,
  @HiveField(2)
  nightOwl;

  String get label {
    switch (this) {
      case Chronotype.morningPerson:
        return 'Morning person';
      case Chronotype.balanced:
        return 'Balanced';
      case Chronotype.nightOwl:
        return 'Night owl';
    }
  }

  String get tagline {
    switch (this) {
      case Chronotype.morningPerson:
        return 'I wake up energized';
      case Chronotype.balanced:
        return "I'm flexible throughout the day";
      case Chronotype.nightOwl:
        return 'I come alive in the evening';
    }
  }

  String get window {
    switch (this) {
      case Chronotype.morningPerson:
        return '5–9 AM peak';
      case Chronotype.balanced:
        return 'Even across the day';
      case Chronotype.nightOwl:
        return '8 PM+ peak';
    }
  }

  String get emoji {
    switch (this) {
      case Chronotype.morningPerson:
        return '🌅';
      case Chronotype.balanced:
        return '🌤️';
      case Chronotype.nightOwl:
        return '🌙';
    }
  }
}

@HiveType(typeId: 3)
class UserProfile extends HiveObject {
  UserProfile({
    required this.name,
    required this.identities,
    required this.focusAreas,
    required this.hasCompletedOnboarding,
    required this.createdAt,
    required this.chronotype,
  });

  @HiveField(0)
  String name;

  @HiveField(1)
  List<String> identities;

  @HiveField(2)
  List<FocusArea> focusAreas;

  @HiveField(3)
  bool hasCompletedOnboarding;

  @HiveField(4)
  DateTime createdAt;

  @HiveField(5)
  Chronotype chronotype;
}
