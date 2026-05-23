import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../../services/profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/challenges/user_badge_chip.dart';
import '../../widgets/responsive_container.dart';

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({super.key, required this.userId, this.initialName});

  final int userId;
  /// Optional name to show in the loading skeleton so the user
  /// doesn't see "Anonymous" flash before the fetch returns.
  final String? initialName;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  PublicProfile? _profile;
  String? _error;
  bool _loading = true;

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
      final p = await ProfileService().fetchPublic(widget.userId);
      if (!mounted) return;
      setState(() {
        _profile = p;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ProfileError ? e.message : 'Could not load profile.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 600,
          child: RefreshIndicator(
            onRefresh: _load,
            color: AppColors.pinkLight,
            backgroundColor: BrandColors.bgCard(context),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded,
                          color: BrandColors.inkSoft(context)),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
                if (_loading && _profile == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 64),
                    child: Center(
                      child: SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor:
                              AlwaysStoppedAnimation(Color(0xFFEC4899)),
                        ),
                      ),
                    ),
                  )
                else if (_error != null && _profile == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 48),
                    child: Center(
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: BrandColors.inkSoft(context)),
                      ),
                    ),
                  )
                else
                  _Body(profile: _profile!),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.profile});
  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final url = profile.avatarAbsoluteUrl();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.orbGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.pink.withValues(alpha: 0.40),
                  blurRadius: 32,
                  spreadRadius: -4,
                ),
              ],
            ),
            child: ClipOval(
              child: url != null
                  ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          _AvatarInitial(name: profile.name),
                    )
                  : _AvatarInitial(name: profile.name),
            ),
          ).animate().fadeIn(duration: 320.ms).scaleXY(
                begin: 0.85,
                end: 1.0,
                curve: Curves.easeOutCubic,
                duration: 360.ms,
              ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            profile.name,
            textAlign: TextAlign.center,
            style: brandFont(
              color: BrandColors.ink(context),
              fontSize: 30,
              weight: FontWeight.w800,
              height: 1.0,
              letterSpacing: -0.4,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (profile.profileBadge != null ||
            (profile.creatorScore) > 0)
          Center(
            child: UserBadgeChip(
              badge: profile.profileBadge,
              creatorScore:
                  profile.creatorScore == 0 ? null : profile.creatorScore,
            ),
          ),
        if (profile.bio != null && profile.bio!.trim().isNotEmpty) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: BoxDecoration(
              color: BrandColors.bgCard(context).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.purple.withValues(alpha: 0.30),
              ),
            ),
            child: Text(
              profile.bio!,
              style: TextStyle(
                color: BrandColors.ink(context),
                fontSize: 14.5,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
                child: _StatTile(
              value: '${profile.streak}',
              label: 'Streak',
              icon: '🔥',
            )),
            const SizedBox(width: 8),
            Expanded(
                child: _StatTile(
              value: '${profile.challengesCompleted}',
              label: 'Challenges',
              icon: '🏁',
            )),
            const SizedBox(width: 8),
            Expanded(
                child: _StatTile(
              value: '${profile.creatorScore}',
              label: 'Creator',
              icon: '✦',
            )),
          ],
        ),
        if (profile.wellbeing != null) ...[
          const SizedBox(height: 18),
          _WellbeingCard(snapshot: profile.wellbeing!),
        ],
        const SizedBox(height: 18),
        if (profile.joinedAt != null)
          Center(
            child: Text(
              'Joined ${DateFormat('MMMM yyyy').format(profile.joinedAt!.toLocal())}',
              style: TextStyle(
                color: BrandColors.inkDim(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.value,
    required this.label,
    required this.icon,
  });
  final String value;
  final String label;
  final String icon;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(icon, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: BrandColors.inkDim(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: brandFont(
              color: BrandColors.ink(context),
              fontSize: 26,
              weight: FontWeight.w800,
              height: 1.0,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _WellbeingCard extends StatelessWidget {
  const _WellbeingCard({required this.snapshot});
  final WellbeingSnapshot snapshot;

  String _mood(double avg) {
    if (avg >= 8) return 'Thriving';
    if (avg >= 6.5) return 'Steady';
    if (avg >= 5) return 'Holding';
    if (avg >= 3.5) return 'Heavy';
    return 'Low';
  }

  @override
  Widget build(BuildContext context) {
    final fraction = (snapshot.avgMood / 10).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.purple.withValues(alpha: 0.20),
            AppColors.pink.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.pinkLight.withValues(alpha: 0.32),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_rounded,
                  color: AppColors.pinkLight, size: 14),
              const SizedBox(width: 6),
              Text(
                'WELLBEING · LAST ${snapshot.windowDays} DAYS',
                style: TextStyle(
                  color: AppColors.pinkLight,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _mood(snapshot.avgMood),
                style: brandFont(
                  color: BrandColors.ink(context),
                  fontSize: 28,
                  weight: FontWeight.w800,
                  letterSpacing: -0.3,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  'avg ${snapshot.avgMood.toStringAsFixed(1)}/10',
                  style: TextStyle(
                    color: BrandColors.inkSoft(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 6,
              color: BrandColors.bgCard(context).withValues(alpha: 0.6),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: fraction,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: AppColors.buttonGradient,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Based on ${snapshot.checkinCount} check-ins.',
            style: TextStyle(
              color: BrandColors.inkDim(context),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  const _AvatarInitial({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    final letter = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Center(
      child: Text(
        letter,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 48,
        ),
      ),
    );
  }
}
