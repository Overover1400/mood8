import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/adaptive_suggestion.dart';
import '../models/sfx_type.dart';
import '../services/haptic_service.dart';
import '../services/sfx_service.dart';
import '../theme/app_theme.dart';

class AdaptiveSuggestionCard extends StatelessWidget {
  const AdaptiveSuggestionCard({
    super.key,
    required this.suggestion,
    required this.onApply,
    required this.onDismiss,
    this.applying = false,
  });

  final AdaptiveSuggestion suggestion;
  final VoidCallback onApply;
  final VoidCallback onDismiss;
  final bool applying;

  @override
  Widget build(BuildContext context) {
    final tone = suggestion.tone;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tone.withValues(alpha: 0.20),
            tone.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: tone.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: tone.withValues(alpha: 0.45)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(suggestion.icon, color: tone, size: 12),
                    const SizedBox(width: 6),
                    Text(
                      suggestion.badge.toUpperCase(),
                      style: TextStyle(
                        color: tone,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  HapticService().selection();
                  onDismiss();
                },
                tooltip: 'Dismiss for today',
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
                icon: Icon(Icons.close_rounded,
                    color: BrandColors.inkDim(context), size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            suggestion.title,
            style: GoogleFonts.instrumentSerif(
              color: BrandColors.ink(context),
              fontStyle: FontStyle.italic,
              fontSize: 20,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            suggestion.reason,
            style: TextStyle(
              color: BrandColors.inkSoft(context),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Spacer(),
              _GhostButton(
                label: applying ? 'Applying…' : 'Apply',
                onTap: applying
                    ? null
                    : () {
                        HapticService().medium();
                        SfxService().fire(SfxType.checkInSuccess);
                        onApply();
                      },
                tone: tone,
                filled: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.label,
    required this.onTap,
    required this.tone,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onTap;
  final Color tone;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Opacity(
          opacity: disabled ? 0.6 : 1.0,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: filled ? tone.withValues(alpha: 0.25) : null,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: tone.withValues(alpha: 0.55)),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: tone,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
