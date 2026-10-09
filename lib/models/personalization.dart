import 'frequency.dart';
import 'habit_type.dart';
import 'routine_category.dart';

/// One habit the server proposes for this user. It is only a proposal: the
/// user adds it (or not) in the sheet.
class PersonalizedSuggestion {
  const PersonalizedSuggestion({
    required this.key,
    required this.title,
    required this.icon,
    required this.type,
    required this.category,
    required this.frequency,
    required this.why,
    this.target,
    this.unit,
    this.time,
    this.difficulty = 2,
    this.identity = 'General',
    this.source = 'identity',
  });

  final String key;
  final String title;
  final String icon;
  final HabitType type;
  final RoutineCategory category;
  final Frequency frequency;
  final int? target;
  final String? unit;

  /// "HH:MM", 24h, or null.
  final String? time;
  final int difficulty;
  final String identity;
  final String why;

  /// identity · goal · similar_users
  final String source;

  /// Reminder minute-of-day for [time], or null when absent / malformed.
  int? get reminderMinute {
    final t = time;
    if (t == null) return null;
    final parts = t.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) {
      return null;
    }
    return h * 60 + m;
  }

  /// "25 minutes", "8 glasses", or '' for yes/no.
  String get amountLabel {
    if (type == HabitType.yesNo || target == null) return '';
    final u = (unit ?? '').trim();
    return u.isEmpty ? '$target' : '$target $u';
  }

  static HabitType _type(String? s) => switch (s) {
        'counter' => HabitType.counter,
        'duration' => HabitType.duration,
        _ => HabitType.yesNo,
      };

  static RoutineCategory _category(String? s) => switch (s) {
        'work' => RoutineCategory.work,
        'mindful' => RoutineCategory.mindful,
        'creative' => RoutineCategory.creative,
        'rest' => RoutineCategory.rest,
        _ => RoutineCategory.health,
      };

  static Frequency _frequency(String? s) => switch (s) {
        'weekdays' => Frequency.weekdays,
        'weekends' => Frequency.weekends,
        _ => Frequency.daily,
      };

  factory PersonalizedSuggestion.fromJson(Map<String, dynamic> j) =>
      PersonalizedSuggestion(
        key: (j['key'] as String?) ?? (j['title'] as String? ?? ''),
        title: (j['title'] as String?) ?? '',
        icon: (j['icon'] as String?) ?? '✨',
        type: _type(j['type'] as String?),
        category: _category(j['category'] as String?),
        frequency: _frequency(j['frequency'] as String?),
        target: (j['target'] as num?)?.toInt(),
        unit: j['unit'] as String?,
        time: j['time'] as String?,
        difficulty: (j['difficulty'] as num?)?.toInt() ?? 2,
        identity: (j['identity'] as String?) ?? 'General',
        why: (j['why'] as String?) ?? '',
        source: (j['source'] as String?) ?? 'identity',
      );
}

class FollowUpOption {
  const FollowUpOption(this.value, this.label);
  final String value;
  final String label;
}

/// A single question the server wants answered to personalise better.
class FollowUpQuestion {
  const FollowUpQuestion({
    required this.key,
    required this.question,
    required this.options,
    this.multi = false,
  });

  final String key;
  final String question;
  final bool multi;
  final List<FollowUpOption> options;

  static FollowUpQuestion? tryParse(dynamic raw) {
    if (raw is! Map) return null;
    final key = raw['key'] as String?;
    final q = raw['question'] as String?;
    if (key == null || q == null) return null;
    final opts = <FollowUpOption>[
      for (final o in (raw['options'] as List?) ?? const [])
        if (o is Map && o['value'] is String)
          FollowUpOption(
              o['value'] as String, (o['label'] as String?) ?? o['value']),
    ];
    if (opts.isEmpty) return null;
    return FollowUpQuestion(
      key: key,
      question: q,
      multi: raw['multi'] == true,
      options: opts,
    );
  }
}

/// What the suggestions are based on, so the UI never claims more than the
/// server did.
class PersonalizationBasis {
  const PersonalizationBasis({
    this.identity,
    this.goalAreas = const [],
    this.behaviour = false,
    this.freshEnergy = 'none',
    this.similarUsers = 'insufficient_data',
    this.level = 2,
  });

  final String? identity;
  final List<String> goalAreas;
  final bool behaviour;

  /// low · ok · none
  final String freshEnergy;

  /// used · insufficient_data
  final String similarUsers;
  final int level;

  factory PersonalizationBasis.fromJson(Map<String, dynamic>? j) {
    if (j == null) return const PersonalizationBasis();
    return PersonalizationBasis(
      identity: j['identity'] as String?,
      goalAreas: [
        for (final g in (j['goal_areas'] as List?) ?? const [])
          if (g is String) g
      ],
      behaviour: j['behaviour'] == true,
      freshEnergy: (j['fresh_energy'] as String?) ?? 'none',
      similarUsers: (j['similar_users'] as String?) ?? 'insufficient_data',
      level: (j['level'] as num?)?.toInt() ?? 2,
    );
  }
}

class PersonalizationResult {
  const PersonalizationResult({
    required this.suggestions,
    this.followUp,
    this.basis = const PersonalizationBasis(),
    this.slotsLeft,
  });

  final List<PersonalizedSuggestion> suggestions;
  final FollowUpQuestion? followUp;
  final PersonalizationBasis basis;

  /// Free habit slots left; null = no cap on this account.
  final int? slotsLeft;

  bool get isEmpty => suggestions.isEmpty && followUp == null;

  /// One honest line about what the suggestions rest on. It never mentions
  /// similar users unless the server actually used them.
  String get basisLine {
    final parts = <String>[
      if (basis.identity != null) 'your ${basis.identity} identity',
      if (basis.goalAreas.isNotEmpty)
        'your focus on ${_join(basis.goalAreas)}',
      if (basis.behaviour) 'your recent habits',
      if (basis.freshEnergy == 'low') 'your low energy lately',
      if (basis.similarUsers == 'used') 'people with a similar rhythm',
    ];
    if (parts.isEmpty) return 'Based on a few general starting points';
    return 'Based on ${_join(parts)}';
  }

  static String _join(List<String> xs) {
    if (xs.length == 1) return xs.first;
    return '${xs.sublist(0, xs.length - 1).join(', ')} and ${xs.last}';
  }

  /// Suggestions the user doesn't already have (case-insensitive title).
  List<PersonalizedSuggestion> without(Iterable<String> existingTitles) {
    final have = {for (final t in existingTitles) t.trim().toLowerCase()};
    return [
      for (final s in suggestions)
        if (!have.contains(s.title.trim().toLowerCase())) s
    ];
  }

  factory PersonalizationResult.fromJson(Map<String, dynamic> j) =>
      PersonalizationResult(
        suggestions: [
          for (final s in (j['suggestions'] as List?) ?? const [])
            if (s is Map<String, dynamic>) PersonalizedSuggestion.fromJson(s)
        ].where((s) => s.title.trim().isNotEmpty).toList(),
        followUp: FollowUpQuestion.tryParse(j['follow_up']),
        basis: PersonalizationBasis.fromJson(
            (j['basis'] as Map?)?.cast<String, dynamic>()),
        slotsLeft: (j['slots_left'] as num?)?.toInt(),
      );
}
