import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/challenge.dart';
import '../../services/auth_service.dart';
import '../../services/challenge_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/challenges/rank_insignia.dart';
import '../../widgets/challenges/user_badge_chip.dart';
import '../../widgets/responsive_container.dart';
import '../profile/public_profile_screen.dart';
import 'badge_legend_screen.dart';
import 'join_requests_screen.dart';

class ChallengeDetailScreen extends StatefulWidget {
  const ChallengeDetailScreen({super.key, required this.challengeId});

  final int challengeId;

  @override
  State<ChallengeDetailScreen> createState() => _ChallengeDetailScreenState();
}

class _ChallengeDetailScreenState extends State<ChallengeDetailScreen> {
  ChallengeDetail? _detail;
  String? _error;
  bool _loading = true;
  bool _joining = false;
  bool _checkingIn = false;
  // The "Request to join" button stays disabled after a successful
  // request so the user knows it landed even before the next refresh.
  bool _hasJustRequested = false;
  bool _upvoting = false;

  // Comments
  List<ChallengeComment> _comments = const [];
  bool _loadingComments = false;
  String? _commentsError;
  bool _postingComment = false;
  String? _commentRejection;
  final TextEditingController _commentController = TextEditingController();

  Timer? _deadlineTicker;
  Duration _untilDeadline = Duration.zero;

  @override
  void initState() {
    super.initState();
    _load();
    _loadComments();
    _deadlineTicker =
        Timer.periodic(const Duration(seconds: 30), (_) => _refreshTick());
  }

  @override
  void dispose() {
    _deadlineTicker?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  void _refreshTick() {
    if (!mounted) return;
    setState(() {
      final d = _detail;
      if (d != null) _untilDeadline = _computeUntilDeadline(d);
    });
  }

  Duration _computeUntilDeadline(ChallengeDetail d) {
    final local = utcMinutesToLocal(d.dailyDeadlineMinutesUtc);
    final now = DateTime.now();
    var dl = DateTime(now.year, now.month, now.day, local.hour, local.minute);
    if (dl.isBefore(now)) {
      dl = dl.add(const Duration(days: 1));
    }
    return dl.difference(now);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await ChallengeService().detail(widget.challengeId);
      if (!mounted) return;
      setState(() {
        _detail = d;
        _loading = false;
        _untilDeadline = _computeUntilDeadline(d);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ChallengeError ? e.message : 'Could not load.';
      });
    }
  }

