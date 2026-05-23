import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../services/haptic_service.dart';
import '../services/notification_feed_service.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_container.dart';
import 'challenges/challenge_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    NotificationFeedService().refresh();
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
          child: Column(
            children: [
              Padding(
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
                    ValueListenableBuilder<int>(
                      valueListenable: NotificationFeedService().unreadCount,
                      builder: (_, unread, _) {
                        if (unread == 0) return const SizedBox.shrink();
                        return TextButton(
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
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => NotificationFeedService().refresh(),
                  color: AppColors.pinkLight,
                  backgroundColor: BrandColors.bgCard(context),
                  child: ValueListenableBuilder<List<AppNotification>>(
                    valueListenable: NotificationFeedService().notifications,
                    builder: (_, items, _) {
                      if (items.isEmpty) {
                        return _EmptyState();
                      }
                      return ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                        itemCount: items.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final n = items[i];
                          return _NotificationTile(
                            notification: n,
                            onTap: () => _open(n),
                          )
                              .animate(delay: (30 * i).ms)
                              .fadeIn(duration: 280.ms)
                              .slideY(
                                  begin: 0.04,
                                  end: 0,
                                  curve: Curves.easeOut);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});
  final AppNotification notification;
  final VoidCallback onTap;

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
    final unread = !notification.isRead;
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

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: BrandColors.bgCard(context).withValues(alpha: 0.7),
              border: Border.all(
                color: AppColors.purple.withValues(alpha: 0.30),
              ),
            ),
            child: Icon(Icons.notifications_none_rounded,
                color: BrandColors.inkSoft(context), size: 32),
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            'All caught up.',
            style: brandFont(
              color: BrandColors.ink(context),
              fontSize: 24,
              weight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'When things happen in your challenges, they’ll land here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: BrandColors.inkSoft(context),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
