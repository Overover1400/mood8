import 'package:hive/hive.dart';

part 'reminder_settings.g.dart';

/// Singleton settings record — stored under the [boxKey] in the
/// `reminder_settings` box (`ReminderService.getSettings()` does the
/// upsert dance).
///
/// Times use **minutes from midnight**: e.g. 540 = 09:00, 1320 = 22:00.
/// Quiet window may wrap midnight (start > end means "from start to
/// midnight, then midnight to end").
@HiveType(typeId: 19)
class ReminderSettings extends HiveObject {
  ReminderSettings({
    bool? enabled,
    List<int>? reminderTimes,
    bool? smartSkip,
    bool? quietHoursEnabled,
    int? quietStart,
    int? quietEnd,
    this.updatedAt,
  })  : enabled = enabled ?? true,
        // Defaults: 09:00, 14:00, 20:00.
        reminderTimes = reminderTimes ?? const <int>[540, 840, 1200],
        smartSkip = smartSkip ?? true,
        quietHoursEnabled = quietHoursEnabled ?? true,
        // 22:00 → 07:00 next day.
        quietStart = quietStart ?? 1320,
        quietEnd = quietEnd ?? 420;

  /// Stable key inside the box. `'settings'` is the only record.
  static const String boxKey = 'settings';

  @HiveField(0)
  bool enabled;

  @HiveField(1)
  List<int> reminderTimes;

  @HiveField(2)
  bool smartSkip;

  @HiveField(3)
  bool quietHoursEnabled;

  @HiveField(4)
  int quietStart;

  @HiveField(5)
  int quietEnd;

  @HiveField(6)
  DateTime? updatedAt;

  ReminderSettings copyWith({
    bool? enabled,
    List<int>? reminderTimes,
    bool? smartSkip,
    bool? quietHoursEnabled,
    int? quietStart,
    int? quietEnd,
  }) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      reminderTimes: reminderTimes ?? List<int>.from(this.reminderTimes),
      smartSkip: smartSkip ?? this.smartSkip,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietStart: quietStart ?? this.quietStart,
      quietEnd: quietEnd ?? this.quietEnd,
    );
  }
}
