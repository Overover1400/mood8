import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/challenge.dart';
import '../../services/challenge_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/challenges/user_badge_chip.dart';
import '../../widgets/responsive_container.dart';

class JoinRequestsScreen extends StatefulWidget {
  const JoinRequestsScreen({
    super.key,
    required this.challengeId,
    required this.title,
  });

  final int challengeId;
  final String title;

  @override
  State<JoinRequestsScreen> createState() => _JoinRequestsScreenState();
}

class _JoinRequestsScreenState extends State<JoinRequestsScreen> {
  List<JoinRequest>? _requests;
  bool _loading = true;
  String? _error;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows =
          await ChallengeService().joinRequests(widget.challengeId);
      if (!mounted) return;
      setState(() {
        _requests = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            e is ChallengeError ? e.message : 'Could not load requests.';
      });
    }
  }

  Future<void> _resolve(JoinRequest r, bool approve) async {
    if (_busy.contains(r.id)) return;
    setState(() => _busy.add(r.id));
    HapticService().selection();
    try {
      await ChallengeService().resolveJoinRequest(
        challengeId: widget.challengeId,
        requestId: r.id,
        approve: approve,
      );
      if (!mounted) return;
      setState(() => _requests = (_requests ?? [])
          .where((x) => x.id != r.id)
          .toList());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          approve ? 'Approved ${r.userName}.' : 'Declined.',
        )),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          e is ChallengeError ? e.message : 'Could not resolve request.',
        )),
      );
    } finally {
      if (mounted) setState(() => _busy.remove(r.id));
    }
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Join requests',
                            style: GoogleFonts.bricolageGrotesque(
                              color: BrandColors.ink(context),
                              fontSize: 24,
                              height: 1.0,
                            ),
                          ),
                          Text(
                            widget.title,
                            style: TextStyle(
                              color: BrandColors.inkDim(context),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation(Color(0xFFEC4899)),
          ),
        ),
      );
    }
    if (_error != null) {
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
    final rows = _requests ?? const <JoinRequest>[];
    if (rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'No pending requests.',
            style: TextStyle(
              color: BrandColors.inkSoft(context),
              fontSize: 14,
            ),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final r = rows[i];
        final busy = _busy.contains(r.id);
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: BrandColors.bgCard(context).withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.purple.withValues(alpha: 0.30),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
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
                      r.userName.isEmpty
                          ? '?'
                          : r.userName[0].toUpperCase(),
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
                          r.userName,
                          style: TextStyle(
                            color: BrandColors.ink(context),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        UserBadgeChip(
                          badge: r.profileBadge,
                          creatorScore: r.creatorScore,
                          compact: true,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    DateFormat('MMM d').format(r.createdAt),
                    style: TextStyle(
                      color: BrandColors.inkDim(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SecondaryBtn(
                      label: 'Decline',
                      onTap: busy ? null : () => _resolve(r, false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PrimaryBtn(
                      label: busy ? '…' : 'Approve',
                      onTap: busy ? null : () => _resolve(r, true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PrimaryBtn extends StatelessWidget {
  const _PrimaryBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.6 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryBtn extends StatelessWidget {
  const _SecondaryBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.6 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: BrandColors.bgCard(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: AppColors.purple.withValues(alpha: 0.30),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: BrandColors.ink(context),
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
