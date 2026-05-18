enum Milestone {
  firstWeek,
  firstMonth,
  century,
  year,
  identity25,
  identity50,
  identity75,
  identityComplete;

  /// Stable key used to mark this milestone as "already shown" in
  /// SharedPreferences. For identity milestones, append the identity name
  /// (e.g. `identity25:Athlete`).
  String key([String? extra]) {
    final base = 'mood8.milestone.$name';
    if (extra == null || extra.isEmpty) return base;
    return '$base:$extra';
  }

  String title({String? identity}) {
    switch (this) {
      case Milestone.firstWeek:
        return '7-day streak';
      case Milestone.firstMonth:
        return '30-day streak';
      case Milestone.century:
        return '100 days';
      case Milestone.year:
        return 'One year';
      case Milestone.identity25:
        return identity == null ? '25% there' : '25% $identity';
      case Milestone.identity50:
        return identity == null ? 'Halfway there' : 'Halfway $identity';
      case Milestone.identity75:
        return identity == null ? '75% there' : '75% $identity — almost';
      case Milestone.identityComplete:
        return identity == null ? 'Identity unlocked' : "You're a $identity";
    }
  }

  String message({String? identity}) {
    switch (this) {
      case Milestone.firstWeek:
        return 'A week in. Compounding starts now.';
      case Milestone.firstMonth:
        return 'A month of small votes for who you are becoming.';
      case Milestone.century:
        return 'One hundred. Few people make it this far.';
      case Milestone.year:
        return "A whole year. You're a different person.";
      case Milestone.identity25:
        return identity == null
            ? 'A quarter of the way to who you want to be.'
            : 'A quarter $identity. Keep voting.';
      case Milestone.identity50:
        return identity == null
            ? 'Halfway through the change.'
            : "Halfway $identity. Don't coast.";
      case Milestone.identity75:
        return identity == null
            ? 'The hard part is behind you.'
            : 'Three quarters $identity. Finish strong.';
      case Milestone.identityComplete:
        return identity == null
            ? 'You did the thing.'
            : "You're a $identity. The vote's in.";
    }
  }
}
