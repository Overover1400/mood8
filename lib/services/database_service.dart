import 'package:hive_flutter/hive_flutter.dart';

import '../models/badge_category.dart';
import '../models/chat_message.dart';
import '../models/earned_badge.dart';
import '../models/focus_area.dart';
import '../models/frequency.dart';
import '../models/gratitude_entry.dart';
import '../models/habit.dart';
import '../models/habit_log.dart';
import '../models/habit_type.dart';
import '../models/insight.dart';
import '../models/insight_type.dart';
import '../models/mood_entry.dart';
import '../models/morning_intention.dart';
import '../models/reflection.dart';
import '../models/reminder_settings.dart';
import '../models/routine_category.dart';
import '../models/routine_item.dart';
import '../models/subscription.dart';
import '../models/user_profile.dart';
import '../models/weekly_recap.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  static const String moodBoxName = 'mood_entries';
  static const String routineBoxName = 'routines';
  static const String userBoxName = 'users';
  static const String reflectionBoxName = 'reflections';
  static const String chatBoxName = 'chat_messages';
  static const String habitBoxName = 'habits';
  static const String habitLogBoxName = 'habit_logs';
  static const String insightBoxName = 'insights';
  static const String intentionBoxName = 'morning_intentions';
  static const String gratitudeBoxName = 'gratitude_entries';
  static const String badgeBoxName = 'earned_badges';
  static const String reminderSettingsBoxName = 'reminder_settings';
  static const String weeklyRecapBoxName = 'weekly_recaps';

  bool _initialized = false;
  late Box<MoodEntry> _moodBox;
  late Box<RoutineItem> _routineBox;
  late Box<UserProfile> _userBox;
  late Box<Reflection> _reflectionBox;
  late Box<ChatMessage> _chatBox;
  late Box<Habit> _habitBox;
  late Box<HabitLog> _habitLogBox;
  late Box<Insight> _insightBox;
  late Box<MorningIntention> _intentionBox;
  late Box<GratitudeEntry> _gratitudeBox;
  late Box<EarnedBadge> _badgeBox;
  late Box<ReminderSettings> _reminderSettingsBox;
  late Box<WeeklyRecap> _weeklyRecapBox;

  Box<MoodEntry> get moodBox => _moodBox;
  Box<RoutineItem> get routineBox => _routineBox;
  Box<UserProfile> get userBox => _userBox;
  Box<Reflection> get reflectionBox => _reflectionBox;
  Box<ChatMessage> get chatBox => _chatBox;
  Box<Habit> get habitBox => _habitBox;
  Box<HabitLog> get habitLogBox => _habitLogBox;
  Box<Insight> get insightBox => _insightBox;
  Box<MorningIntention> get intentionBox => _intentionBox;
  Box<GratitudeEntry> get gratitudeBox => _gratitudeBox;
  Box<EarnedBadge> get badgeBox => _badgeBox;
  Box<ReminderSettings> get reminderSettingsBox => _reminderSettingsBox;
  Box<WeeklyRecap> get weeklyRecapBox => _weeklyRecapBox;

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
    if (!Hive.isAdapterRegistered(6)) {
      Hive.registerAdapter(ReflectionAdapter());
    }
    if (!Hive.isAdapterRegistered(7)) {
      Hive.registerAdapter(ChatMessageAdapter());
    }
    if (!Hive.isAdapterRegistered(8)) {
      Hive.registerAdapter(HabitAdapter());
    }
    if (!Hive.isAdapterRegistered(9)) {
      Hive.registerAdapter(HabitTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(10)) {
      Hive.registerAdapter(FrequencyAdapter());
    }
    if (!Hive.isAdapterRegistered(11)) {
      Hive.registerAdapter(HabitLogAdapter());
    }
    if (!Hive.isAdapterRegistered(12)) {
      Hive.registerAdapter(InsightAdapter());
    }
    if (!Hive.isAdapterRegistered(13)) {
      Hive.registerAdapter(InsightTypeAdapter());
    }
    if (!Hive.isAdapterRegistered(14)) {
      Hive.registerAdapter(SubscriptionTierAdapter());
    }
    if (!Hive.isAdapterRegistered(15)) {
      Hive.registerAdapter(MorningIntentionAdapter());
    }
    if (!Hive.isAdapterRegistered(16)) {
      Hive.registerAdapter(GratitudeEntryAdapter());
    }
    if (!Hive.isAdapterRegistered(17)) {
      Hive.registerAdapter(EarnedBadgeAdapter());
    }
    if (!Hive.isAdapterRegistered(18)) {
      Hive.registerAdapter(BadgeCategoryAdapter());
    }
    if (!Hive.isAdapterRegistered(19)) {
      Hive.registerAdapter(ReminderSettingsAdapter());
    }
    if (!Hive.isAdapterRegistered(20)) {
      Hive.registerAdapter(WeeklyRecapAdapter());
    }

    _moodBox = await Hive.openBox<MoodEntry>(moodBoxName);
    _routineBox = await Hive.openBox<RoutineItem>(routineBoxName);
    _userBox = await Hive.openBox<UserProfile>(userBoxName);
    _reflectionBox = await Hive.openBox<Reflection>(reflectionBoxName);
    _chatBox = await Hive.openBox<ChatMessage>(chatBoxName);
    _habitBox = await Hive.openBox<Habit>(habitBoxName);
    _habitLogBox = await Hive.openBox<HabitLog>(habitLogBoxName);
    _insightBox = await Hive.openBox<Insight>(insightBoxName);
    _intentionBox =
        await Hive.openBox<MorningIntention>(intentionBoxName);
    _gratitudeBox =
        await Hive.openBox<GratitudeEntry>(gratitudeBoxName);
    _badgeBox = await Hive.openBox<EarnedBadge>(badgeBoxName);
    _reminderSettingsBox =
        await Hive.openBox<ReminderSettings>(reminderSettingsBoxName);
    _weeklyRecapBox =
        await Hive.openBox<WeeklyRecap>(weeklyRecapBoxName);
    _initialized = true;
  }

  Future<void> close() async {
    if (!_initialized) return;
    await _moodBox.close();
    await _routineBox.close();
    await _userBox.close();
    await _reflectionBox.close();
    await _chatBox.close();
    await _habitBox.close();
    await _habitLogBox.close();
    await _insightBox.close();
    await _intentionBox.close();
    await _gratitudeBox.close();
    await _badgeBox.close();
    await _reminderSettingsBox.close();
    await _weeklyRecapBox.close();
    _initialized = false;
  }
}
