import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/gratitude_entry.dart';
import '../services/gratitude_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/gratitude_sheet.dart';
import '../widgets/responsive_container.dart';

/// Read-back surface for everything the user has saved through the
/// gratitude sheet. Tap any entry to edit it (re-opens the sheet
/// pre-filled). Newest first; grouped by month header so the user
/// can scan their streak at a glance.
class GratitudeHistoryScreen extends StatefulWidget {
  const GratitudeHistoryScreen({super.key});

  @override
  State<GratitudeHistoryScreen> createState() =>
      _GratitudeHistoryScreenState();
}

class _GratitudeHistoryScreenState extends State<GratitudeHistoryScreen> {
  final GratitudeRepository _repo = GratitudeRepository();
  late final ValueListenable<Box<GratitudeEntry>> _listenable =
      _repo.watchEntries();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: BrandColors.inkSoft(context), size: 18),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          'Gratitude',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 560,
          child: ValueListenableBuilder<Box<GratitudeEntry>>(
            valueListenable: _listenable,
            builder: (context, box, _) {
              // Pull newest first + drop completely empty entries.
              final entries = box.values
                  .where((e) => e.nonEmptyItems.isNotEmpty)
                  .toList()
                ..sort((a, b) => b.date.compareTo(a.date));
              if (entries.isEmpty) {
                return _Empty();
              }
              // Group by yyyy-MM so the list reads like a journal.
              final monthFmt = DateFormat('MMMM yyyy');
              String? lastHeader;
              final tiles = <Widget>[];
              for (var i = 0; i < entries.length; i++) {
                final e = entries[i];
                final header = monthFmt.format(e.date);
                if (header != lastHeader) {
                  tiles.add(_MonthHeader(label: header));
                  lastHeader = header;
                }
                tiles.add(
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
                    child: _EntryCard(
                      entry: e,
                      streakAnchor: _repo.currentStreakSync(),
                      onTap: () => _editEntry(e),
                    ),
                  )
                      .animate(delay: (24 * i).ms)
                      .fadeIn(duration: 280.ms)
                      .slideY(
                          begin: 0.04, end: 0, curve: Curves.easeOut),
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Summary(
                      total: entries.length,
                      streak: _repo.currentStreakSync(),
                      thisMonth: _repo.countThisMonth(),
                    ),
                    const SizedBox(height: 20),
                    ...tiles,
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _editEntry(GratitudeEntry e) async {
    await showGratitudeSheet(context, existing: e);
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.total,
    required this.streak,
    required this.thisMonth,
  });
  final int total;
  final int streak;
  final int thisMonth;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.pink.withValues(alpha: 0.22),
            AppColors.purple.withValues(alpha: 0.16),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.pinkLight.withValues(alpha: 0.42),
        ),
      ),
      child: Row(
        children: [
          _Stat(label: 'STREAK', value: '$streak'),
          const SizedBox(width: 16),
          _Stat(label: 'THIS MONTH', value: '$thisMonth'),
          const SizedBox(width: 16),
          _Stat(label: 'ALL TIME', value: '$total'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: BrandColors.inkDim(context),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.bricolageGrotesque(
              color: BrandColors.ink(context),
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 0, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: BrandColors.inkDim(context),
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.streakAnchor,
    required this.onTap,
  });
  final GratitudeEntry entry;
  final int streakAnchor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dayFmt = DateFormat('EEE · MMM d');
    final items = entry.nonEmptyItems;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            color: BrandColors.bgCard(context).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.pinkLight.withValues(alpha: 0.28),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    dayFmt.format(entry.date),
                    style: TextStyle(
                      color: AppColors.pinkLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.edit_outlined,
                      size: 14, color: BrandColors.inkDim(context)),
                ],
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < items.length; i++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppColors.pinkLight.withValues(alpha: 0.55),
                            AppColors.purple.withValues(alpha: 0.18),
                          ],
                        ),
                      ),
                      child: Text(
                        '${i + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        items[i],
                        style: TextStyle(
                          color: BrandColors.ink(context),
                          fontSize: 13.5,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                if (i < items.length - 1) const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.buttonGradient,
              ),
              child: const Icon(Icons.favorite_rounded,
                  color: Colors.white, size: 26),
            ),
            const SizedBox(height: 18),
            Text(
              'No gratitudes yet',
              style: GoogleFonts.bricolageGrotesque(
                color: BrandColors.ink(context),
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap the + on Home and pick Gratitude — three small things '
              'from your day. They show up here after.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: BrandColors.inkSoft(context),
                fontSize: 13.5,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
