import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/challenge.dart';
import '../../services/challenge_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/challenges/challenge_card.dart';
import '../../widgets/responsive_container.dart';
import 'badge_legend_screen.dart';
import 'challenge_detail_screen.dart';
import 'create_challenge_screen.dart';
import 'my_challenges_screen.dart';

class ChallengesListScreen extends StatefulWidget {
  const ChallengesListScreen({super.key, this.embedded = false});

  /// When `true` the screen renders as a top-level tab (no back button,
  /// extra bottom padding so the floating nav doesn't cover content).
  /// The push-routed variant (e.g. from Settings → Browse) leaves
  /// `embedded` at its default false so the back arrow is shown.
  final bool embedded;

  @override
  State<ChallengesListScreen> createState() => _ChallengesListScreenState();
}

class _ChallengesListScreenState extends State<ChallengesListScreen> {
  String? _category; // null = All
  List<ChallengeSummary>? _challenges;
  String? _error;
  bool _loading = false;

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
      final rows = await ChallengeService().list(category: _category);
      if (!mounted) return;
      setState(() {
        _challenges = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ChallengeError ? e.message : 'Could not load challenges.';
      });
    }
  }

  void _selectCategory(String? c) {
    HapticService().selection();
    setState(() => _category = c);
    _load();
  }

  Future<void> _openCreate() async {
    HapticService().light();
    final id = await Navigator.of(context).push<int?>(
      MaterialPageRoute(builder: (_) => const CreateChallengeScreen()),
    );
    if (id != null && mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChallengeDetailScreen(challengeId: id),
        ),
      );
      _load();
    } else {
      _load();
    }
  }

  /// Optimistic per-row upvote toggle. Flips local state immediately,
  /// fires the server toggle, reconciles with the canonical count or
  /// rolls back on error.
  Future<void> _toggleUpvote(int index, ChallengeSummary c) async {
    final before = _challenges ?? const <ChallengeSummary>[];
    if (index < 0 || index >= before.length) return;
    final wasUp = c.userUpvoted;
    final optimistic = c.copyWith(
      userUpvoted: !wasUp,
      upvoteCount: (c.upvoteCount + (wasUp ? -1 : 1)).clamp(0, 1 << 30),
    );
    setState(() => _challenges = [
          for (var i = 0; i < before.length; i++)
            if (i == index) optimistic else before[i],
        ]);
    try {
      final res = await ChallengeService().toggleUpvote(c.id);
      if (!mounted) return;
      // Reconcile with the server's canonical count.
      setState(() => _challenges = [
            for (var i = 0; i < (_challenges ?? const []).length; i++)
              if (i == index)
                (_challenges![i]).copyWith(
                  userUpvoted: res.upvoted,
                  upvoteCount: res.count,
                )
              else
                (_challenges![i]),
          ]);
    } catch (e) {
      if (!mounted) return;
      setState(() => _challenges = before);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          e is ChallengeError ? e.message : "Couldn't update upvote.",
        )),
      );
    }
  }

  Future<void> _openMine() async {
    HapticService().light();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MyChallengesScreen()),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 720,
          child: Column(
            children: [
              _Header(
                onMine: _openMine,
                onCreate: _openCreate,
                embedded: widget.embedded,
              ),
              _CategoryRow(
                current: _category,
                onSelect: _selectCategory,
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading && _challenges == null) {
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
    if (_error != null && _challenges == null) {
      return _ErrorState(message: _error!, onRetry: _load);
    }
    final list = _challenges ?? const <ChallengeSummary>[];
    if (list.isEmpty) {
      return _EmptyState(onCreate: _openCreate);
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.pinkLight,
      backgroundColor: BrandColors.bgCard(context),
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(20, 12, 20, widget.embedded ? 120 : 32),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (_, i) {
          final c = list[i];
          return ChallengeCard(
            challenge: c,
            onTap: () async {
              HapticService().light();
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChallengeDetailScreen(challengeId: c.id),
                ),
              );
              _load();
            },
            onToggleUpvote: () => _toggleUpvote(i, c),
          )
              .animate()
              .fadeIn(duration: 320.ms, delay: (40 * i).ms)
              .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onMine,
    required this.onCreate,
    required this.embedded,
  });
  final VoidCallback onMine;
  final VoidCallback onCreate;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(embedded ? 20 : 20, 12, 12, 8),
      child: Row(
        children: [
          if (!embedded)
            IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: BrandColors.inkSoft(context),
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: embedded ? 0 : 0),
              child: Text(
                'Challenges',
                style: brandFont(
                  color: BrandColors.ink(context),
                  fontSize: 30,
                  weight: FontWeight.w800,
                  height: 1.0,
                  letterSpacing: -0.4,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Badges & ranks',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const BadgeLegendScreen(),
              ),
            ),
            icon: Icon(Icons.info_outline_rounded,
                color: BrandColors.inkSoft(context)),
          ),
          IconButton(
            tooltip: 'My challenges',
            onPressed: onMine,
            icon: Icon(Icons.bookmark_rounded,
                color: BrandColors.inkSoft(context)),
          ),
          IconButton(
            tooltip: 'Create',
            onPressed: onCreate,
            icon: Icon(Icons.add_circle_outline_rounded,
                color: AppColors.pinkLight),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.current, required this.onSelect});
  final String? current;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _CategoryChip(
            label: 'All',
            selected: current == null,
            onTap: () => onSelect(null),
          ),
          const SizedBox(width: 8),
          for (final cat in kChallengeCategories) ...[
            _CategoryChip(
              label: prettyCategory(cat),
              selected: current == cat,
              onTap: () => onSelect(cat),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.buttonGradient : null,
          color: selected ? null : BrandColors.bgCard(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : AppColors.purple.withValues(alpha: 0.30),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : BrandColors.inkSoft(context),
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.orbGradient,
              ),
              child: const Icon(Icons.flag_rounded,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(height: 18),
            Text(
              'No challenges yet.',
              style: GoogleFonts.bricolageGrotesque(
                color: BrandColors.ink(context),
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start one — or hold tight while we wait for someone to.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: BrandColors.inkSoft(context),
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            GestureDetector(
              onTap: onCreate,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 22, vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(26),
                ),
                child: const Text(
                  'Create challenge',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.3,
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

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_rounded,
                color: AppColors.pinkLight, size: 32),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: BrandColors.inkSoft(context),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: TextStyle(
                  color: AppColors.pinkLight,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
