import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:share_plus/share_plus.dart';

import '../models/share_card_data.dart';
import 'analytics_service.dart';
import 'export_downloader.dart';
import 'habit_repository.dart';
import 'mood_repository.dart';
import 'score_service.dart';
import 'user_repository.dart';
import 'year_in_review_service.dart';

/// Renders [ShareCard] to a PNG at its canonical resolution and routes
/// it through the native share sheet (mobile) or a web download.
class ShareService {
  ShareService._();
  static final ShareService _instance = ShareService._();
  factory ShareService() => _instance;

  /// Build a [ShareCardData] from the user's current Hive state.
  /// Reads the same data sources that ProgressScreen / HomeScreen
  /// already use, so the numbers on the card match the in-app numbers.
  ///
  /// For [ShareCardTemplate.yearInReview] the snapshot covers the
  /// user's full calendar year instead of the last 7 days, sourced
  /// from [YearInReviewService] so the card matches the YIR story.
  Future<ShareCardData> buildCurrentSnapshot({
    ShareCardTemplate template = ShareCardTemplate.weekRecap,
  }) async {
    if (template == ShareCardTemplate.yearInReview) {
      return _buildYearSnapshot();
    }
    final user = UserRepository().getCurrentUser();
    final moods = MoodRepository();
    final habits = HabitRepository();
    final analytics = AnalyticsService();
    final score = ScoreService();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(const Duration(days: 6));

    final streak = moods.calculateStreak();
    final avgMoodRaw = analytics.getAverageMood(7);
    // analytics returns 0.0 when no entries exist; treat that as "no
    // data" so the card shows blank instead of a flat 0.
    final hasMoodData = moods
        .getAllEntries()
        .any((e) => !e.timestamp.isBefore(weekStart));
    final avgMood = hasMoodData ? avgMoodRaw : null;

    int habitsCompleted = 0;
    for (final h in habits.getActiveHabits()) {
      habitsCompleted += habits
          .getLogsForHabit(
            h.id,
            from: weekStart,
            to: today.add(const Duration(days: 1)),
          )
          .where((l) => l.isCompleted)
          .length;
    }

    return ShareCardData(
      userName: user?.name,
      streakDays: streak,
      avgMood: avgMood,
      habitsCompleted: habitsCompleted,
      disciplineScore: score.getDisciplineScore(),
      identities: user?.identities ?? const [],
      weekStart: weekStart,
      weekEnd: today,
    );
  }

  /// Year-scale snapshot used by the Year in Review share template.
  /// Repurposes ShareCardData's existing fields:
  ///   streakDays      → longest streak of the year
  ///   habitsCompleted → total habits checked off all year
  ///   avgMood         → year average
  ///   disciplineScore → days active (label is overridden in _StatRow)
  ///   weekStart/End   → first and last day of the recap window
  Future<ShareCardData> _buildYearSnapshot() async {
    final now = DateTime.now();
    final year = now.month == 1 ? now.year - 1 : now.year;
    final yir = await YearInReviewService().generateForYear(year);
    return ShareCardData(
      userName: yir.userName,
      streakDays: yir.longestStreakDays,
      avgMood: yir.avgMood,
      habitsCompleted: yir.totalHabitsCompleted,
      disciplineScore: yir.daysActive,
      identities: yir.identities,
      weekStart: yir.windowStart,
      weekEnd: yir.windowEnd,
    );
  }

  /// Capture the [RepaintBoundary] keyed by [boundaryKey] to a PNG.
  /// Caller is expected to host the boundary in the widget tree at the
  /// card's design resolution (1080×1080 or 1080×1920).
  Future<Uint8List?> captureAsPng(GlobalKey boundaryKey) async {
    try {
      final ctx = boundaryKey.currentContext;
      final boundary = ctx?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('[Share] capture: no RenderRepaintBoundary at key');
        return null;
      }
      // Boundary is laid out at design pixels (1080×1080 or 1080×1920)
      // so pixelRatio: 1.0 already yields the canonical export size.
      // Higher ratios would just bloat the file with redundant data.
      final ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('[Share] captureAsPng failed: $e');
      return null;
    }
  }

  /// Captures + invokes the native share sheet (mobile) or downloads
  /// the PNG (web). Returns true on success.
  Future<bool> shareCard(
    GlobalKey boundaryKey, {
    required ShareCardFormat format,
    String shareText = 'My week on Mood8 ✨ — mood8.app',
  }) async {
    final bytes = await captureAsPng(boundaryKey);
    if (bytes == null) return false;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final filename = 'mood8-share-$stamp.png';
    if (kIsWeb) {
      // Web Share API for files is patchy across browsers. The
      // ExportDownloader path triggers a clean download — users can
      // attach the file to whatever they want.
      return ExportDownloader().downloadBytes(
        bytes: bytes,
        filename: filename,
        mimeType: 'image/png',
      );
    }
    try {
      final file = XFile.fromData(
        bytes,
        name: filename,
        mimeType: 'image/png',
      );
      await Share.shareXFiles([file], text: shareText);
      return true;
    } catch (e) {
      debugPrint('[Share] shareXFiles failed: $e');
      return false;
    }
  }

  /// Save-to-device variant — same as [shareCard] on web (download),
  /// uses share_plus on mobile which writes to the user-chosen target
  /// app (Files, Photos, etc.).
  Future<bool> saveCardToDevice(
    GlobalKey boundaryKey, {
    required ShareCardFormat format,
  }) =>
      shareCard(boundaryKey, format: format, shareText: 'Mood8 share card');
}
