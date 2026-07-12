import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/haptic_service.dart';
import '../services/notification_feed_service.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_container.dart';
import 'challenges/challenge_detail_screen.dart';

/// Two-tab layout — **Active** (unread) and **History** (read).
/// Marking a notification as read moves it out of Active into History
/// on the next stream frame (the underlying list stays sorted by
/// created_at desc; the partition is just a filter). Server-side
/// prune drops read entries older than 30 days so History doesn't
/// grow forever — see challenge_daily_job::_prune_read_notifications.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    NotificationFeedService().refresh();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _open(AppNotification n) async {
    HapticService().selection();
    if (!n.isRead) {
      // ignore: discarded_futures
      NotificationFeedService().markRead(n.id);
    }
    if (n.relatedId == null) return;
    // All current types relate to a challenge.
    final id = n.relatedId!;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChallengeDetailScreen(challengeId: id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 560,
          child: ValueListenableBuilder<List<AppNotification>>(
            valueListenable: NotificationFeedService().notifications,
            builder: (_, items, _) {
              final active = items.where((n) => !n.isRead).toList();
              final history = items.where((n) => n.isRead).toList();
              return Column(
                children: [
                  _HeaderRow(activeCount: active.length),
                  _TabBarStrip(
                    controller: _tabs,
                    activeCount: active.length,
                    historyCount: history.length,
                  ),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        _NotificationList(
                          items: active,
                          onOpen: _open,
                          emptyBuilder: (_) => _ActiveEmptyState(
                            onSeeHistory: history.isEmpty
                                ? null
                                : () => _tabs.animateTo(1),
                            historyCount: history.length,
                          ),
                          highlightUnread: true,
                        ),
                        _NotificationList(
                          items: history,
                          onOpen: _open,
                          emptyBuilder: (_) => _HistoryEmptyState(),
                          highlightUnread: false,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.activeCount});
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: BrandColors.inkSoft(context)),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              'Notifications',
              style: brandFont(
                color: BrandColors.ink(context),
                fontSize: 26,
                weight: FontWeight.w800,
                height: 1.0,
                letterSpacing: -0.3,
              ),
            ),
          ),
          if (activeCount > 0)
            TextButton(
              onPressed: () =>
                  NotificationFeedService().markAllRead(),
              child: Text(
                'Mark all read',
                style: TextStyle(
                  color: AppColors.pinkLight,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabBarStrip extends StatelessWidget {
  const _TabBarStrip({
    required this.controller,
    required this.activeCount,
    required this.historyCount,
  });
  final TabController controller;
  final int activeCount;
  final int historyCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
      child: Container(
        decoration: BoxDecoration(
          color: BrandColors.bgCard(context).withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.purple.withValues(alpha: 0.24),
          ),
        ),
        child: TabBar(
          controller: controller,
          indicator: BoxDecoration(
            gradient: AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorPadding: const EdgeInsets.all(4),
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: BrandColors.inkSoft(context),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
            letterSpacing: 0.2,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
          splashFactory: NoSplash.splashFactory,
          overlayColor: WidgetStatePropertyAll(Colors.transparent),
          tabs: [
            Tab(text: 'Active${activeCount == 0 ? '' : ' · $activeCount'}'),
            Tab(text: 'History${historyCount == 0 ? '' : ' · $historyCount'}'),
          ],
        ),
      ),
    );
  }
}

class _NotificationList extends StatelessWidget {
  const _NotificationList({
    required this.items,
    required this.onOpen,
    required this.emptyBuilder,
    required this.highlightUnread,
  });

  final List<AppNotification> items;
  final void Function(AppNotification) onOpen;
  final WidgetBuilder emptyBuilder;
  /// True for the Active list — renders unread items with the
  /// glowing purple border. False for History where every row is by
  /// definition read.
  final bool highlightUnread;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => NotificationFeedService().refresh(),
      color: AppColors.pinkLight,
      backgroundColor: BrandColors.bgCard(context),
      child: items.isEmpty
          ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: emptyBuilder(context),
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final n = items[i];
                return _NotificationTile(
                  notification: n,
                  onTap: () => onOpen(n),
                  highlightUnread: highlightUnread,
                )
                    .animate(delay: (30 * i).ms)
                    .fadeIn(duration: 280.ms)
                    .slideY(
                        begin: 0.04, end: 0, curve: Curves.easeOut);
              },
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.onTap,
    required this.highlightUnread,
  });
  final AppNotification notification;
  final VoidCallback onTap;
  final bool highlightUnread;

  ({IconData icon, Color tone}) _iconFor(String type, BuildContext context) {
    switch (type) {
      case 'join_request':
        return (icon: Icons.person_add_rounded, tone: AppColors.purpleLight);
      case 'join_approved':
        return (icon: Icons.check_circle_rounded, tone: AppColors.pinkLight);
      case 'rank_up':
        return (icon: Icons.military_tech_rounded, tone: AppColors.pinkLight);
      case 'challenge_ended':
        return (icon: Icons.flag_rounded, tone: AppColors.blueAccent);
      case 'challenge_comment':
        return (icon: Icons.chat_bubble_outline_rounded,
            tone: AppColors.purpleLight);
      case 'challenge_upvote':
        return (icon: Icons.favorite_rounded, tone: AppColors.pink);
      default:
        return (icon: Icons.notifications_rounded,
            tone: BrandColors.inkSoft(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ic = _iconFor(notification.type, context);
    final unread = highlightUnread && !notification.isRead;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: unread
                ? AppColors.purple.withValues(alpha: 0.16)
                : BrandColors.bgCard(context).withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: unread
                  ? AppColors.pinkLight.withValues(alpha: 0.55)
                  : AppColors.purple.withValues(alpha: 0.22),
            ),
            boxShadow: unread
                ? [
                    BoxShadow(
                      color: AppColors.pink.withValues(alpha: 0.20),
                      blurRadius: 18,
                      spreadRadius: -8,
                    ),
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ic.tone.withValues(alpha: 0.18),
                  border: Border.all(
                    color: ic.tone.withValues(alpha: 0.45),
                  ),
                ),
                child: Icon(ic.icon, color: ic.tone, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              color: BrandColors.ink(context),
                              fontSize: 14,
                              fontWeight:
                                  unread ? FontWeight.w800 : FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(left: 8),
                            decoration: BoxDecoration(
                              color: AppColors.pinkLight,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      AppColors.pink.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      notification.body,
                      style: TextStyle(
                        color: BrandColors.inkSoft(context),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _relativeTime(notification.createdAt),
                      style: TextStyle(
                        color: BrandColors.inkDim(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _relativeTime(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

/// "You're all caught up ✨" — shown on the Active tab when nothing
/// is unread. If History has entries the empty state includes a
/// subtle nudge toward it so the user knows old items didn't vanish.
class _ActiveEmptyState extends StatelessWidget {
  const _ActiveEmptyState({
    required this.historyCount,
    required this.onSeeHistory,
  });
  final int historyCount;
  final VoidCallback? onSeeHistory;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 32),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: BrandColors.bgCard(context).withValues(alpha: 0.7),
              border: Border.all(
                color: AppColors.pinkLight.withValues(alpha: 0.35),
              ),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.pinkLight,
              size: 32,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            "You're all caught up ✨",
            style: brandFont(
              color: BrandColors.ink(context),
              fontSize: 24,
              weight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'When things happen in your challenges, they’ll land here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: BrandColors.inkSoft(context),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          if (onSeeHistory != null) ...[
            const SizedBox(height: 18),
            TextButton.icon(
              onPressed: onSeeHistory,
              icon: Icon(
                Icons.history_rounded,
                color: AppColors.purpleLight,
                size: 16,
              ),
              label: Text(
                'See history ($historyCount)',
                style: TextStyle(
                  color: AppColors.purpleLight,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Empty state for the History tab. Kept plainer than the Active
/// one — it's a diagnostic surface, not the primary read.
class _HistoryEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 32),
      child: Column(
        children: [
          Icon(
            Icons.history_rounded,
            color: BrandColors.inkDim(context),
            size: 40,
          ),
          const SizedBox(height: 14),
          Text(
            'No history yet.',
            style: TextStyle(
              color: BrandColors.inkSoft(context),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Notifications you’ve read show up here for 30 days.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: BrandColors.inkDim(context),
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
