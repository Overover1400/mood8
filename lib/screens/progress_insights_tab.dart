import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/analytics_service.dart';
import '../services/haptic_service.dart';
import '../theme/app_theme.dart';
import 'insights_screen.dart';
import 'progress_screen.dart';

/// Host for the unified "Progress | Insights" experience that replaces
/// the separate Insights bottom-nav tab. Owns the active sub-view AND
/// the time-range selector so both share a single top bar; the toggle
/// + range pill live here, the inner screens render content only.
class ProgressInsightsTab extends StatefulWidget {
  const ProgressInsightsTab({super.key});

  @override
  State<ProgressInsightsTab> createState() => ProgressInsightsTabState();
}

class ProgressInsightsTabState extends State<ProgressInsightsTab> {
  int _index = 0;
  int _range = 30;

  /// Switches to the Insights sub-view. Used by tutorial / deep links
  /// that previously targeted the standalone Insights tab.
  void showInsights() {
    if (mounted && _index != 1) setState(() => _index = 1);
  }

  void _select(int i) {
    if (_index == i) return;
    HapticService().selection();
    setState(() => _index = i);
  }

  void _setRange(int days) {
    if (_range == days) return;
    HapticFeedback.selectionClick();
    setState(() => _range = days);
    AnalyticsService().invalidate();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SegmentedToggle(
                          selected: _index,
                          onChanged: _select,
                        ),
                      ),
                    ],
                  ),
                  // Range selector only matters for Progress — Insights
                  // is timeline-agnostic — but keep it visible across
                  // both views so the bar height never shifts when the
                  // user toggles. On Insights it stays inert visually.
                  if (_index == 0) ...[
                    const SizedBox(height: 10),
                    _RangeSelector(value: _range, onChanged: _setRange),
                  ],
                ],
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                ProgressScreen(range: _range),
                const InsightsScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({required this.selected, required this.onChanged});
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          _Segment(
            label: 'Progress',
            selected: selected == 0,
            onTap: () => onChanged(0),
          ),
          _Segment(
            label: 'Insights',
            selected: selected == 1,
            onTap: () => onChanged(1),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? AppColors.buttonGradient : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.pink.withValues(alpha: 0.35),
                      blurRadius: 14,
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : BrandColors.inkSoft(context),
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static const _options = [7, 30, 90];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          for (final d in _options)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(d),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: d == value ? AppColors.buttonGradient : null,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: d == value
                        ? [
                            BoxShadow(
                              color: AppColors.pink.withValues(alpha: 0.30),
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    '$d days',
                    style: TextStyle(
                      color: d == value
                          ? Colors.white
                          : BrandColors.inkDim(context),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