  Future<void> _loadComments() async {
    if (_loadingComments) return;
    setState(() {
      _loadingComments = true;
      _commentsError = null;
    });
    try {
      final rows =
          await ChallengeService().listComments(widget.challengeId);
      if (!mounted) return;
      setState(() {
        _comments = rows;
        _loadingComments = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingComments = false;
        _commentsError =
            e is ChallengeError ? e.message : 'Could not load comments.';
      });
    }
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (_postingComment) return;
    if (text.isEmpty) return;
    setState(() {
      _postingComment = true;
      _commentRejection = null;
    });
    HapticService().selection();
    try {
      final result = await ChallengeService().postComment(
        challengeId: widget.challengeId,
        text: text,
      );
      if (!mounted) return;
      if (result.isRejected) {
        setState(() {
          _postingComment = false;
          _commentRejection = result.rejectionReason;
        });
        return;
      }
      _commentController.clear();
      setState(() {
        _postingComment = false;
        _comments = [..._comments, result.comment!];
        _detail = _detail?._withCounts(
          commentCount: (_detail?.commentCount ?? 0) + 1,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _postingComment = false;
        _commentRejection =
            e is ChallengeError ? e.message : 'Could not post.';
      });
    }
  }

  Future<void> _deleteComment(ChallengeComment c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrandColors.bgCard(context),
        title: Text('Delete this comment?',
            style: TextStyle(color: BrandColors.ink(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete',
                style: TextStyle(color: AppColors.pinkLight)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ChallengeService().deleteComment(
        challengeId: widget.challengeId,
        commentId: c.id,
      );
      if (!mounted) return;
      setState(() {
        _comments = _comments.where((x) => x.id != c.id).toList();
        _detail = _detail?._withCounts(
          commentCount: (_detail!.commentCount - 1).clamp(0, 1 << 30),
        );
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          e is ChallengeError ? e.message : 'Could not delete.',
        )),
      );
    }
  }

  Future<void> _reportComment(ChallengeComment c) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrandColors.bgCard(context),
        title: Text('Report comment',
            style: TextStyle(color: BrandColors.ink(context))),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          style: TextStyle(color: BrandColors.ink(context)),
          decoration: const InputDecoration(
            hintText: 'Why are you reporting this?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim()),
            child: Text('Submit',
                style: TextStyle(color: AppColors.pinkLight)),
          ),
        ],
      ),
    );
    if (reason == null || reason.length < 3) return;
    try {
      await ChallengeService().reportComment(
        commentId: c.id,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — the team will review.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          e is ChallengeError ? e.message : 'Could not report.',
        )),
      );
    }
  }

  Future<void> _toggleUpvote() async {
    final d = _detail;
    if (d == null || _upvoting) return;
    setState(() => _upvoting = true);
    final wasUp = d.userUpvoted;
    final optimisticCount =
        (d.upvoteCount + (wasUp ? -1 : 1)).clamp(0, 1 << 30);
    setState(() => _detail = d._withCounts(
          userUpvoted: !wasUp,
          upvoteCount: optimisticCount,
        ));
    HapticService().selection();
    try {
      final res = await ChallengeService().toggleUpvote(d.id);
      if (!mounted) return;
      setState(() {
        _upvoting = false;
        _detail = _detail!._withCounts(
          userUpvoted: res.upvoted,
          upvoteCount: res.count,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _upvoting = false;
        _detail = d;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          e is ChallengeError ? e.message : "Couldn't update upvote.",
        )),
      );
    }
  }

  void _openUserProfile({required int userId, required String name}) {
    HapticService().light();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            PublicProfileScreen(userId: userId, initialName: name),
      ),
    );
  }

  Future<void> _requestJoin() async {
    if (_joining) return;
    setState(() => _joining = true);
    try {
      await ChallengeService().requestJoin(widget.challengeId);
      if (!mounted) return;
      setState(() {
        _hasJustRequested = true;
        _joining = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request sent to the creator.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _joining = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          e is ChallengeError ? e.message : 'Could not send request.',
        )),
      );
    }
  }

  Future<void> _checkin() async {
    if (_checkingIn) return;
    setState(() => _checkingIn = true);
    HapticService().medium();
    try {
      final result = await ChallengeService().checkin(widget.challengeId);
      if (!mounted) return;
      setState(() => _checkingIn = false);
      // Update the local detail with the new rank/state without a
      // full round-trip.
      final d = _detail;
      if (d?.me != null) {
        final newMe = ChallengeMe(
          participantId: d!.me!.participantId,
          status: d.me!.status,
          rankIndex: result.rankIndex,
          rankName: result.rankName,
          missedRankups: result.missedRankups,
          checkedInToday: true,
          checkedInOnTime: result.wasOnTime,
        );
        setState(() => _detail = _detailWithMe(d, newMe));
      }
      if (result.idempotent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Already logged for today.')),
        );
      } else if (result.wasOnTime) {
        HapticService().medium();
        await showDialog<void>(
          context: context,
          barrierColor: Colors.black.withValues(alpha: 0.78),
          builder: (_) => _RankUpDialog(
            rankIndex: result.rankIndex,
            rankName: result.rankName,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
            'Logged — but past today’s deadline, so no rank-up.',
          )),
        );
      }
      // The cron may have advanced a prestige tier in the meantime;
      // refresh /me so prestigeUnlockedNotifier can fire if so.
      // ignore: discarded_futures
      AuthService().refreshMe();
      _load();
    } catch (e) {
      if (!mounted) return;
      setState(() => _checkingIn = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          e is ChallengeError ? e.message : 'Check-in failed.',
        )),
      );
    }
  }

  ChallengeDetail _detailWithMe(ChallengeDetail d, ChallengeMe me) {
    return ChallengeDetail(
      id: d.id,
      title: d.title,
      description: d.description,
      category: d.category,
      durationDays: d.durationDays,
      dailyDeadlineMinutesUtc: d.dailyDeadlineMinutesUtc,
      startDate: d.startDate,
      endDate: d.endDate,
      daysRemaining: d.daysRemaining,
      maxParticipants: d.maxParticipants,
      status: d.status,
      aiReviewStatus: d.aiReviewStatus,
      aiReviewReason: d.aiReviewReason,
      createdAt: d.createdAt,
      creator: d.creator,
      participants: d.participants,
      summary: d.summary,
      me: me,
      isCreator: d.isCreator,
      upvoteCount: d.upvoteCount,
      userUpvoted: d.userUpvoted,
      commentCount: d.commentCount,
    );
  }

  Future<void> _report() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrandColors.bgCard(context),
        title: Text('Report challenge',
            style: TextStyle(color: BrandColors.ink(context))),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          style: TextStyle(color: BrandColors.ink(context)),
          decoration: const InputDecoration(
            hintText: 'Why are you reporting this?',
            hintMaxLines: 2,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(
              'Submit',
              style: TextStyle(color: AppColors.pinkLight),
            ),
          ),
        ],
      ),
    );
    if (reason == null || reason.length < 3) return;
    try {
      await ChallengeService().report(widget.challengeId, reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — the team will review.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          e is ChallengeError ? e.message : 'Could not submit.',
        )),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 720,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _detail == null) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation(Color(0xFFEC4899)),
          ),
        ),
      );
    }
    if (_error != null && _detail == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: BrandColors.inkSoft(context)),
          ),
        ),
      );
    }
    final d = _detail!;
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.pinkLight,
      backgroundColor: BrandColors.bgCard(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          _TopBar(
            onBack: () => Navigator.of(context).maybePop(),
            onReport: _report,
          ),
          const SizedBox(height: 6),
          _CreatorRow(d: d),
          const SizedBox(height: 18),
          Text(
            d.title,
            style: GoogleFonts.bricolageGrotesque(
              color: BrandColors.ink(context),
              fontSize: 30,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            d.description,
            style: TextStyle(
              color: BrandColors.inkSoft(context),
              fontSize: 14.5,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 14),
          _DetailUpvoteRow(
            detail: d,
            busy: _upvoting,
            onTap: _toggleUpvote,
          ),
          const SizedBox(height: 16),
          _StatsRow(d: d),
          const SizedBox(height: 18),
          _ActionPanel(
            detail: d,
            joining: _joining,
            requested: _hasJustRequested,
            untilDeadline: _untilDeadline,
            onRequestJoin: _requestJoin,
            checkingIn: _checkingIn,
            onCheckin: _checkin,
            onCreatorRequests: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => JoinRequestsScreen(
                    challengeId: d.id, title: d.title,
                  ),
                ),
              );
              _load();
            },
          ),
          const SizedBox(height: 24),
          _ParticipantHistory(detail: d),
          const SizedBox(height: 28),
          _CommentsSection(
            detail: d,
            comments: _comments,
            loading: _loadingComments,
            error: _commentsError,
            posting: _postingComment,
            rejectionReason: _commentRejection,
            controller: _commentController,
            onPost: _postComment,
            onDelete: _deleteComment,
            onReport: _reportComment,
            onTapUser: _openUserProfile,
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, required this.onReport});
  final VoidCallback onBack;
  final VoidCallback onReport;
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: BrandColors.inkSoft(context)),
          onPressed: onBack,
        ),
        const Spacer(),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert_rounded,
              color: BrandColors.inkSoft(context)),
          color: BrandColors.bgCard(context),
          onSelected: (v) {
            if (v == 'report') onReport();
            if (v == 'legend') {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BadgeLegendScreen(),
                ),
              );
            }
          },
          itemBuilder: (ctx) => [
            PopupMenuItem(
              value: 'legend',
              child: Row(
                children: [
                  Icon(Icons.shield_rounded,
                      color: AppColors.purpleLight, size: 18),
                  const SizedBox(width: 8),
                  Text('Badges & ranks',
                      style: TextStyle(color: BrandColors.ink(context))),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.flag_outlined,
                      color: AppColors.pinkLight, size: 18),
                  const SizedBox(width: 8),
                  Text('Report challenge',
                      style: TextStyle(color: BrandColors.ink(context))),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CreatorRow extends StatelessWidget {
  const _CreatorRow({required this.d});
  final ChallengeDetail d;
  @override
  Widget build(BuildContext context) {
    final creatorId = d.creator.id;
    void openCreatorProfile() {
      if (creatorId == null) return;
      HapticService().light();
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PublicProfileScreen(
            userId: creatorId,
            initialName: d.creator.name,
          ),
        ),
      );
    }
    return Row(
      children: [
        GestureDetector(
          onTap: openCreatorProfile,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.orbGradient,
            ),
            child: Text(
              d.creator.name.isEmpty ? '?' : d.creator.name[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: openCreatorProfile,
            behavior: HitTestBehavior.opaque,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d.creator.name,
                  style: TextStyle(
                    color: BrandColors.ink(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                UserBadgeChip(
                  badge: d.creator.profileBadge,
                  creatorScore: d.creator.creatorScore,
                  compact: true,
                ),
              ],
            ),
          ),
        ),
        if (d.status != 'active')
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: BrandColors.bgCard(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: BrandColors.inkDim(context),
              ),
            ),
            child: Text(
              d.status.toUpperCase(),
              style: TextStyle(
                color: BrandColors.inkSoft(context),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
          ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.d});
  final ChallengeDetail d;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatTile(
          value: '${d.daysRemaining}',
          label: 'days left',
        )),
        const SizedBox(width: 8),
        Expanded(child: _StatTile(
          value: '${d.summary.activeCount}/${d.summary.participantCount}',
          label: 'active',
        )),
        const SizedBox(width: 8),
        Expanded(child: _StatTile(
          value: '${d.summary.gaveUpPct.toStringAsFixed(0)}%',
          label: 'gave up',
        )),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.bricolageGrotesque(
              color: BrandColors.ink(context),
              fontSize: 26,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: BrandColors.inkDim(context),
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

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.detail,
    required this.joining,
    required this.requested,
    required this.untilDeadline,
    required this.onRequestJoin,
    required this.checkingIn,
    required this.onCheckin,
    required this.onCreatorRequests,
  });

  final ChallengeDetail detail;
  final bool joining;
  final bool requested;
  final Duration untilDeadline;
  final VoidCallback onRequestJoin;
  final bool checkingIn;
  final VoidCallback onCheckin;
  final VoidCallback onCreatorRequests;

  @override
  Widget build(BuildContext context) {
    final d = detail;
    final me = d.me;
    if (d.isCreator) {
      return _CreatorPanel(
        onRequests: onCreatorRequests,
        details: d,
      );
    }
    if (me == null) {
      // Not joined, not requested.
      if (d.status != 'active') {
        return _DisabledPanel(
          message: 'This challenge isn’t accepting new participants.',
        );
      }
      return _PrimaryButton(
        label: requested ? 'Request pending' : 'Request to join',
        onTap: requested || joining ? null : onRequestJoin,
      );
    }
    if (me.status == 'removed') {
      return _DisabledPanel(
        message:
            'You were removed from this challenge. Rejoining isn’t allowed.',
      );
    }
    if (me.status == 'completed') {
      return _DisabledPanel(
        message: 'You completed this challenge. Onward.',
      );
    }
    // Active participant — show check-in.
    return _CheckinPanel(
      detail: d,
      me: me,
      untilDeadline: untilDeadline,
      onCheckin: checkingIn ? null : onCheckin,
      busy: checkingIn,
    );
  }
}

class _CheckinPanel extends StatelessWidget {
  const _CheckinPanel({
    required this.detail,
    required this.me,
    required this.untilDeadline,
    required this.onCheckin,
    required this.busy,
  });
  final ChallengeDetail detail;
  final ChallengeMe me;
  final Duration untilDeadline;
  final VoidCallback? onCheckin;
  final bool busy;

  String _countdown(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h <= 0 && m <= 0) return 'deadline passed';
    if (h == 0) return '${m}m left today';
    return '${h}h ${m}m left today';
  }

  @override
  Widget build(BuildContext context) {
    final local = utcMinutesToLocal(detail.dailyDeadlineMinutesUtc);
    final tod = TimeOfDay(hour: local.hour, minute: local.minute);
    final deadlineLabel = tod.format(context);

    if (me.checkedInToday) {
      return _DisabledPanel(
        message: me.checkedInOnTime ?? false
            ? 'Logged today, on time. See you tomorrow before $deadlineLabel.'
            : 'Logged today, but past the $deadlineLabel deadline — no rank-up.',
        leading: const Icon(Icons.check_circle_rounded,
            color: Color(0xFFC084FC), size: 22),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.purple.withValues(alpha: 0.20),
                AppColors.pink.withValues(alpha: 0.18),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.purpleLight.withValues(alpha: 0.40),
            ),
          ),
          child: Row(
            children: [
              RankInsignia(
                rankIndex: me.rankIndex,
                rankName: me.rankName,
                size: 22,
              ),
              const Spacer(),
              Text(
                _countdown(untilDeadline),
                style: TextStyle(
                  color: AppColors.pinkLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _PrimaryButton(
          label: busy ? 'Logging…' : 'I did it today ✓',
          onTap: onCheckin,
        ),
        const SizedBox(height: 6),
        Text(
          'Daily deadline: $deadlineLabel your time.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: BrandColors.inkDim(context),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

class _CreatorPanel extends StatelessWidget {
  const _CreatorPanel({required this.onRequests, required this.details});
  final VoidCallback onRequests;
  final ChallengeDetail details;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onRequests,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: BoxDecoration(
            color: BrandColors.bgCard(context).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.purple.withValues(alpha: 0.40),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.inbox_rounded, color: AppColors.pinkLight),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Join requests',
                      style: GoogleFonts.bricolageGrotesque(
                        color: BrandColors.ink(context),
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      'Review who wants to join your challenge.',
                      style: TextStyle(
                        color: BrandColors.inkSoft(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: BrandColors.inkSoft(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisabledPanel extends StatelessWidget {
  const _DisabledPanel({required this.message, this.leading});
  final String message;
  final Widget? leading;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: BrandColors.inkDim(context).withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: BrandColors.inkSoft(context),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.6 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 54,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(27),
            boxShadow: [
              BoxShadow(
                color: AppColors.pink.withValues(alpha: 0.45),
                blurRadius: 22,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.p});
  final ChallengeParticipant p;

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    switch (p.status) {
      case 'removed':
        statusColor = AppColors.pinkLight;
        break;
      case 'completed':
        statusColor = AppColors.purpleLight;
        break;
      default:
        statusColor = AppColors.blueAccent;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticService().light();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PublicProfileScreen(
                userId: p.userId,
                initialName: p.name,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: _buildContent(context, statusColor),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Color statusColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.60),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.orbGradient,
            ),
            child: Text(
              p.name.isEmpty ? '?' : p.name[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  style: TextStyle(
                    color: BrandColors.ink(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                RankInsignia(
                  rankIndex: p.rankIndex,
                  rankName: p.rankName,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: statusColor.withValues(alpha: 0.45),
              ),
            ),
            child: Text(
              p.status.toUpperCase(),
              style: TextStyle(
                color: statusColor,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankUpDialog extends StatefulWidget {
  const _RankUpDialog({required this.rankIndex, required this.rankName});
  final int rankIndex;
  final String rankName;
  @override
  State<_RankUpDialog> createState() => _RankUpDialogState();
}

class _RankUpDialogState extends State<_RankUpDialog> {
  late final ConfettiController _confetti = ConfettiController(
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confetti.play();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  BrandColors.bgCard(context),
                  BrandColors.bg(context),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.pinkLight.withValues(alpha: 0.55),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.pink.withValues(alpha: 0.55),
                  blurRadius: 60,
                  spreadRadius: -10,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _GlowingInsignia(rankIndex: widget.rankIndex)
                    .animate()
                    .fadeIn(duration: 320.ms)
                    .scaleXY(
                      begin: 0.55, end: 1.0,
                      duration: 540.ms,
                      curve: Curves.easeOutBack,
                    ),
                const SizedBox(height: 18),
                Text(
                  'RANK UP',
                  style: TextStyle(
                    color: AppColors.pinkLight,
                    fontSize: 11,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w800,
                  ),
                ).animate(delay: 200.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 6),
                Text(
                  'You advanced to',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bricolageGrotesque(
                    color: BrandColors.inkSoft(context),
                    fontSize: 22,
                    height: 1.0,
                  ),
                ).animate(delay: 320.ms).fadeIn(duration: 400.ms),
                const SizedBox(height: 4),
                Text(
                  widget.rankName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bricolageGrotesque(
                    color: BrandColors.ink(context),
                    fontSize: 40,
                    height: 1.05,
                    foreground: Paint()
                      ..shader = AppColors.primaryGradient.createShader(
                        const Rect.fromLTWH(0, 0, 280, 60),
                      ),
                  ),
                )
                    .animate(delay: 440.ms)
                    .fadeIn(duration: 500.ms)
                    .slideY(
                      begin: 0.18,
                      end: 0,
                      curve: Curves.easeOutCubic,
                    ),
                const SizedBox(height: 22),
                GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: AppColors.buttonGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.pink.withValues(alpha: 0.45),
                          blurRadius: 18,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ).animate(delay: 700.ms).fadeIn(duration: 400.ms),
              ],
            ),
          ),
          // Confetti emitter positioned just above the dialog.
          Positioned(
            top: -8,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirection: math.pi / 2, // straight down
              blastDirectionality: BlastDirectionality.explosive,
              maxBlastForce: 16,
              minBlastForce: 5,
              emissionFrequency: 0.05,
              numberOfParticles: 26,
              gravity: 0.25,
              shouldLoop: false,
              colors: const [
                Color(0xFFA855F7),
                Color(0xFFC084FC),
                Color(0xFFEC4899),
                Color(0xFFF472B6),
                Color(0xFFFFE08A),
                Color(0xFFFFFFFF),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cinematic version of [RankInsigniaArt] for the rank-up dialog — the
/// medallion sits over a layered radial glow that pulses softly.
class _GlowingInsignia extends StatelessWidget {
  const _GlowingInsignia({required this.rankIndex});
  final int rankIndex;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.pinkLight.withValues(alpha: 0.45),
                  AppColors.purple.withValues(alpha: 0.25),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(
                begin: 0.94,
                end: 1.06,
                duration: 1600.ms,
                curve: Curves.easeInOut,
              ),
          RankInsigniaArt(rankIndex: rankIndex, size: 96),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Upvote pill in the detail header
// ──────────────────────────────────────────────────────────────────

class _DetailUpvoteRow extends StatelessWidget {
  const _DetailUpvoteRow({
    required this.detail,
    required this.busy,
    required this.onTap,
  });
  final ChallengeDetail detail;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final up = detail.userUpvoted;
    return Row(
      children: [
        GestureDetector(
          onTap: busy ? null : onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: up
                  ? LinearGradient(
                      colors: [
                        AppColors.purple.withValues(alpha: 0.35),
                        AppColors.pink.withValues(alpha: 0.30),
                      ],
                    )
                  : null,
              color: up
                  ? null
                  : BrandColors.bgCard(context).withValues(alpha: 0.70),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: up
                    ? AppColors.pinkLight.withValues(alpha: 0.55)
                    : AppColors.purple.withValues(alpha: 0.30),
              ),
              boxShadow: up
                  ? [
                      BoxShadow(
                        color: AppColors.pink.withValues(alpha: 0.40),
                        blurRadius: 18,
                        spreadRadius: -4,
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  up
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 16,
                  color: up ? Colors.white : BrandColors.inkSoft(context),
                ),
                const SizedBox(width: 8),
                Text(
                  '${detail.upvoteCount}',
                  style: TextStyle(
                    color: up ? Colors.white : BrandColors.inkSoft(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  up ? 'upvoted' : 'upvote',
                  style: TextStyle(
                    color: (up ? Colors.white : BrandColors.inkSoft(context))
                        .withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Participant history section — grouped by status
// ──────────────────────────────────────────────────────────────────

class _ParticipantHistory extends StatelessWidget {
  const _ParticipantHistory({required this.detail});
  final ChallengeDetail detail;

  @override
  Widget build(BuildContext context) {
    final parts = detail.participants;
    final active = parts.where((p) => p.status == 'active').toList();
    final completed =
        parts.where((p) => p.status == 'completed').toList();
    final removed = parts.where((p) => p.status == 'removed').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PARTICIPANT HISTORY · ${parts.length}',
          style: TextStyle(
            color: BrandColors.inkDim(context),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 10),
        if (parts.isEmpty)
          Text(
            'No participants yet.',
            style: TextStyle(
              color: BrandColors.inkSoft(context),
              fontSize: 13,
            ),
          )
        else ...[
          if (active.isNotEmpty)
            _StatusGroup(label: 'STILL IN', participants: active),
          if (completed.isNotEmpty)
            _StatusGroup(label: 'COMPLETED', participants: completed),
          if (removed.isNotEmpty)
            _StatusGroup(label: 'GAVE UP', participants: removed),
        ],
      ],
    );
  }
}

class _StatusGroup extends StatelessWidget {
  const _StatusGroup({required this.label, required this.participants});
  final String label;
  final List<ChallengeParticipant> participants;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: BrandColors.inkDim(context),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          for (final p in participants)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ParticipantTile(p: p),
            ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────
// Comments section
// ──────────────────────────────────────────────────────────────────

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({
    required this.detail,
    required this.comments,
    required this.loading,
    required this.error,
    required this.posting,
    required this.rejectionReason,
    required this.controller,
    required this.onPost,
    required this.onDelete,
    required this.onReport,
    required this.onTapUser,
  });

  final ChallengeDetail detail;
  final List<ChallengeComment> comments;
  final bool loading;
  final String? error;
  final bool posting;
  final String? rejectionReason;
  final TextEditingController controller;
  final VoidCallback onPost;
  final void Function(ChallengeComment) onDelete;
  final void Function(ChallengeComment) onReport;
  final void Function({required int userId, required String name}) onTapUser;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'COMMENTS · ${comments.length}',
          style: TextStyle(
            color: BrandColors.inkDim(context),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 10),
        if (loading && comments.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.0,
                  valueColor: AlwaysStoppedAnimation(Color(0xFFEC4899)),
                ),
              ),
            ),
          )
        else if (error != null && comments.isEmpty)
          Text(
            error!,
            style: TextStyle(color: BrandColors.inkSoft(context)),
          )
        else if (comments.isEmpty)
          Text(
            'No comments yet. Say something kind.',
            style: TextStyle(
              color: BrandColors.inkSoft(context),
              fontSize: 13,
              height: 1.4,
            ),
          )
        else
          for (final c in comments)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CommentTile(
                comment: c,
                canDelete:
                    c.userId == detail.creator.id || detail.isCreator
                        ? true
                        : (c.userId == _selfId()),
                onTap: () => onTapUser(userId: c.userId, name: c.userName),
                onDelete: () => onDelete(c),
                onReport: () => onReport(c),
              ),
            ),
        const SizedBox(height: 12),
        _CommentComposer(
          controller: controller,
          posting: posting,
          rejection: rejectionReason,
          onPost: onPost,
        ),
      ],
    );
  }

  int _selfId() {
    final id = int.tryParse(AuthService().currentUser?.id ?? '');
    return id ?? -1;
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.comment,
    required this.canDelete,
    required this.onTap,
    required this.onDelete,
    required this.onReport,
  });
  final ChallengeComment comment;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  String _relativeTime(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }

  @override
  Widget build(BuildContext context) {
    final avatar = absoluteAvatarUrl(comment.userAvatarUrl);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTap,
            child: SizedBox(
              width: 32,
              height: 32,
              child: ClipOval(
                child: avatar != null
                    ? Image.network(
                        avatar,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            _AvatarFallback(name: comment.userName),
                      )
                    : _AvatarFallback(name: comment.userName),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: onTap,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        comment.userName,
                        style: TextStyle(
                          color: BrandColors.ink(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (comment.userProfileBadge != null)
                      UserBadgeChip(
                        badge: comment.userProfileBadge,
                        compact: true,
                      ),
                    const Spacer(),
                    Text(
                      _relativeTime(comment.createdAt),
                      style: TextStyle(
                        color: BrandColors.inkDim(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: TextStyle(
                    color: BrandColors.inkSoft(context),
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded,
                color: BrandColors.inkDim(context), size: 18),
            color: BrandColors.bgCard(context),
            onSelected: (v) {
              if (v == 'delete') onDelete();
              if (v == 'report') onReport();
            },
            itemBuilder: (_) => [
              if (canDelete)
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline_rounded,
                          color: AppColors.pinkLight, size: 16),
                      const SizedBox(width: 8),
                      Text('Delete',
                          style: TextStyle(color: BrandColors.ink(context))),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined,
                        color: BrandColors.inkSoft(context), size: 16),
                    const SizedBox(width: 8),
                    Text('Report',
                        style: TextStyle(color: BrandColors.ink(context))),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.orbGradient,
      ),
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.posting,
    required this.rejection,
    required this.onPost,
  });
  final TextEditingController controller;
  final bool posting;
  final String? rejection;
  final VoidCallback onPost;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(12, 4, 6, 4),
          decoration: BoxDecoration(
            color: BrandColors.bgCard(context).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.purple.withValues(alpha: 0.30),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 500,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onPost(),
                  style: TextStyle(color: BrandColors.ink(context)),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'Say something supportive…',
                    hintStyle: TextStyle(
                      color: BrandColors.inkFaint(context)
                          .withValues(alpha: 0.7),
                    ),
                    border: InputBorder.none,
                    isCollapsed: true,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              GestureDetector(
                onTap: posting ? null : onPost,
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.buttonGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.pink.withValues(alpha: 0.40),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Icon(
                    posting
                        ? Icons.hourglass_top_rounded
                        : Icons.send_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (rejection != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: AppColors.pink.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.pinkLight.withValues(alpha: 0.45),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    color: AppColors.pinkLight, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rejection!,
                    style: TextStyle(
                      color: BrandColors.ink(context),
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

extension on ChallengeDetail {
  ChallengeDetail _withCounts({
    int? upvoteCount,
    bool? userUpvoted,
    int? commentCount,
  }) =>
      ChallengeDetail(
        id: id,
        title: title,
        description: description,
        category: category,
        durationDays: durationDays,
        dailyDeadlineMinutesUtc: dailyDeadlineMinutesUtc,
        startDate: startDate,
        endDate: endDate,
        daysRemaining: daysRemaining,
        maxParticipants: maxParticipants,
        status: status,
        aiReviewStatus: aiReviewStatus,
        aiReviewReason: aiReviewReason,
        createdAt: createdAt,
        creator: creator,
        participants: participants,
        summary: summary,
        me: me,
        isCreator: isCreator,
        upvoteCount: upvoteCount ?? this.upvoteCount,
        userUpvoted: userUpvoted ?? this.userUpvoted,
        commentCount: commentCount ?? this.commentCount,
      );
}
