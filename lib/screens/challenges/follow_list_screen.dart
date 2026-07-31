import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/challenge.dart';
import '../../services/challenge_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/responsive_container.dart';
import '../profile/public_profile_screen.dart';

enum FollowListMode { followers, following }

/// Shows a user's followers or following list, with a per-row
/// follow/unfollow button and a search field to find new people to
/// follow. Reachable from the tappable Followers/Following counts on a
/// profile. `userId` is whose list this is; the follow buttons reflect
/// the SIGNED-IN viewer's relationship.
class FollowListScreen extends StatefulWidget {
  const FollowListScreen({
    super.key,
    required this.userId,
    required this.mode,
    this.title,
  });

  final int userId;
  final FollowListMode mode;
  final String? title;

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  final TextEditingController _searchCtl = TextEditingController();
  Timer? _debounce;

  List<ChallengeUser> _rows = const [];
  bool _loading = true;
  bool _searching = false;
  String? _error;

  bool get _isSearchMode => _searchCtl.text.trim().length >= 2;

  String get _title =>
      widget.title ??
      (widget.mode == FollowListMode.followers ? 'Followers' : 'Following');

  @override
  void initState() {
    super.initState();
    _loadList();
    _searchCtl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  Future<void> _loadList() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = widget.mode == FollowListMode.followers
          ? await ChallengeService().followers(widget.userId)
          : await ChallengeService().following(widget.userId);
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ChallengeError ? e.message : 'Could not load list.';
      });
    }
  }

  void _onSearchChanged() {
    setState(() {});
    _debounce?.cancel();
    final q = _searchCtl.text.trim();
    if (q.length < 2) {
      _loadList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 640,
          child: Column(
            children: [
              _header(context),
              _searchBar(context),
              const SizedBox(height: 6),
              Expanded(child: _body(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 20, 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded,
                color: BrandColors.inkSoft(context)),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: Text(
              _title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: brandFont(
                color: BrandColors.ink(context),
                fontSize: 28,
                weight: FontWeight.w800,
                height: 1.0,
                letterSpacing: -0.4,
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
                  hintText: 'Search people to follow',
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
      final msg = _isSearchMode
          ? 'No one found. Try another name.'
          : widget.mode == FollowListMode.followers
              ? 'No followers yet.'
              : 'Not following anyone yet.\nSearch above to find people.';
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Text(
            msg,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: BrandColors.inkSoft(context),
              fontSize: 14,
              height: 1.4,
            ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                PublicProfileScreen(userId: u.id, initialName: u.name),
          ),
        ),
        child: Padding(
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        ),
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
    final abs = (url != null && url!.isNotEmpty)
        ? (url!.startsWith('http') ? url! : 'https://mood8.app$url')
        : null;
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.orbGradient,
        image: abs != null
            ? DecorationImage(image: NetworkImage(abs), fit: BoxFit.cover)
            : null,
      ),
      child: abs == null
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
