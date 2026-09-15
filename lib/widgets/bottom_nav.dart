import 'package:flutter/material.dart';

import '../feature_flags.dart';
import '../services/feature_unlock_service.dart';
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

/// Live GlobalKeys for each visible bottom-nav tab, one per [kNavItems]
/// (index == tab index). Overlays that need to spotlight a tab — the
/// welcome tutorial — read the button's real on-screen RenderBox through
/// these instead of recomputing nav geometry, so the highlight stays
/// glued to the tab at any width, font scale, or platform.
final List<GlobalKey> kNavTabKeys =
    List<GlobalKey>.generate(kNavItems.length, (i) => GlobalKey());

/// Spec 10.1 caps the bar at FOUR tabs. Rather than renumber the index
/// space — which every `goToTab` caller and every `k*TabIndex` constant
/// depends on — the bar simply renders four entries and routes the rest
/// through "More". Challenge, Coach and Routine keep their existing
/// indices and are reached from the More sheet.
class VisibleTab {
  const VisibleTab(this.label, this.icon, this.targetIndex);
  final String label;
  final IconData icon;
  /// Index into [kNavItems] / the IndexedStack. -1 means "open More".
  final int targetIndex;
}

const List<VisibleTab> kVisibleTabs = [
  VisibleTab('Today', Icons.today_rounded, kHomeTabIndex),
  VisibleTab('Habits', Icons.check_circle_outline_rounded, kHabitsTabIndex),
  VisibleTab('Progress', Icons.bar_chart_rounded, kProgressTabIndex),
  VisibleTab('More', Icons.grid_view_rounded, -1),
];

/// Everything that used to own a tab and now lives one tap deeper.
const List<VisibleTab> kMoreTabs = [
  VisibleTab('Challenges', Icons.flag_rounded, kChallengeTabIndex),
  VisibleTab('Coach', Icons.chat_bubble_outline_rounded, kCoachTabIndex),
  if (kRoutineEnabled)
    VisibleTab('Routine', Icons.schedule_rounded, kRoutineTabIndex),
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
    // Respect the bottom system-bar inset (gesture pill OR 3-button nav).
    // MainNavigation's Scaffold body is a Stack with no SafeArea, so
    // without this the pill sits UNDER the phone's navigation bar on
    // devices like the Samsung S24 and its tabs become unreachable.
    // viewPadding (not padding) is used so the inset is honoured even
    // when a keyboard or other SafeArea has already consumed it.
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomInset),
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
            for (final t in kVisibleTabs)
              Expanded(
                child: _NavButton(
                  key: t.targetIndex >= 0 &&
                          t.targetIndex < kNavTabKeys.length
                      ? kNavTabKeys[t.targetIndex]
                      : null,
                  item: NavItem(t.label, t.icon),
                  selected: t.targetIndex == -1
                      // "More" lights up while any of its screens is on.
                      ? kMoreTabs.any((m) => m.targetIndex == currentIndex)
                      : t.targetIndex == currentIndex,
                  // Spec 6 — a locked tab explains what opens it rather
                  // than navigating to an empty screen.
                  locked: _isLocked(t.targetIndex),
                  onTap: () {
                    if (t.targetIndex == -1) {
                      _showMoreSheet(context, onTap);
                      return;
                    }
                    if (_isLocked(t.targetIndex)) {
                      _explainLock(context, t.targetIndex);
                      return;
                    }
                    onTap(t.targetIndex);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Spec 6 — is this destination still closed for this user?
bool _isLocked(int targetIndex) {
  final svc = FeatureUnlockService();
  if (targetIndex == kProgressTabIndex) return !svc.progressUnlocked;
  if (targetIndex == kCoachTabIndex) return !svc.coachUnlocked;
  if (targetIndex == kChallengeTabIndex) return !svc.challengesUnlocked;
  return false;
}

String _lockReason(int targetIndex) {
  final svc = FeatureUnlockService();
  if (targetIndex == kProgressTabIndex) return svc.progressLockReason();
  if (targetIndex == kCoachTabIndex) return svc.coachLockReason();
  if (targetIndex == kChallengeTabIndex) return svc.challengesLockReason();
  return '';
}

/// Tell the user what opens it, and when. Never a bare "locked".
void _explainLock(BuildContext context, int targetIndex) {
  HapticService().selection();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(_lockReason(targetIndex)),
      backgroundColor: BrandColors.bgCard(context),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
  );
}

/// One tap deeper: the screens that no longer justify a permanent tab.
Future<void> _showMoreSheet(
    BuildContext context, ValueChanged<int> onTap) async {
  HapticService().selection();
  final picked = await showModalBottomSheet<int>(
    context: context,
    backgroundColor: BrandColors.bgCard(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: BrandColors.inkFaint(ctx),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 10),
          for (final t in kMoreTabs)
            Builder(builder: (rowCtx) {
              final locked = _isLocked(t.targetIndex);
              return ListTile(
                leading: Icon(
                  locked ? Icons.lock_outline_rounded : t.icon,
                  color: locked
                      ? BrandColors.inkDim(ctx)
                      : AppColors.pinkLight,
                ),
                title: Text(
                  t.label,
                  style: TextStyle(
                    color: locked
                        ? BrandColors.inkDim(ctx)
                        : BrandColors.ink(ctx),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                // Spec 6 — the locked row says what opens it, right there.
                subtitle: locked
                    ? Text(
                        _lockReason(t.targetIndex),
                        style: TextStyle(
                          color: BrandColors.inkDim(ctx),
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      )
                    : null,
                // The subtitle already says what opens it, so a locked
                // row simply doesn't respond rather than closing the
                // sheet and leaving the user with no explanation.
                onTap: locked
                    ? null
                    : () => Navigator.of(ctx).pop(t.targetIndex),
              );
            }),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (picked != null && picked >= 0) onTap(picked);
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
    this.locked = false,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  /// Spec 6 — dimmed with a small lock glyph. Still tappable: tapping is
  /// how the user learns what opens it.
  final bool locked;

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
              locked ? Icons.lock_outline_rounded : item.icon,
              size: 22,
              color: selected
                  ? Colors.white
                  : BrandColors.inkDim(context)
                      .withValues(alpha: locked ? 0.55 : 1.0),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: selected
                    ? Colors.white
                    : BrandColors.inkDim(context)
                        .withValues(alpha: locked ? 0.55 : 1.0),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
