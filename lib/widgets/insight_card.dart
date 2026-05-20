import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/insight.dart';
import '../models/insight_type.dart';
import '../services/insights_ai_service.dart';
import '../theme/app_theme.dart';
import 'confidence_indicator.dart';

class InsightCard extends StatefulWidget {
  const InsightCard({
    super.key,
    required this.insight,
    required this.onDismiss,
    required this.onAction,
  });

  final Insight insight;
  final VoidCallback onDismiss;
  final VoidCallback onAction;

  @override
  State<InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<InsightCard> {
  final InsightsAiService _ai = InsightsAiService();
  bool _expanded = false;
  bool _loadingExplain = false;
  String? _explanation;

  Future<void> _toggleExplain() async {
    if (_expanded) {
      setState(() => _expanded = false);
      return;
    }
    setState(() {
      _expanded = true;
      _explanation = widget.insight.aiExplanation;
    });
    if (_explanation != null && _explanation!.isNotEmpty) return;
    setState(() => _loadingExplain = true);
    try {
      final text = await _ai.enhanceInsight(widget.insight);
      if (!mounted) return;
      setState(() => _explanation = text);
    } catch (_) {
      if (!mounted) return;
      setState(() => _explanation =
          'Mood8 couldn’t reach the coach. Try again in a moment.');
    } finally {
      if (mounted) setState(() => _loadingExplain = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.insight;
    final tone = i.color;
    final isWarning = i.type == InsightType.warning;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tone.withValues(alpha: 0.16),
            tone.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: tone.withValues(alpha: 0.40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Badge(type: i.type),
              const Spacer(),
              IconButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  widget.onDismiss();
                },
                tooltip: 'Dismiss',
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(
                  minWidth: 28,
                  minHeight: 28,
                ),
                icon: Icon(Icons.close_rounded,
                    color: BrandColors.inkDim(context), size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            i.title,
            style: GoogleFonts.instrumentSerif(
              color: BrandColors.ink(context),
              fontStyle: FontStyle.italic,
              fontSize: 22,
              height: 1.15,
            ),
          ),
          if (i.description != null) ...[
            const SizedBox(height: 8),
            Text(
              i.description!,
              style: TextStyle(
                color: BrandColors.inkSoft(context),
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ConfidenceIndicator(confidence: i.confidence, compact: true),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Based on ${i.sampleSize} day${i.sampleSize == 1 ? '' : 's'}',
                style: TextStyle(
                  color: BrandColors.inkDim(context),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              if (i.actionable && i.actionText != null) ...[
                _GhostButton(
                  label: i.actionText!,
                  onTap: widget.onAction,
                  tone: tone,
                ),
                const SizedBox(width: 6),
              ],
              _GhostButton(
                label: _expanded ? 'Hide' : 'Tell me more',
                onTap: _toggleExplain,
                tone: tone,
                outlined: true,
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topLeft,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                      decoration: BoxDecoration(
                        color: BrandColors.bg(context).withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: tone.withValues(alpha: 0.22),
                        ),
                      ),
                      child: _loadingExplain
                          ? Row(
                              children: [
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation(tone),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Mood8 is thinking…',
                                  style: TextStyle(
                                    color: BrandColors.inkSoft(context),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            )
                          : Text(
                              _explanation ?? '',
                              style: TextStyle(
                                color: isWarning
                                    ? BrandColors.inkSoft(context)
                                    : BrandColors.ink(context),
                                fontSize: 13,
                                height: 1.45,
                              ),
                            ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.type});
  final InsightType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: type.color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: type.color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(type.emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 6),
          Text(
            type.badge.toUpperCase(),
            style: TextStyle(
              color: type.color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
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
    this.outlined = false,
  });

  final String label;
  final VoidCallback onTap;
  final Color tone;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: outlined ? null : tone.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: tone.withValues(alpha: 0.45)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: tone,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}
