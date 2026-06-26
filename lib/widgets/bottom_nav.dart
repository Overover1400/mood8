import 'package:flutter/material.dart';

import '../feature_flags.dart';
import '../services/haptic_service.dart';
import '../theme/app_theme.dart';

class NavItem {
  const NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// All possible nav items, in canonical order. The actual nav
/// (and the IndexedStack children in MainNavigation) filters this
/// list by [_navItemEnabled] — flipping a feature flag changes both
/// the visible tabs and the index constants below without further
/// surgery.
const List<NavItem> _kAllNavItems = [
  NavItem('Today', Icons.today_rounded),
  NavItem('Habits', Icons.check_circle_outline_rounded),
  NavItem('Routine', Icons.schedule_rounded),
  NavItem('Challenge', Icons.flag_rounded),
  NavItem('Coach', Icons.chat_bubble_outline_rounded),
  NavItem('Progress', Icons.bar_chart_rounded),
];

/// Mirror of [_kAllNavItems] but only the items currently shown,
/// computed at compile time so const lists / index constants below
/// stay const. When [kRoutineEnabled] is false the Routine tab is
/// skipped entirely.
const List<NavItem> kNavItems = kRoutineEnabled
    ? _kAllNavItems
    : [
        NavItem('Today', Icons.today_rounded),
        NavItem('Habits', Icons.check_circle_outline_rounded),
        NavItem('Challenge', Icons.flag_rounded),
        NavItem('Coach', Icons.chat_bubble_outline_rounded),
        NavItem('Progress', Icons.bar_chart_rounded),
      ];

// Tab-index constants. They shift when Routine is hidden, so every
// goToTab caller continues to land on the right screen without
// per-call branching.
const int kHomeTabIndex = 0;
const int kHabitsTabIndex = 1;
const int kRoutineTabIndex = kRoutineEnabled ? 2 : -1;
const int kChallengeTabIndex = kRoutineEnabled ? 3 : 2;
const int kCoachTabIndex = kRoutineEnabled ? 4 : 3;
const int kProgressTabIndex = kRoutineEnabled ? 5 : 4;
// Insights is no longer a tab — it lives inside the Progress screen
// as a segmented toggle. Legacy alias kept so older call sites still
// route correctly.
const int kInsightsTabIndex = kProgressTabIndex;

class MoodBottomNav extends StatelessWidget {
  const MoodBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        height: 66,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              BrandColors.bgCard(context).withValues(alpha: 0.95),
              BrandColors.bg(context).withValues(alpha: 0.95),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: AppColors.purple.withValues(alpha: 0.20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 30,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: AppColors.purple.withValues(alpha: 0.18),
              blurRadius: 40,
              spreadRadius: -6,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < kNavItems.length; i++)
              Expanded(
                child: _NavButton(
                  item: kNavItems[i],
                  selected: i == currentIndex,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticService().selection();
        // Nav tab changes are silent — the haptic alone is the
        // confirmation. The chime got tiring on rapid switching.
        onTap();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [
                    AppColors.purple.withValues(alpha: 0.50),
                    AppColors.pink.withValues(alpha: 0.45),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.pink.withValues(alpha: 0.40),
                    blurRadius: 16,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              size: 22,
              color: selected ? Colors.white : BrandColors.inkDim(context),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : BrandColors.inkDim(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
