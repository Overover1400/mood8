import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/challenge.dart';
import '../../services/challenge_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';

/// Bottom sheet that lets the user pick friends (search by name or pick
/// from people they follow) and returns the SELECTED user ids — it does
/// NOT send anything itself. Used by the create-challenge flow to gather
/// invitees before the challenge exists; the caller sends the invites
/// once it has a challenge id. Returns null if dismissed.
Future<Set<int>?> showPickFriendsSheet(
  BuildContext context, {
  Set<int> initialSelected = const {},
}) {
  return showModalBottomSheet<Set<int>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PickFriendsSheet(initialSelected: initialSelected),
  );
}

class _PickFriendsSheet extends StatefulWidget {
  const _PickFriendsSheet({required this.initialSelected});
  final Set<int> initialSelected;

  @override
  State<_PickFriendsSheet> createState() => _PickFriendsSheetState();
}

class _PickFriendsSheetState extends State<_PickFriendsSheet> {
  final TextEditingController _searchCtl = TextEditingController();
  Timer? _debounce;

  List<ChallengeUser> _rows = const [];
  late final Set<int> _selected;
  // Names for selected users so the button count reads sensibly even
  // after the row scrolls out of the current result set.
  final Map<int, ChallengeUser> _known = {};
  bool _loading = true;
  bool _searching = false;
  String? _error;

  bool get _isSearchMode => _searchCtl.text.trim().length >= 2;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initialSelected};
    _loadFriends();
    _searchCtl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtl.dispose();
    super.dispose();
  }

  void _remember(List<ChallengeUser> rows) {
    for (final u in rows) {
      _known[u.id] = u;
    }
  }

  Future<void> _loadFriends() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await ChallengeService().friends();
      if (!mounted) return;
      _remember(rows);
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
      _remember(rows);
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
              const SizedBox(height: 12),
              _searchBar(context),
              const SizedBox(height: 8),
              Flexible(child: _body(context)),
              _doneBar(context),
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
        child: Text(
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
                child: Text(
                  u.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: BrandColors.ink(context),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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

  Widget _doneBar(BuildContext context) {
    final n = _selected.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
      child: SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(_selected),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 15),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppColors.buttonGradient,
              borderRadius: BorderRadius.circular(26),
            ),
            child: Text(
              n == 0 ? 'Done' : 'Add $n friend${n == 1 ? '' : 's'}',
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
      width: 40,
      height: 40,
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
                fontSize: 16,
              ),
            )
          : null,
    );
  }
}
