import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/challenge.dart';
import '../../services/challenge_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/challenges/challenge_card.dart';
import '../../widgets/responsive_container.dart';
import 'badge_legend_screen.dart';
import 'ranking_screen.dart';
import 'challenge_detail_screen.dart';
import 'create_challenge_screen.dart';
import 'friends_screen.dart';
import 'my_challenges_screen.dart';

/// Vertical space the floating bottom nav occupies when this screen is
/// shown as a tab (`embedded`). Container height (66) + its bottom margin
/// (12) + a little breathing room. The device's bottom safe-area inset is
/// added on top at call sites via MediaQuery. Centered empty/error states
/// reserve this so their CTA never hides under the nav.
const double _kNavClearance = 96;

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

  /// Debounced search field. Empty = no search filter. The controller
  /// listens for edits and re-fires _load after a short delay so we
  /// don't hit the backend on every keystroke.
  final TextEditingController _searchCtl = TextEditingController();
  Timer? _searchDebounce;
  /// Last search string sent to the backend. Kept so a debounce tick
  /// with no change doesn't re-hit the network.
  String _lastQuery = '';
  static const _searchDebounceMs = 260;

  /// Whether the "How challenges work" explainer has been dismissed.
  /// Defaults to dismissed (hidden) until prefs load so it never flashes
  /// for a returning user who already closed it.
  static const _kHelpDismissedKey = 'challenges_help_dismissed';
  bool _helpDismissed = true;

  @override
  void initState() {
    super.initState();
    _load();
    _loadHelpState();
    _searchCtl.addListener(_onSearchChanged);
  }

  Future<void> _loadHelpState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dismissed = prefs.getBool(_kHelpDismissedKey) ?? false;
      if (mounted) setState(() => _helpDismissed = dismissed);
    } catch (_) {
      if (mounted) setState(() => _helpDismissed = false);
    }
  }

  Future<void> _dismissHelp() async {
    HapticService().selection();
    setState(() => _helpDismissed = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kHelpDismissedKey, true);
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtl.removeListener(_onSearchChanged);
    _searchCtl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    // Rebuild for the trailing "clear" X visibility.
    setState(() {});
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: _searchDebounceMs),
      () {
        final q = _searchCtl.text.trim();
        if (q == _lastQuery) return;
        _lastQuery = q;
        _load();
      },
    );
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ChallengeService().list(
        category: _category,
        search: _searchCtl.text,
      );
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

  void _clearSearch() {
    HapticService().selection();
    _searchCtl.clear();
    // No need to explicitly _load — the listener + debounce will fire
    // once and drop the search filter cleanly.
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

  Future<void> _openFriends() async {
    HapticService().light();
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const FriendsScreen()),
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
                onFriends: _openFriends,
                embedded: widget.embedded,
              ),
              _SearchBar(
                controller: _searchCtl,
                onClear: _searchCtl.text.isEmpty ? null : _clearSearch,
              ),
              _CategoryRow(
                current: _category,
                onSelect: _selectCategory,
              ),
              if (!_helpDismissed)
                _HowItWorksBanner(
                  onDismiss: _dismissHelp,
                  onCreate: _openCreate,
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
      return _ErrorState(
        message: _error!,
        onRetry: _load,
        embedded: widget.embedded,
      );
    }
    final list = _challenges ?? const <ChallengeSummary>[];
    if (list.isEmpty) {
      return _EmptyState(
        onCreate: _openCreate,
        onFriends: _openFriends,
        searchQuery: _searchCtl.text.trim(),
        embedded: widget.embedded,
      );
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
    required this.onFriends,
    required this.embedded,
  });
  final VoidCallback onMine;
  final VoidCallback onCreate;
  final VoidCallback onFriends;
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
            tooltip: 'Friends',
            onPressed: onFriends,
            icon: Icon(Icons.group_rounded,
                color: BrandColors.inkSoft(context)),
          ),
          IconButton(
            tooltip: 'Ranking',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RankingScreen(),
              ),
            ),
            icon: Icon(Icons.emoji_events_rounded,
                color: AppColors.pinkLight),
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

