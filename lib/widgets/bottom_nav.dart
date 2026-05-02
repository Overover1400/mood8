import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class NavItem {
  const NavItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

const List<NavItem> kNavItems = [
  NavItem('Today', Icons.today_rounded),
  NavItem('Habits', Icons.check_circle_outline_rounded),
  NavItem('Routine', Icons.schedule_rounded),
  NavItem('Insights', Icons.auto_awesome_rounded),
  NavItem('Progress', Icons.trending_up_rounded),
];

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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.bgCard.withValues(alpha: 0.95),
              AppColors.bg.withValues(alpha: 0.95),
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
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
              color: selected ? Colors.white : AppColors.inkDim,
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.inkDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
