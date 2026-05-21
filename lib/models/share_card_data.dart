/// Snapshot of the user's current stats, formatted for the share card.
/// Built once on screen entry and passed to [ShareCard] / [ShareService].
class ShareCardData {
  const ShareCardData({
    required this.userName,
    required this.streakDays,
    required this.avgMood,
    required this.habitsCompleted,
    required this.disciplineScore,
    required this.identities,
    required this.weekStart,
    required this.weekEnd,
  });

  /// User's display name, or null if unknown (we fall back to "My week").
  final String? userName;
  final int streakDays;
  final double? avgMood;   // 0–10
  final int habitsCompleted;
  final int disciplineScore; // 0–100
  final List<String> identities;
  final DateTime weekStart;
  final DateTime weekEnd;
}

enum ShareCardTemplate {
  weekRecap,
  streakMilestone,
  identityProgress,
}

enum ShareCardFormat {
  /// 1080 × 1080 — Instagram feed / Twitter card.
  square,
  /// 1080 × 1920 — Instagram / Snapchat / TikTok story.
  story,
}

extension ShareCardFormatX on ShareCardFormat {
  /// Logical layout size that, captured at pixelRatio=1, yields the
  /// canonical export resolution.
  double get width => 1080;
  double get height => this == ShareCardFormat.square ? 1080 : 1920;
  double get aspect => width / height;
  String get label => this == ShareCardFormat.square ? 'Square' : 'Story';
}

extension ShareCardTemplateX on ShareCardTemplate {
  String get label {
    switch (this) {
      case ShareCardTemplate.weekRecap:
        return 'Week recap';
      case ShareCardTemplate.streakMilestone:
        return 'Streak';
      case ShareCardTemplate.identityProgress:
        return 'Identity';
    }
  }
}