/// Dismissible three-step explainer. Answers the #1 confusion — "what
/// is this section and how do I use it?" — right where a new user lands.
class _HowItWorksBanner extends StatelessWidget {
  const _HowItWorksBanner({required this.onDismiss, required this.onCreate});
  final VoidCallback onDismiss;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 2),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.purple.withValues(alpha: 0.16),
              AppColors.pink.withValues(alpha: 0.12),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.purple.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_rounded, color: AppColors.pinkLight, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'How challenges work',
                    style: TextStyle(
                      color: BrandColors.ink(context),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onDismiss,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded,
                        color: BrandColors.inkSoft(context), size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const _Step(
              n: '1',
              text: 'Join a challenge below — or tap + to start your own.',
            ),
            const SizedBox(height: 8),
            const _Step(
              n: '2',
              text: 'Check in once a day before the deadline to keep '
                  'your rank climbing.',
            ),
            const SizedBox(height: 8),
            const _Step(
              n: '3',
              text: 'Invite friends and rise from Recruit to Legend '
                  'together.',
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onCreate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  gradient: AppColors.buttonGradient,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Text(
                  'Start a challenge',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
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

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});
  final String n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.purple.withValues(alpha: 0.35),
          ),
          child: Text(
            n,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              text,
              style: TextStyle(
                color: BrandColors.inkSoft(context),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.onCreate,
    required this.onFriends,
    required this.searchQuery,
    required this.embedded,
  });
  final VoidCallback onCreate;
  final VoidCallback onFriends;
  /// When non-empty, the empty state is a "no results for X" screen
  /// (search didn't match anything) rather than a "no challenges
  /// yet" screen (list actually empty).
  final String searchQuery;
  /// True when shown as a tab (floating nav overlays the bottom). Adds
  /// nav clearance so the CTA sits fully above the nav bar.
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final searching = searchQuery.isNotEmpty;
    final iconData = searching
        ? Icons.search_off_rounded
        : Icons.flag_rounded;
    final title = searching
        ? 'No challenges found'
        : 'Be the first to start one.';
    final subtitle = searching
        ? 'Nothing matched "$searchQuery". Want to create it?'
        : 'A challenge is a shared goal: everyone checks in once a day '
            'and climbs the ranks together. Create one, then invite '
            'friends to join you.';
    final bottomClear =
        embedded ? _kNavClearance + MediaQuery.viewPaddingOf(context).bottom : 0.0;
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(32, 0, 32, bottomClear),
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
              child: Icon(iconData,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: GoogleFonts.bricolageGrotesque(
                color: BrandColors.ink(context),
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
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
            const SizedBox(height: 12),
            // Secondary path so the friends feature is reachable even
            // with zero challenges: find + follow people first, then
            // invite them from any challenge you create/join.
            TextButton.icon(
              onPressed: onFriends,
              icon: Icon(Icons.group_rounded,
                  color: AppColors.pinkLight, size: 18),
              label: Text(
                'Find friends',
                style: TextStyle(
                  color: AppColors.pinkLight,
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact search bar under the header — one line, 40px tall, matches
/// the collapsed-category-pill styling on Habits. `onClear` is null
/// while the input is empty; when set, renders a trailing X.
class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller, required this.onClear});
  final TextEditingController controller;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: BrandColors.bgCard(context).withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: AppColors.purple.withValues(alpha: 0.22),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded,
                color: BrandColors.inkSoft(context), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.search,
                style: TextStyle(
                  color: BrandColors.ink(context),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Search challenges',
                  hintStyle: TextStyle(
                    color: BrandColors.inkDim(context),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(Icons.close_rounded,
                      color: BrandColors.inkSoft(context), size: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    this.embedded = false,
  });
  final String message;
  final VoidCallback onRetry;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final bottomClear =
        embedded ? _kNavClearance + MediaQuery.viewPaddingOf(context).bottom : 0.0;
    return Center(
      child: Padding(
        padding: EdgeInsets.fromLTRB(24, 0, 24, bottomClear),
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
