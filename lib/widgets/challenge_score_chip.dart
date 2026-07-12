import 'package:flutter/material.dart';

import '../models/challenge.dart' show tierColor;

/// Compact tier-colored "1.2k" chip shown next to a user's name in
/// every Challenges surface: participant lists, comments, join
/// requests, creator card previews. Deliberately small — score reads
/// as a prefix, not a banner. Renders nothing when [score] <= 0 so
/// brand-new users don't clutter rows with "Bronze · 0" chips.
class ChallengeScoreChip extends StatelessWidget {
  const ChallengeScoreChip({
    super.key,
    required this.score,
    required this.tier,
    this.dense = false,
  });

  final int score;
  final String tier;

  /// Even smaller variant for very tight rows (comment headers,
  /// inline lists). Drops the trophy icon and pads a hair less.
  final bool dense;

  static String _formatScore(int s) {
    if (s < 1000) return '$s';
    if (s < 10000) {
      final k = s / 1000;
      return '${k.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}k';
    }
    return '${(s / 1000).round()}k';
  }

  @override
  Widget build(BuildContext context) {
    if (score <= 0) return const SizedBox.shrink();
    final c = tierColor(tier);
    final fs = dense ? 10.0 : 10.5;
    final iconSize = dense ? 10.0 : 11.0;
    final hPad = dense ? 6.0 : 7.0;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.50), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!dense) ...[
            Icon(Icons.emoji_events_rounded, color: c, size: iconSize),
            const SizedBox(width: 3),
          ],
          Text(
            _formatScore(score),
            style: TextStyle(
              color: c,
              fontSize: fs,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
