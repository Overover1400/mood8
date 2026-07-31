import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/challenge.dart';
import '../../services/challenge_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive_container.dart';
import 'create_challenge_screen.dart';

/// Standalone Friends hub, reachable from the Challenges tab (header +
/// empty state) so a user can find people, follow them, and build their
/// network BEFORE they ever join a challenge. Once they follow someone,
/// the invite sheet inside any challenge lists them as an invite target.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchCtl = TextEditingController();
  Timer? _debounce;

  List<ChallengeUser> _rows = const [];
  bool _loading = true;
  bool _searching = false;
  String? _error;

  bool get _isSearchMode => _searchCtl.text.trim().length >= 2;

  @override
  void initState() {
    super.initState();
    _loadFriends();
    _searchCtl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _loadFriends() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ChallengeService().friends();
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ChallengeError ? e.message : 'Could not load friends.';
      });
    }
  }

  void _onSearchChanged() {
    setState(() {});
    _debounce?.cancel();
    final q = _searchCtl.text.trim();
    if (q.length < 2) {
      _loadFriends();
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _runSearch(q));
  }

  Future<void> _runSearch(String q) async {
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final rows = await ChallengeService().searchUsers(q);
      if (!mounted || _searchCtl.text.trim() != q) return;
      setState(() {
        _rows = rows;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _error = e is ChallengeError ? e.message : 'Search failed.';
      });
    }
  }

  Future<void> _toggleFollow(ChallengeUser u) async {
    HapticService().selection();
    final idx = _rows.indexWhere((r) => r.id == u.id);
    if (idx < 0) return;
    final wasFollowing = u.isFollowing;
    setState(() {
      _rows = [
        for (var i = 0; i < _rows.length; i++)
          if (i == idx) _rows[i].copyWith(isFollowing: !wasFollowing)
          else _rows[i],
      ];
    });
    try {
      if (wasFollowing) {
        await ChallengeService().unfollow(u.id);
      } else {
        await ChallengeService().follow(u.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _rows = [
          for (var i = 0; i < _rows.length; i++)
            if (i == idx) _rows[i].copyWith(isFollowing: wasFollowing)
            else _rows[i],
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          e is ChallengeError ? e.message : "Couldn't update follow.",
        )),
      );
    }
  }

  Future<void> _startChallenge() async {
    HapticService().light();
    final id = await Navigator.of(context).push<int?>(
      MaterialPageRoute(builder: (_) => const CreateChallengeScreen()),
    );
    if (id != null && mounted) Navigator.of(context).pop();
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
              _header(context),
              _searchBar(context),
              const SizedBox(height: 4),
              if (!_isSearchMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _rows.isEmpty
                          ? 'Search by name to find people to follow.'
                          : 'People you follow',
                      style: TextStyle(
                        color: BrandColors.inkDim(context),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              Expanded(child: _body(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: BrandColors.inkSoft(context)),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              'Friends',
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
          TextButton.icon(
            onPressed: _startChallenge,
            icon: Icon(Icons.add_rounded, color: AppColors.pinkLight, size: 18),
            label: Text(
              'Challenge',
              style: TextStyle(
                color: AppColors.pinkLight,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 6),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: BrandColors.bgCard(context).withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.purple.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded,
                color: BrandColors.inkSoft(context), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchCtl,
                textInputAction: TextInputAction.search,
                style: TextStyle(
                  color: BrandColors.ink(context),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: 'Search people by name',
                  hintStyle: TextStyle(
                    color: BrandColors.inkDim(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  isDense: true,
                  border: InputBorder.none,
                ),
              ),
            ),
            if (_searchCtl.text.isNotEmpty)
              GestureDetector(
                onTap: () => _searchCtl.clear(),
                behavior: HitTestBehavior.opaque,
                child: Icon(Icons.close_rounded,
                    color: BrandColors.inkSoft(context), size: 16),
              ),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading || _searching) {
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
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: BrandColors.inkSoft(context)),
          ),
        ),
      );
    }
    if (_rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isSearchMode
                    ? Icons.search_off_rounded
                    : Icons.group_add_rounded,
                color: BrandColors.inkDim(context),
                size: 40,
              ),
              const SizedBox(height: 14),
              Text(
                _isSearchMode
                    ? 'No one found. Try another name.'
                    : "Find your friends by name and follow them.\n"
                        'Then invite them from any challenge.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: BrandColors.inkSoft(context),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 32),
      itemCount: _rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, i) => _row(context, _rows[i]),
    );
  }

  Widget _row(BuildContext context, ChallengeUser u) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          _Avatar(url: u.avatarUrl, name: u.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  u.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: BrandColors.ink(context),
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${u.challengeTier} · ${u.challengeScore} pts',
                  style: TextStyle(
                    color: BrandColors.inkDim(context),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _toggleFollow(u),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: u.isFollowing
                    ? Colors.transparent
                    : AppColors.purple.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppColors.purple.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                u.isFollowing ? 'Following' : 'Follow',
                style: TextStyle(
                  color: u.isFollowing
                      ? BrandColors.inkDim(context)
                      : BrandColors.inkSoft(context),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.url, required this.name});
  final String? url;
  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.orbGradient,
        image: (url != null && url!.isNotEmpty)
            ? DecorationImage(image: NetworkImage(url!), fit: BoxFit.cover)
            : null,
      ),
      child: (url == null || url!.isEmpty)
          ? Text(
              initial,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            )
          : null,
    );
  }
}
