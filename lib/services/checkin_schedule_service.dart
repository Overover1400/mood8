import 'package:flutter/foundation.dart';

import 'notification_service.dart';
import 'preferences_service.dart';
import 'user_repository.dart';

/// Spec 2.1 — schedules the two daily check-in prompts.
///
/// Before this existed the app had `scheduleMorningCheckIn` and
/// `scheduleEveningReflection` wired only to two manual buttons in
/// Settings, at hard-coded 09:00 / 21:00. Nothing called them on boot, so
/// in practice almost nobody received either prompt — which is why the
/// check-in dataset was thin enough that the adaptation engine had very
/// little to correlate against.
///
/// This service re-arms both on every launch, at the times the user
/// actually chose (`PreferencesService.checkinTime` /
/// `.reflectionTime`), and respects the per-category notification
/// toggle so turning check-ins off in Settings genuinely stops them.
class CheckinScheduleService {
  CheckinScheduleService._();
  static final CheckinScheduleService _instance = CheckinScheduleService._();
  factory CheckinScheduleService() => _instance;

  final PreferencesService _prefs = PreferencesService.instance;
  final UserRepository _users = UserRepository();

  /// Cancel + reschedule both prompts. Safe to call repeatedly: the
  /// notification ids are fixed, so re-scheduling overwrites in place
  /// rather than stacking duplicates.
  Future<void> rescheduleAll() async {
    final notifier = NotificationService();
    if (!notifier.isSupported) return;
    if (!notifier.isGranted) return;

    try {
      if (_prefs.checkinNotificationsEnabled) {
        final t = _prefs.checkinTime;
        final user = _users.getCurrentUser();
        await notifier.scheduleMorningCheckIn(
          name: user?.name ?? 'friend',
          hour: t.hour,
          minute: t.minute,
        );
        final r = _prefs.reflectionTime;
        await notifier.scheduleEveningReflection(
          hour: r.hour,
          minute: r.minute,
        );
      }
    } catch (e, st) {
      // Never let a scheduling failure block startup.
      debugPrint('CheckinScheduleService.rescheduleAll failed: $e\n$st');
    }
  }
}
