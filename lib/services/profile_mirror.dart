import '../models/focus_area.dart';
import '../models/user_profile.dart';

/// Mirror an edited profile answer into the on-device profile, so the
/// Habits filters and the server's suggestions never disagree about who
/// the user says they are. Returns true when [p] changed (the caller
/// saves it). Answers that only the server uses (energy peak, usual
/// reason) leave the device profile alone.
bool applyProfileAnswer(UserProfile p, String key, Object value) {
  switch (key) {
    case 'identity':
      final v = value is String ? value.trim() : '';
      if (v.isEmpty) return false;
      if (p.identities.isNotEmpty && p.identities.first == v) return false;
      p.identities = [v, ...p.identities.where((i) => i != v)];
      return true;
    case 'goal_areas':
      final names = value is List ? value.whereType<String>() : const <String>[];
      final areas = [
        for (final n in names)
          for (final a in FocusArea.values)
            if (a.name == n) a
      ];
      if (areas.isEmpty) return false;
      p.focusAreas = areas;
      return true;
    default:
      return false;
  }
}
