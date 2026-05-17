import 'package:hive_flutter/hive_flutter.dart';

import '../models/focus_area.dart';
import '../models/mood_entry.dart';
import '../models/routine_category.dart';
import '../models/routine_item.dart';
import '../models/user_profile.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const String moodBoxName = 'mood_entries';
  static const String routineBoxName = 'routines';
  static const String userBoxName = 'users';

  bool _initialized = false;
  late Box<MoodEntry> _moodBox;
  late Box<RoutineItem> _routineBox;
  late Box<UserProfile> _userBox;

  Box<MoodEntry> get moodBox => _moodBox;
  Box<RoutineItem> get routineBox => _routineBox;
  Box<UserProfile> get userBox => _userBox;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(MoodEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(RoutineItemAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(RoutineCategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(UserProfileAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(FocusAreaAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(ChronotypeAdapter());
    }

    _moodBox = await Hive.openBox<MoodEntry>(moodBoxName);
    _routineBox = await Hive.openBox<RoutineItem>(routineBoxName);
    _userBox = await Hive.openBox<UserProfile>(userBoxName);
    _initialized = true;
  }

  Future<void> close() async {
    if (!_initialized) return;
    await _moodBox.close();
    await _routineBox.close();
    await _userBox.close();
    _initialized = false;
  }
}
