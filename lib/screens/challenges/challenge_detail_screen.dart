import 'dart:async';
import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/challenge.dart';
import '../../services/auth_service.dart';
import '../../services/challenge_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/challenge_score_chip.dart';
import '../../widgets/challenges/invite_friends_sheet.dart';
import '../../widgets/challenges/network_avatar.dart';
import '../../widgets/challenges/rank_insignia.dart';
import '../../widgets/challenges/user_badge_chip.dart';
import '../../widgets/responsive_container.dart';
import '../profile/public_profile_screen.dart';
import 'badge_legend_screen.dart';
import 'challenge_participants_screen.dart';
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
  /// Comments are lazy-mounted — the body starts with a "View
  /// comments (N)" strip and only reveals the composer + full thread
  /// after the user taps it or posts. Flipped true once and stays
  /// there for the rest of the screen session.
  bool _commentsExpanded = false;

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

  /// Push the participants list screen. `initialTab`: 0=Active,
  /// 1=Gave up, 2=Completed. Reloads on return so a status change
  /// (e.g. the viewer's own removal after a missed deadline) reflects
  /// on the detail page.
  Future<void> _openParticipants(
    ChallengeDetail d, {
    int initialTab = 0,
  }) async {
    HapticService().light();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChallengeParticipantsScreen(
          challengeTitle: d.title,
          participants: d.participants,
          initialTabIndex: initialTab,
        ),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _deleteChallenge() async {
    final d = _detail;
    if (d == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrandColors.bgCard(context),
        title: Text(
          'Delete "${d.title}"?',
          style: TextStyle(color: BrandColors.ink(context)),
        ),
        content: Text(
          "This removes the challenge for everyone. Participants, "
          "checkins, join requests, and comments are all wiped. "
          "This can't be undone.",
          style: TextStyle(
            color: BrandColors.inkSoft(context),
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Color(0xFFFF6B81),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    HapticService().heavy();
    try {
      await ChallengeService().delete(widget.challengeId);
      if (!mounted) return;
      Navigator.of(context).pop(true); // return to list, which reloads
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ChallengeError ? e.message : 'Could not delete challenge.',
          ),
        ),
      );
    }
  }

  Future<void> _leave() async {
    final d = _detail;
    if (d == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrandColors.bgCard(context),
        title: Text(
          'Leave "${d.title}"?',
          style: TextStyle(color: BrandColors.ink(context)),
        ),
        content: Text(
          "You'll give up your spot and your rank in this challenge. "
          "You can request to join again later. If everyone leaves, "
          "the challenge closes automatically.",
          style: TextStyle(color: BrandColors.inkSoft(context), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Leave',
              style: TextStyle(
                color: Color(0xFFFF6B81),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    HapticService().medium();
    try {
      final closed = await ChallengeService().leave(widget.challengeId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(closed
              ? 'You left — the challenge closed (everyone gave up).'
              : 'You left the challenge.'),
        ),
      );
      Navigator.of(context).pop(true); // back to list, which reloads
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          e is ChallengeError ? e.message : 'Could not leave challenge.',
        )),
      );
    }
  }

  Future<void> _shareInviteLink() async {
    final d = _detail;
    if (d == null) return;
    HapticService().light();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Creating invite link…'), duration: Duration(milliseconds: 800)),
    );
    try {
      final url = await ChallengeService().inviteLink(d.id);
      if (!mounted || url.isEmpty) return;
      await Share.share(
        'Join me in “${d.title}” on Mood8 — no account needed:\n$url',
        subject: 'Join my Mood8 challenge',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          e is ChallengeError ? e.message : 'Could not create invite link.',
        )),
      );
    }
  }

  Future<void> _openInvite() async {
    final d = _detail;
    if (d == null) return;
    HapticService().light();
    final invited = await showInviteFriendsSheet(context, challengeId: d.id);
    if (invited != null && invited > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          invited == 1 ? '1 invite sent.' : '$invited invites sent.',
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
        // Small, tasteful score-awarded note after the rank-up
        // celebration. Only shown when the check-in actually earned
        // Ranking points (0 for creator-of-challenge halves, <3-
        // participant challenges, or when the 10/day cap is hit).
        if (result.scoreAwarded > 0 && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '+${result.scoreAwarded} Challenge Score',
              ),
              backgroundColor: AppColors.purple.withValues(alpha: 0.85),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
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
      imageUrl: d.imageUrl,
    );
  }

  /// Creator-only: pick a new cover photo and upload it, or remove
  /// the current one (choice sheet when a cover already exists).
  Future<void> _changeCover() async {
    final d = _detail;
    if (d == null) return;
    var action = 'change';
    if (d.imageUrl != null) {
      final picked = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: BrandColors.bgCard(context),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.add_photo_alternate_rounded,
                    color: AppColors.pinkLight),
                title: Text('Change cover photo',
                    style: TextStyle(color: BrandColors.ink(ctx))),
                onTap: () => Navigator.of(ctx).pop('change'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFFF6B81)),
                title: const Text('Remove cover photo',
                    style: TextStyle(color: Color(0xFFFF6B81))),
                onTap: () => Navigator.of(ctx).pop('remove'),
              ),
            ],
          ),
        ),
      );
      if (picked == null) return;
      action = picked;
    }
    try {
      if (action == 'remove') {
        await ChallengeService().removeCoverImage(d.id);
      } else {
        final file = await ImagePicker().pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          imageQuality: 85,
        );
        if (file == null) return;
        final bytes = await file.readAsBytes();
        await ChallengeService().uploadCoverImage(
          challengeId: d.id,
          bytes: bytes,
          filename: file.name,
        );
      }
      if (!mounted) return;
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          e is ChallengeError ? e.message : 'Could not update the cover.',
        )),
      );
    }
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
          // TOP: back arrow + ⋮ menu (Badges + Report + owner Delete
          // + Join requests when isCreator). All secondary actions
          // live here so the body reads calmly top-to-bottom.
          _TopBar(
            isCreator: d.isCreator,
            onBack: () => Navigator.of(context).maybePop(),
            onReport: _report,
            // Invite is available to anyone in the challenge (creator or
            // active participant). Leave is for active participants who
            // aren't the creator — the creator ends a challenge via
            // Delete, not Leave.
            onInvite: (d.isCreator || d.me?.status == 'active')
                ? _openInvite
                : null,
            onShareLink: d.isCreator ? _shareInviteLink : null,
            onCoverPhoto: d.isCreator ? _changeCover : null,
            onLeave: (!d.isCreator && d.me?.status == 'active')
                ? _leave
                : null,
            onDelete: d.isCreator ? _deleteChallenge : null,
            onJoinRequests: d.isCreator
                ? () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => JoinRequestsScreen(
                          challengeId: d.id, title: d.title,
                        ),
                      ),
                    );
                    _load();
                  }
                : null,
          ),
          const SizedBox(height: 4),
          // 0. Cover photo banner (when the creator uploaded one).
          //    Creators tap it to change/remove the cover.
          if (d.imageUrl != null) ...[
            GestureDetector(
              onTap: d.isCreator ? _changeCover : null,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  absoluteAvatarUrl(d.imageUrl)!,
                  width: double.infinity,
                  height: 170,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          // 1. Title (gradient shader for a premium, editorial feel)
          //    + compact creator row + glowing meta chips replacing
          //    the old dot-separated text line.
          _GradientTitle(text: d.title),
          const SizedBox(height: 12),
          _CreatorRow(d: d),
          const SizedBox(height: 12),
          _MetaChips(d: d),
          const SizedBox(height: 18),
          _DescriptionBlock(text: d.description),
          const SizedBox(height: 22),
          // 2. HERO — check-in control. For active participants
          //    (creator included) this is the single most prominent
          //    element on the page.
          _ActionPanel(
            detail: d,
            joining: _joining,
            requested: _hasJustRequested,
            untilDeadline: _untilDeadline,
            onRequestJoin: _requestJoin,
            checkingIn: _checkingIn,
            onCheckin: _checkin,
            // Creator-panel callbacks are unused post-refactor
            // (moved to the ⋮ menu). Kept for backward compat with
            // the widget's existing constructor.
            onCreatorRequests: () {},
            onCreatorDelete: () {},
          ),
          const SizedBox(height: 14),
          // 3. "Did it today" — compact avatar row.
          _TodayCheckinsRow(
            detail: d,
            onTap: () => _openParticipants(d, initialTab: 0),
          ),
          const SizedBox(height: 18),
          // 4. Compact stats row — one thin line, no card tiles.
          _CompactStatsLine(d: d),
          const SizedBox(height: 12),
          // 5. Participants — single row, opens the full list.
          _ParticipantsTapStrip(
            detail: d,
            onTap: () => _openParticipants(d, initialTab: 0),
          ),
          const SizedBox(height: 12),
          // 6. Slim upvote + comment-count action row.
          _EngagementRow(
            detail: d,
            upvoting: _upvoting,
            onUpvote: _toggleUpvote,
            onScrollToComments: () => setState(() => _commentsExpanded = true),
          ),
          const SizedBox(height: 18),
          // 7. Comments — lazy-collapsed behind "View comments (N)"
          //    until tapped. Once open, stays open for the rest of
          //    the screen session so a scroll-back doesn't collapse
          //    the user's own comment out of view.
          _LazyComments(
            expanded: _commentsExpanded,
            onExpand: () => setState(() => _commentsExpanded = true),
            child: _CommentsSection(
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
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.isCreator,
    required this.onBack,
    required this.onReport,
    this.onInvite,
    this.onShareLink,
    this.onCoverPhoto,
    this.onLeave,
    this.onDelete,
    this.onJoinRequests,
  });

  final bool isCreator;
  final VoidCallback onBack;
  final VoidCallback onReport;
  /// Shown to anyone in the challenge. When null the "Invite friends"
  /// item is omitted.
  final VoidCallback? onInvite;
  /// Creator-only public shareable link. When null the item is omitted.
  final VoidCallback? onShareLink;
  /// Creator-only cover photo add/change/remove. When null the item
  /// is omitted.
  final VoidCallback? onCoverPhoto;
  /// Shown to active non-creator participants. When null the "Leave
  /// challenge" item is omitted.
  final VoidCallback? onLeave;
  /// Only wired for creators. When null the "Delete challenge" item
  /// is omitted from the overflow menu.
  final VoidCallback? onDelete;
  /// Only wired for creators. When null the "Join requests" item is
  /// omitted from the overflow menu.
  final VoidCallback? onJoinRequests;

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
            switch (v) {
              case 'legend':
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BadgeLegendScreen(),
                  ),
                );
                break;
              case 'report':
                onReport();
                break;
              case 'invite':
                onInvite?.call();
                break;
              case 'share_link':
                onShareLink?.call();
                break;
              case 'cover_photo':
                onCoverPhoto?.call();
                break;
              case 'leave':
                onLeave?.call();
                break;
              case 'join_requests':
                onJoinRequests?.call();
                break;
              case 'delete':
                onDelete?.call();
                break;
            }
          },
          itemBuilder: (ctx) => [
            if (onInvite != null)
              PopupMenuItem(
                value: 'invite',
                child: Row(
                  children: [
                    Icon(Icons.person_add_alt_1_rounded,
                        color: AppColors.pinkLight, size: 18),
                    const SizedBox(width: 8),
                    Text('Invite friends',
                        style: TextStyle(color: BrandColors.ink(context))),
                  ],
                ),
              ),
            if (onShareLink != null)
              PopupMenuItem(
                value: 'share_link',
                child: Row(
                  children: [
                    Icon(Icons.link_rounded,
                        color: AppColors.pinkLight, size: 18),
                    const SizedBox(width: 8),
                    Text('Share invite link',
                        style: TextStyle(color: BrandColors.ink(context))),
                  ],
                ),
              ),
            if (isCreator && onCoverPhoto != null)
              PopupMenuItem(
                value: 'cover_photo',
                child: Row(
                  children: [
                    Icon(Icons.add_photo_alternate_rounded,
                        color: AppColors.pinkLight, size: 18),
                    const SizedBox(width: 8),
                    Text('Cover photo',
                        style: TextStyle(color: BrandColors.ink(context))),
                  ],
                ),
              ),
            if (isCreator && onJoinRequests != null)
              PopupMenuItem(
                value: 'join_requests',
                child: Row(
                  children: [
                    Icon(Icons.inbox_rounded,
                        color: AppColors.pinkLight, size: 18),
                    const SizedBox(width: 8),
                    Text('Join requests',
                        style: TextStyle(color: BrandColors.ink(context))),
                  ],
                ),
              ),
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
            if (onLeave != null) ...[
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'leave',
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded,
                        color: Color(0xFFFF6B81), size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Leave challenge',
                      style: TextStyle(
                        color: Color(0xFFFF6B81),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (isCreator && onDelete != null) ...[
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline_rounded,
                        color: Color(0xFFFF6B81), size: 18),
                    const SizedBox(width: 8),
                    const Text(
                      'Delete challenge',
                      style: TextStyle(
                        color: Color(0xFFFF6B81),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
          child: NetworkAvatar(
            name: d.creator.name,
            avatarUrl: absoluteAvatarUrl(d.creator.avatarUrl),
            size: 38,
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
                Row(
                  children: [
                    if (d.creator.challengeScore > 0) ...[
                      ChallengeScoreChip(
                        score: d.creator.challengeScore,
                        tier: d.creator.challengeTier,
                      ),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        d.creator.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: BrandColors.ink(context),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
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

/// Editorial gradient-shader title. Uses the brand purple→pink→pink-
/// light gradient masked over Bricolage Grotesque so the challenge
/// name reads as the visual anchor of the page without needing a
/// bg-card container. Falls back to solid ink if the shader can't
/// resolve (never observed in practice; belt-and-suspenders).
class _GradientTitle extends StatelessWidget {
  const _GradientTitle({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          AppColors.pinkLight,
          AppColors.pink,
          AppColors.purpleLight,
        ],
      ).createShader(bounds),
      child: Text(
        text,
        style: GoogleFonts.bricolageGrotesque(
          color: Colors.white,
          fontSize: 30,
          height: 1.1,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// Fancy glowing pill chips for the challenge meta. The category chip
/// carries a soft brand-gradient background + glow so it visually
/// tags the challenge domain; duration + days-left use a calmer
/// bordered-glass style with a subtle accent-tinted glow so the row
/// stays hierarchical (category > duration > days-left). Wraps at
/// narrow widths so 320dp stays safe.
class _MetaChips extends StatelessWidget {
  const _MetaChips({required this.d});
  final ChallengeDetail d;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _CategoryPill(label: prettyCategory(d.category)),
        _MetaPill(
          icon: Icons.schedule_rounded,
          label: '${d.durationDays}d',
          accent: AppColors.blueAccent,
        ),
        _MetaPill(
          icon: d.status == 'active'
              ? Icons.timelapse_rounded
              : Icons.check_circle_rounded,
          label: d.status == 'active'
              ? '${d.daysRemaining} days left'
              : d.status.toLowerCase(),
          accent: d.status == 'active'
              ? AppColors.pinkLight
              : AppColors.purpleLight,
        ),
      ],
    );
  }
}

class _CategoryPill extends StatelessWidget {
  const _CategoryPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.purple.withValues(alpha: 0.35),
            AppColors.pink.withValues(alpha: 0.30),
            AppColors.pinkLight.withValues(alpha: 0.25),
          ],
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppColors.pinkLight.withValues(alpha: 0.55),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.pink.withValues(alpha: 0.28),
            blurRadius: 14,
            spreadRadius: -4,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: BrandColors.ink(context),
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.accent,
  });
  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accent.withValues(alpha: 0.42),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.18),
            blurRadius: 10,
            spreadRadius: -3,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 12),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: BrandColors.inkSoft(context),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft-container description block. Adds a whisper of brand gradient
/// on the left edge + comfortable reading padding so the description
/// stops looking like a plain text dump under the meta line, without
/// stealing focus from the check-in hero below.
class _DescriptionBlock extends StatelessWidget {
  const _DescriptionBlock({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.purple.withValues(alpha: 0.08),
            AppColors.pink.withValues(alpha: 0.04),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border(
          left: BorderSide(
            color: AppColors.pinkLight.withValues(alpha: 0.55),
            width: 2.5,
          ),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: BrandColors.inkSoft(context),
          fontSize: 14.5,
          height: 1.55,
        ),
      ),
    );
  }
}

/// Slim inline "N active · M% gave up · N in" stats line — one row,
/// no card tiles. Replaces the old boxy _StatsRow so the middle of
/// the page reads calmer.
class _CompactStatsLine extends StatelessWidget {
  const _CompactStatsLine({required this.d});
  final ChallengeDetail d;

  @override
  Widget build(BuildContext context) {
    final summary = d.summary;
    return Row(
      children: [
        _StatChip(
          value: '${summary.activePct.toStringAsFixed(0)}%',
          label: 'active',
          color: AppColors.blueAccent,
        ),
        const SizedBox(width: 10),
        _StatChip(
          value: '${summary.gaveUpPct.toStringAsFixed(0)}%',
          label: 'gave up',
          color: AppColors.pinkLight,
        ),
        const SizedBox(width: 10),
        _StatChip(
          value: '${summary.participantCount}',
          label: summary.participantCount == 1 ? 'person' : 'people',
          color: AppColors.purpleLight,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.value,
    required this.label,
    required this.color,
  });
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: GoogleFonts.bricolageGrotesque(
            color: color,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: BrandColors.inkDim(context),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Slim engagement row — upvote toggle on the left, comment count on
/// the right. Tapping the comment count expands the lazy comments
/// section below. Deliberately minimal so it doesn't compete with
/// the check-in hero above.
class _EngagementRow extends StatelessWidget {
  const _EngagementRow({
    required this.detail,
    required this.upvoting,
    required this.onUpvote,
    required this.onScrollToComments,
  });
  final ChallengeDetail detail;
  final bool upvoting;
  final VoidCallback onUpvote;
  final VoidCallback onScrollToComments;

  @override
  Widget build(BuildContext context) {
    final up = detail.userUpvoted;
    return Row(
      children: [
        InkWell(
          onTap: upvoting ? null : onUpvote,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: up
                  ? AppColors.pink.withValues(alpha: 0.16)
                  : BrandColors.bgCard(context).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: up
                    ? AppColors.pinkLight.withValues(alpha: 0.60)
                    : AppColors.purple.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  up
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  color: up ? AppColors.pinkLight : BrandColors.inkSoft(context),
                  size: 15,
                ),
                const SizedBox(width: 6),
                Text(
                  '${detail.upvoteCount}',
                  style: TextStyle(
                    color: up
                        ? AppColors.pinkLight
                        : BrandColors.inkSoft(context),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: onScrollToComments,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: BrandColors.bgCard(context).withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.purple.withValues(alpha: 0.22),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.mode_comment_outlined,
                    color: BrandColors.inkSoft(context), size: 14),
                const SizedBox(width: 6),
                Text(
                  '${detail.commentCount}',
                  style: TextStyle(
                    color: BrandColors.inkSoft(context),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
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

/// Wraps [child] behind a "View comments (N)" tap strip. Renders the
/// strip when [expanded] is false and swaps in [child] once expanded.
/// [child] should be the full CommentsSection (composer + list).
class _LazyComments extends StatelessWidget {
  const _LazyComments({
    required this.expanded,
    required this.onExpand,
    required this.child,
  });
  final bool expanded;
  final VoidCallback onExpand;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (expanded) return child;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onExpand,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: BrandColors.bgCard(context).withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.purple.withValues(alpha: 0.20),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.mode_comment_outlined,
                  color: AppColors.pinkLight, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'View comments',
                  style: TextStyle(
                    color: BrandColors.inkSoft(context),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: BrandColors.inkSoft(context), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// Superseded by _CompactStatsLine (thin inline row). Kept for one
// release in case the compact version needs to A/B against the old
// tile grid.
// ignore: unused_element
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
    required this.onCreatorDelete,
  });

  final ChallengeDetail detail;
  final bool joining;
  final bool requested;
  final Duration untilDeadline;
  final VoidCallback onRequestJoin;
  final bool checkingIn;
  final VoidCallback onCheckin;
  final VoidCallback onCreatorRequests;
  final VoidCallback onCreatorDelete;

  @override
  Widget build(BuildContext context) {
    final d = detail;
    final me = d.me;
    // Non-participant paths first — no `me` means the viewer isn't in
    // the challenge, so nothing to check in and no management UI.
    if (me == null) {
      if (d.status != 'active') {
        return _DisabledPanel(
          message: "This challenge isn't accepting new participants.",
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
            "You were removed from this challenge. Rejoining isn't allowed.",
      );
    }
    if (me.status == 'completed') {
      return _DisabledPanel(
        message: 'You completed this challenge. Onward.',
      );
    }
    // Active participant — show the check-in panel. This intentionally
    // covers the creator too: they auto-join as participant 0 on
    // challenge creation (see backend main.py::create_challenge), so
    // `me.status == 'active'` is true for them and they get to tick
    // the same daily check-in as everyone else. The creator-only
    // management row (Join requests + Delete challenge) is rendered
    // separately from the parent build so the check-in always sits at
    // the top.
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

// Superseded by _CreatorManagementStrip below. Kept for reference
// while the new UX beds in — delete after ~2 releases if nobody
// misses the tall "Join requests" card.
// ignore: unused_element
class _CreatorPanel extends StatelessWidget {
  const _CreatorPanel({
    required this.onRequests,
    required this.onDelete,
    required this.details,
  });
  final VoidCallback onRequests;
  final VoidCallback onDelete;
  final ChallengeDetail details;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
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
        ),
        const SizedBox(height: 10),
        // Owner delete — softened destructive style (subtle outline
        // + destructive text colour) so it doesn't dominate the
        // creator panel but is unambiguously available.
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onDelete,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              decoration: BoxDecoration(
                color: BrandColors.bgCard(context).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFFF6B81).withValues(alpha: 0.55),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFFF6B81),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Delete this challenge',
                      style: TextStyle(
                        color: BrandColors.ink(context),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: BrandColors.inkSoft(context)),
                ],
              ),
            ),
          ),
        ),
      ],
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

// Superseded by _ParticipantRow inside challenge_participants_screen.
// Kept here in case a future compact inline preview wants the same
// shape without pulling the full screen file in.
// ignore: unused_element
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
          NetworkAvatar(
            name: p.name,
            avatarUrl: absoluteAvatarUrl(p.avatarUrl),
            size: 34,
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
                GradientText(
                  widget.rankName,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bricolageGrotesque(
                    fontSize: 40,
                    height: 1.05,
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

// Superseded by _EngagementRow (upvote + comment count together).
// Kept for reference — the standalone upvote row was factored out
// so we could pair upvote + comment count into one slim strip.
// ignore: unused_element
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
// Today's check-ins avatar row + participants tap strip
// ──────────────────────────────────────────────────────────────────

/// Compact "N of M did it today" strip showing overlapping avatars of
/// the participants who've already checked in today. Tap → opens the
/// full participants view (Active tab). Renders nothing before start
/// or after end so it doesn't lie about "who's checked in" when no
/// day is in play.
class _TodayCheckinsRow extends StatelessWidget {
  const _TodayCheckinsRow({required this.detail, required this.onTap});
  final ChallengeDetail detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (detail.status != 'active') return const SizedBox.shrink();
    final active = detail.participants
        .where((p) => p.status == 'active')
        .toList();
    if (active.isEmpty) return const SizedBox.shrink();
    final done = active.where((p) => p.checkedInToday).toList();
    final total = active.length;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: BrandColors.bgCard(context).withValues(alpha: 0.60),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.purple.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              _AvatarStack(
                participants: done.isEmpty
                    // Show muted avatars of active people when nobody's
                    // checked in yet — otherwise the row is empty and
                    // useless.
                    ? active.take(6).toList()
                    : done.take(6).toList(),
                muted: done.isEmpty,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      done.isEmpty
                          ? 'Nobody has checked in today yet'
                          : done.length == total
                              ? 'Everyone did it today · $total of $total'
                              : '${done.length} of $total did it today',
                      style: TextStyle(
                        color: BrandColors.ink(context),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to see everyone',
                      style: TextStyle(
                        color: BrandColors.inkDim(context),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: BrandColors.inkSoft(context),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Overlapping avatar stack, up to N shown, each nudged left. `muted`
/// reduces opacity for the "nobody checked in yet" placeholder.
class _AvatarStack extends StatelessWidget {
  const _AvatarStack({required this.participants, this.muted = false});
  final List<ChallengeParticipant> participants;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    const size = 30.0;
    const overlap = 10.0;
    final width = size + (participants.length - 1) * (size - overlap);
    return Opacity(
      opacity: muted ? 0.55 : 1.0,
      child: SizedBox(
        width: width.clamp(size, size * 6),
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var i = 0; i < participants.length; i++)
              Positioned(
                left: i * (size - overlap),
                child: Container(
                  padding: const EdgeInsets.all(1.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: BrandColors.bgDeep(context),
                  ),
                  child: NetworkAvatar(
                    name: participants[i].name,
                    avatarUrl: absoluteAvatarUrl(
                      participants[i].avatarUrl,
                    ),
                    size: size,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Active 12 · Gave up 3 · Completed 5 ›" tap target that opens the
/// full participants view. Replaces the previous inline
/// _ParticipantHistory so the detail scroll stays short.
class _ParticipantsTapStrip extends StatelessWidget {
  const _ParticipantsTapStrip({
    required this.detail,
    required this.onTap,
  });
  final ChallengeDetail detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parts = detail.participants;
    final active = parts.where((p) => p.status == 'active').length;
    final removed = parts.where((p) => p.status == 'removed').length;
    final completed = parts.where((p) => p.status == 'completed').length;
    if (parts.isEmpty) return const SizedBox.shrink();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: BrandColors.bgCard(context).withValues(alpha: 0.60),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.purple.withValues(alpha: 0.22),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.groups_rounded,
                  color: AppColors.pinkLight, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _StatusCount(
                      label: 'Active',
                      count: active,
                      color: AppColors.blueAccent,
                    ),
                    _StatusCount(
                      label: 'Gave up',
                      count: removed,
                      color: AppColors.pinkLight,
                    ),
                    if (completed > 0)
                      _StatusCount(
                        label: 'Completed',
                        count: completed,
                        color: AppColors.purpleLight,
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: BrandColors.inkSoft(context),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCount extends StatelessWidget {
  const _StatusCount({
    required this.label,
    required this.count,
    required this.color,
  });
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: BrandColors.inkSoft(context),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Compact creator-only management row. Renders below the check-in
/// panel + participants strip when `d.isCreator` — auto-joined
/// creators still get to check in, this is the secondary "manage the
/// challenge you run" surface.
// Superseded — creator management (Join requests + Delete) moved
// into the ⋮ overflow menu in _TopBar so the detail body reads
// calmly without creator-only chrome mid-scroll.
// ignore: unused_element
class _CreatorManagementStrip extends StatelessWidget {
  const _CreatorManagementStrip({
    required this.onRequests,
    required this.onDelete,
  });
  final VoidCallback onRequests;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ManageTile(
            icon: Icons.inbox_rounded,
            label: 'Join requests',
            onTap: onRequests,
            accent: AppColors.pinkLight,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ManageTile(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            onTap: onDelete,
            accent: const Color(0xFFFF6B81),
            danger: true,
          ),
        ),
      ],
    );
  }
}

class _ManageTile extends StatelessWidget {
  const _ManageTile({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.accent,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color accent;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: (danger ? accent : AppColors.purple)
                .withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: accent.withValues(alpha: danger ? 0.45 : 0.30),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: accent, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: danger ? accent : BrandColors.ink(context),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
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
    // Compare in UTC to avoid the "just posted → 4h ago" bug that
    // came from the server emitting naive UTC strings without a
    // zone marker. `_parseServerUtc` in models/challenge.dart now
    // stamps every server datetime as UTC; toUtc() here is
    // defence-in-depth so a local-flagged DateTime from any other
    // path still lands right.
    final nowUtc = DateTime.now().toUtc();
    final atUtc = at.isUtc ? at : at.toUtc();
    final diff = nowUtc.difference(atUtc);
    // Clock-skew guard: a server timestamp a few seconds in the
    // "future" (round-trip latency) shouldn't render "-1m ago".
    if (diff.isNegative || diff.inSeconds < 60) return 'just now';
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
                    if (comment.userChallengeScore > 0) ...[
                      ChallengeScoreChip(
                        score: comment.userChallengeScore,
                        tier: comment.userChallengeTier,
                        dense: true,
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: GestureDetector(
                        onTap: onTap,
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          comment.userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: BrandColors.ink(context),
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
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
        imageUrl: imageUrl,
      );
}
