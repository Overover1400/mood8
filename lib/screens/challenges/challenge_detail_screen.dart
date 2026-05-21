import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/challenge.dart';
import '../../services/challenge_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/challenges/rank_insignia.dart';
import '../../widgets/challenges/user_badge_chip.dart';
import '../../widgets/responsive_container.dart';
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

  Timer? _deadlineTicker;
  Duration _untilDeadline = Duration.zero;

  @override
  void initState() {
    super.initState();
    _load();
    _deadlineTicker =
        Timer.periodic(const Duration(seconds: 30), (_) => _refreshTick());
  }

  @override
  void dispose() {
    _deadlineTicker?.cancel();
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
        await showDialog<void>(
          context: context,
          builder: (_) => _RankUpDialog(rankName: result.rankName),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(
            'Logged — but past today’s deadline, so no rank-up.',
          )),
        );
      }
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
            style: GoogleFonts.instrumentSerif(
              color: BrandColors.ink(context),
              fontStyle: FontStyle.italic,
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
          Text(
            'PARTICIPANTS · ${d.participants.length}',
            style: TextStyle(
              color: BrandColors.inkDim(context),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          for (final p in d.participants)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ParticipantTile(p: p),
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
          },
          itemBuilder: (ctx) => [
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
    return Row(
      children: [
        Container(
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
        const SizedBox(width: 12),
        Expanded(
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
            style: GoogleFonts.instrumentSerif(
              color: BrandColors.ink(context),
              fontStyle: FontStyle.italic,
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
                      style: GoogleFonts.instrumentSerif(
                        color: BrandColors.ink(context),
                        fontStyle: FontStyle.italic,
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

class _RankUpDialog extends StatelessWidget {
  const _RankUpDialog({required this.rankName});
  final String rankName;
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              BrandColors.bgCard(context),
              BrandColors.bg(context),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.pinkLight.withValues(alpha: 0.55),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.orbGradient,
              ),
              child: const Icon(Icons.military_tech_rounded,
                  color: Colors.white, size: 36),
            )
                .animate()
                .scaleXY(begin: 0.6, end: 1.0, duration: 360.ms)
                .fadeIn(),
            const SizedBox(height: 16),
            Text(
              'Rank up.',
              textAlign: TextAlign.center,
              style: GoogleFonts.instrumentSerif(
                color: BrandColors.inkSoft(context),
                fontStyle: FontStyle.italic,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'You advanced to $rankName.',
              textAlign: TextAlign.center,
              style: GoogleFonts.instrumentSerif(
                color: BrandColors.ink(context),
                fontStyle: FontStyle.italic,
                fontSize: 32,
                foreground: Paint()
                  ..shader = AppColors.primaryGradient
                      .createShader(const Rect.fromLTWH(0, 0, 240, 50)),
              ),
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: () => Navigator.of(context).maybePop(),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
