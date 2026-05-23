import 'package:flutter/material.dart';

import '../services/haptic_service.dart';
import '../theme/app_theme.dart';
import 'insights_screen.dart';
import 'progress_screen.dart';

/// Host for the "Progress | Insights" segmented experience that
/// replaces the Insights bottom-nav tab. Both inner screens keep
/// their state via an IndexedStack so scroll position survives the
/// toggle.
class ProgressInsightsTab extends StatefulWidget {
  const ProgressInsightsTab({super.key});

  @override
  State<ProgressInsightsTab> createState() => ProgressInsightsTabState();
}

class ProgressInsightsTabState extends State<ProgressInsightsTab> {
  int _index = 0;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
              child: _SegmentedToggle(
                selected: _index,
                onChanged: _select,
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const [
                ProgressScreen(),
                InsightsScreen(),
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
      height: 38,
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
              fontSize: 13,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
