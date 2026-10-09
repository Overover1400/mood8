import 'package:flutter/material.dart';

import '../../models/personalization.dart';
import '../../services/haptic_service.dart';
import '../../services/personalization_service.dart';
import '../../services/profile_mirror.dart';
import '../../services/user_repository.dart';
import '../../theme/app_theme.dart';

/// Review and change the answers the suggestions are built on: when the
/// user has the most energy, what they want to improve, what usually gets
/// in the way, and who they want to be. A change is saved at once and
/// shapes the next suggestions.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<ProfileQuestion>? _questions;
  bool _loading = true;
  String? _saving;
  final Map<String, Set<String>> _pending = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final q = await PersonalizationService().fetchProfile();
    if (!mounted) return;
    setState(() {
      _questions = q;
      _loading = false;
      _pending
        ..clear()
        ..addEntries([
          for (final x in q ?? const <ProfileQuestion>[])
            if (x.multi) MapEntry(x.key, {...x.selected})
        ]);
    });
  }

  Future<void> _save(ProfileQuestion q, Object value) async {
    if (_saving != null) return;
    setState(() => _saving = q.key);
    HapticService().selection();
    final r = await PersonalizationService().answer(q.key, value);
    if (r != null) {
      try {
        final repo = UserRepository();
        final u = repo.getCurrentUser();
        if (u != null && applyProfileAnswer(u, q.key, value)) {
          await repo.saveUser(u);
        }
      } catch (_) {/* the server copy is saved; the device copy is cosmetic */}
    }
    if (!mounted) return;
    setState(() => _saving = null);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(r == null
          ? "Couldn't save that. Try again."
          : 'Saved. Your suggestions will use this.'),
    ));
    if (r != null) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final qs = _questions;
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      appBar: AppBar(
        title: const Text('Goals & preferences'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : qs == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "Couldn't load your answers. Check your connection "
                            'and sign-in, then try again.',
                            textAlign: TextAlign.center,
                            style:
                                TextStyle(color: BrandColors.inkDim(context)),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                              onPressed: _load, child: const Text('Try again')),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                    children: [
                      Text(
                        'These answers shape the habits Mood8 suggests. '
                        'Change any of them whenever your life changes.',
                        style: TextStyle(
                            color: BrandColors.inkDim(context), fontSize: 13.5),
                      ),
                      for (final q in qs) _card(context, q),
                    ],
                  ),
      ),
    );
  }

  Widget _card(BuildContext context, ProfileQuestion q) {
    final busy = _saving == q.key;
    final picked = _pending[q.key] ?? {...q.selected};
    final changed = q.multi &&
        (picked.length != q.selected.length ||
            !picked.containsAll(q.selected));
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q.question,
              style: TextStyle(
                  color: BrandColors.ink(context),
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          if (!q.multi && q.selected.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('Not answered yet',
                  style: TextStyle(
                      color: BrandColors.inkFaint(context), fontSize: 12.5)),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in q.options)
                q.multi
                    ? FilterChip(
                        label: Text(o.label),
                        selected: picked.contains(o.value),
                        onSelected: busy
                            ? null
                            : (on) => setState(() {
                                  final s = _pending.putIfAbsent(
                                      q.key, () => {...q.selected});
                                  on ? s.add(o.value) : s.remove(o.value);
                                }),
                      )
                    : ChoiceChip(
                        label: Text(o.label),
                        selected: q.selected.contains(o.value),
                        onSelected: busy || q.selected.contains(o.value)
                            ? null
                            : (_) => _save(q, o.value),
                      ),
            ],
          ),
          if (q.multi) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: busy || !changed || picked.isEmpty
                    ? null
                    : () => _save(q, picked.toList()),
                child: Text(busy ? 'Saving...' : 'Save'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
