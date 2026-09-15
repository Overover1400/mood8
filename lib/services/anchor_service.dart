import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/habit.dart';
import '../models/routine_category.dart';

/// Spec 3.2 — habit anchoring (implementation intentions).
///
/// "After I make coffee, I read 10 pages."
///
/// Attaching a new habit to an existing routine is one of the most
/// consistently replicated effects in behavioural science: naming *when
/// and where* a behaviour will happen raises the rate at which it
/// actually happens. That published grounding is the point — the method
/// can be checked against the literature rather than taken on our word.
///
/// Deliberately not a field on the create-habit form (spec 6). The offer
/// appears in the normal flow, once, for a habit that is being missed
/// and has no anchor yet.
class AnchorService {
  AnchorService._();
  static final AnchorService _instance = AnchorService._();
  factory AnchorService() => _instance;

  static const _kOfferedOn = 'anchor_offered_on';
  static const _kDeclinedPrefix = 'anchor_declined_';

  /// Candidate anchors, ordered so the most common daily routines come
  /// first. All are things nearly everyone already does at a fixed point
  /// in the day — an anchor only works if it is itself reliable.
  static const List<String> _common = [
    'I wake up',
    'I make coffee',
    'I finish breakfast',
    'I brush my teeth',
    'I get home from work',
    'I finish dinner',
    'I get into bed',
  ];

  /// Category-appropriate anchors shown first, then the common ones.
  /// A study habit anchored to "after I get into bed" is a worse
  /// suggestion than one anchored to "after I get home from work".
  List<String> suggestionsFor(Habit h) {
    final preferred = switch (h.category) {
      RoutineCategory.health => ['I wake up', 'I get home from work'],
      RoutineCategory.mindful => ['I get into bed', 'I make coffee'],
      RoutineCategory.work => ['I make coffee', 'I finish breakfast'],
      RoutineCategory.creative => ['I finish dinner', 'I make coffee'],
      RoutineCategory.rest => ['I finish dinner', 'I get into bed'],
    };
    final out = <String>[...preferred];
    for (final c in _common) {
      if (!out.contains(c)) out.add(c);
    }
    return out.take(5).toList();
  }

  /// The full sentence, for display.
  String sentenceFor(Habit h) {
    final a = h.anchor;
    if (a == null || a.trim().isEmpty) return '';
    return 'After ${a.trim()}, I ${h.title.toLowerCase()}.';
  }

  /// Offer at most one anchor per day across the whole app — this is a
  /// suggestion, and a suggestion that arrives repeatedly becomes
  /// nagging (spec 8).
  Future<bool> shouldOfferToday() async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getString(_kOfferedOn) != _todayStamp();
    } catch (e) {
      debugPrint('AnchorService.shouldOfferToday failed: $e');
      return false;
    }
  }

  Future<void> markOffered() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kOfferedOn, _todayStamp());
    } catch (e) {
      debugPrint('AnchorService.markOffered failed: $e');
    }
  }

  /// A declined habit is never asked about again. Saying no once is an
  /// answer, not an invitation to ask next week.
  Future<void> markDeclined(Habit h) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('$_kDeclinedPrefix${h.id}', true);
    } catch (e) {
      debugPrint('AnchorService.markDeclined failed: $e');
    }
  }

  Future<bool> wasDeclined(Habit h) async {
    try {
      final p = await SharedPreferences.getInstance();
      return p.getBool('$_kDeclinedPrefix${h.id}') ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Pick the habit worth anchoring: un-anchored, not archived, not
  /// already declined, and currently being missed often enough that a
  /// suggestion is useful rather than noise.
  ///
  /// [missCountFor] returns misses in the trailing week for a habit.
  Future<Habit?> pickCandidate(
    List<Habit> habits,
    int Function(Habit) missCountFor,
  ) async {
    Habit? best;
    var bestMisses = 0;
    for (final h in habits) {
      if (h.isArchived) continue;
      if ((h.anchor ?? '').trim().isNotEmpty) continue;
      final misses = missCountFor(h);
      // Two misses in a week is a pattern; one is noise (spec 1.2).
      if (misses < 2) continue;
      if (await wasDeclined(h)) continue;
      if (misses > bestMisses) {
        best = h;
        bestMisses = misses;
      }
    }
    return best;
  }

  static String _todayStamp() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }
}
