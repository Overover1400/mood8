import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/challenge.dart';
import '../../services/challenge_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';

/// Bottom sheet to find friends (people you follow) or search anyone by
/// name, follow them, and invite the selected people to [challengeId].
/// Resolves to the number of invites actually sent (null if dismissed).
Future<int?> showInviteFriendsSheet(
  BuildContext context, {
  required int challengeId,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _InviteFriendsSheet(challengeId: challengeId),
  );
}

class _InviteFriendsSheet extends StatefulWidget {
  const _InviteFriendsSheet({required this.challengeId});
  final int challengeId;

  @override
  State<_InviteFriendsSheet> createState() => _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends State<_InviteFriendsSheet> {
  final TextEditingController _searchCtl = TextEditingController();
  Timer? _debounce;

  List<ChallengeUser> _rows = const [];
  final Set<int> _selected = <int>{};
  bool _loading = true;
  bool _searching = false;
  bool _sending = false;
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

  Future<void> _send() async {
    if (_selected.isEmpty || _sending) return;
    setState(() => _sending = true);
    HapticService().medium();
    try {
      final count = await ChallengeService()
          .invite(widget.challengeId, _selected.toList());
      if (!mounted) return;
      Navigator.of(context).pop(count);
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(
          e is ChallengeError ? e.message : 'Could not send invites.',
        )),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: BrandColors.bgCard(context),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppColors.purple.withValues(alpha: 0.20)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: BrandColors.inkFaint(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(Icons.person_add_alt_1_rounded,
                        color: AppColors.pinkLight, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Invite friends',
                      style: brandFont(
                        color: BrandColors.ink(context),
                        fontSize: 20,
                        weight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Search anyone by name, follow them, then invite.',
                    style: TextStyle(
                      color: BrandColors.inkDim(context),
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _searchBar(context),
              const SizedBox(height: 8),
              Flexible(child: _body(context)),
              _sendBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _searchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: BrandColors.bg(context).withValues(alpha: 0.6),
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
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation(Color(0xFFEC4899)),
            ),
          ),
        ),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: TextStyle(color: BrandColors.inkSoft(context)),
        ),
      );
    }
    if (_rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 34),
        child: Column(
          children: [
            Icon(
              _isSearchMode
                  ? Icons.search_off_rounded
                  : Icons.group_add_rounded,
              color: BrandColors.inkDim(context),
              size: 34,
            ),
            const SizedBox(height: 12),
            Text(
              _isSearchMode
                  ? 'No one found. Try another name.'
                  : "You're not following anyone yet.\n"
                      'Search above to find people to invite.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: BrandColors.inkSoft(context),
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: _rows.length,
      separatorBuilder: (_, _) => const SizedBox(height: 6),
      itemBuilder: (_, i) => _row(context, _rows[i]),
    );
  }

  Widget _row(BuildContext context, ChallengeUser u) {
    final selected = _selected.contains(u.id);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticService().selection();
          setState(() {
            if (selected) {
              _selected.remove(u.id);
            } else {
              _selected.add(u.id);
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.purple.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
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
                        fontSize: 14,
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
              // Inline follow toggle so users can follow-then-select.
              GestureDetector(
                onTap: () => _toggleFollow(u),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: u.isFollowing
                        ? Colors.transparent
                        : AppColors.purple.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(20),
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
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? AppColors.pinkLight
                    : BrandColors.inkFaint(context),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sendBar(BuildContext context) {
    final n = _selected.length;
    final enabled = n > 0 && !_sending;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: enabled ? _send : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 15),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppColors.buttonGradient,
                borderRadius: BorderRadius.circular(26),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(
                      n == 0 ? 'Select people to invite' : 'Invite $n',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: 0.3,
                      ),
                    ),
            ),
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
    return Container(
      width: 40,
      height: 40,
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
                fontSize: 16,
              ),
            )
          : null,
    );
  }
}
