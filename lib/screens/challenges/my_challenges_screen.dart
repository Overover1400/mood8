import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/challenge.dart';
import '../../services/challenge_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/challenges/challenge_card.dart';
import '../../widgets/responsive_container.dart';
import 'challenge_detail_screen.dart';

class MyChallengesScreen extends StatefulWidget {
  const MyChallengesScreen({super.key});

  @override
  State<MyChallengesScreen> createState() => _MyChallengesScreenState();
}

class _MyChallengesScreenState extends State<MyChallengesScreen> {
  List<ChallengeSummary>? _created;
  List<ChallengeSummary>? _joined;
  bool _loading = true;
  String? _error;

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
      final mine = await ChallengeService().mine();
      if (!mounted) return;
      setState(() {
        _created = mine.created;
        _joined = mine.joined;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is ChallengeError ? e.message : 'Could not load.';
      });
    }
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
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back_rounded,
                          color: BrandColors.inkSoft(context)),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    Text(
                      'My challenges',
                      style: GoogleFonts.instrumentSerif(
                        color: BrandColors.ink(context),
                        fontStyle: FontStyle.italic,
                        fontSize: 24,
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
    final created = _created ?? const <ChallengeSummary>[];
    final joined = _joined ?? const <ChallengeSummary>[];
    if (created.isEmpty && joined.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'You haven’t joined or created any challenges yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: BrandColors.inkSoft(context),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.pinkLight,
      backgroundColor: BrandColors.bgCard(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          if (created.isNotEmpty) ...[
            _Section(title: 'Created by me'),
            for (final c in created)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ChallengeCard(
                  challenge: c,
                  onTap: () => _open(c.id),
                ),
              ),
          ],
          if (joined.isNotEmpty) ...[
            _Section(title: 'I’m in'),
            for (final c in joined)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ChallengeCard(
                  challenge: c,
                  onTap: () => _open(c.id),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _open(int id) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChallengeDetailScreen(challengeId: id),
      ),
    );
    _load();
  }
}

class _Section extends StatelessWidget {
  // ignore: unused_element_parameter
  const _Section({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: BrandColors.inkDim(context),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}
