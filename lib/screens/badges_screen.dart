import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/badge_category.dart';
import '../models/earned_badge.dart';
import '../services/badge_definitions.dart';
import '../services/badge_service.dart';
import '../services/haptic_service.dart';
import '../theme/app_theme.dart';
import '../widgets/badge_unlock_modal.dart';
import '../widgets/responsive_container.dart';

class BadgesScreen extends StatefulWidget {
  const BadgesScreen({super.key});

  @override
  State<BadgesScreen> createState() => _BadgesScreenState();
}

class _BadgesScreenState extends State<BadgesScreen> {
  final BadgeService _service = BadgeService();
  late final ValueListenable<Box<EarnedBadge>> _listenable = _service.watch();

  Map<String, double> _progress = const {};
  Map<BadgeCategory, int> _counters = const {};
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final progress = await _service.getProgress();
    final counters = await _service.getCategoryCounters();
    if (!mounted) return;
    setState(() {
      _progress = progress;
      _counters = counters;
      _loaded = true;
    });
  }

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
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Achievements',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 720,
          child: ValueListenableBuilder<Box<EarnedBadge>>(
            valueListenable: _listenable,
            builder: (context, box, _) {
              // Re-pull derived data when the box changes.
              if (_loaded) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _refresh();
                });
              }
              final earnedKeys = <String>{
                for (final b in box.values) b.badgeKey,
              };
              final earnedCount = earnedKeys.length;
              final total = BadgeCatalog.count;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _StatsHeader(earned: earnedCount, total: total)
                        .animate()
                        .fadeIn(duration: 350.ms)
                        .slideY(
                            begin: -0.05, end: 0, curve: Curves.easeOut),
                    const SizedBox(height: 24),
                    for (final cat in BadgeCategory.values) ...[
                      _CategorySection(
                        category: cat,
                        definitions: BadgeCatalog.forCategory(cat),
                        earnedKeys: earnedKeys,
                        earnedRecords: <String, EarnedBadge>{
                          for (final b in box.values) b.badgeKey: b,
                        },
                        progress: _progress,
                        currentCount: _counters[cat] ?? 0,
                      ),
                      const SizedBox(height: 26),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.earned, required this.total});
  final int earned;
  final int total;

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : earned / total;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.purple.withValues(alpha: 0.22),
            AppColors.pink.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.pinkLight.withValues(alpha: 0.40),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.pinkLight.withValues(alpha: 0.85),
                      AppColors.purple.withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.pink.withValues(alpha: 0.45),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Badges earned',
                      style: TextStyle(
                        color: BrandColors.inkDim(context),
                        fontSize: 11,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '$earned',
                          style: GoogleFonts.bricolageGrotesque(
                            color: BrandColors.ink(context),
                            fontSize: 32,
                            height: 1.0,
                          ),
                        ),
                        Text(
                          ' / $total',
                          style: TextStyle(
                            color: BrandColors.inkSoft(context),
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Container(
                  height: 8,
                  color: BrandColors.bg(context).withValues(alpha: 0.7),
                ),
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                  widthFactor: pct.clamp(0, 1),
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: AppColors.buttonGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.pink.withValues(alpha: 0.45),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.category,
    required this.definitions,
    required this.earnedKeys,
    required this.earnedRecords,
    required this.progress,
    required this.currentCount,
  });

  final BadgeCategory category;
  final List<BadgeDefinition> definitions;
  final Set<String> earnedKeys;
  final Map<String, EarnedBadge> earnedRecords;
  final Map<String, double> progress;
  final int currentCount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppColors.buttonGradient,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              category.label.toUpperCase(),
              style: TextStyle(
                color: BrandColors.inkDim(context),
                fontSize: 10,
                letterSpacing: 1.8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 540 ? 4 : 3;
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: definitions.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.86,
            ),
            itemBuilder: (context, i) {
              final def = definitions[i];
              final earned = earnedKeys.contains(def.key);
              return _BadgeTile(
                definition: def,
                earned: earned,
                earnedRecord: earnedRecords[def.key],
                progress: progress[def.key] ?? 0,
                currentCount: currentCount,
              )
                  .animate(delay: (40 * i).ms)
                  .fadeIn(duration: 280.ms)
                  .slideY(
                      begin: 0.04, end: 0, curve: Curves.easeOut);
            },
          );
        }),
      ],
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({
    required this.definition,
    required this.earned,
    required this.earnedRecord,
    required this.progress,
    required this.currentCount,
  });

  final BadgeDefinition definition;
  final bool earned;
  final EarnedBadge? earnedRecord;
  final double progress;
  final int currentCount;

  @override
  Widget build(BuildContext context) {
    final accent = definition.accent;
    return GestureDetector(
      onTap: () {
        HapticService().light();
        if (earned && earnedRecord != null) {
          showDialog<void>(
            context: context,
            builder: (_) => BadgeDetailPopup(badge: earnedRecord!),
          );
        } else {
          _showLockedDetail(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: earned
                ? [
                    accent.withValues(alpha: 0.22),
                    accent.withValues(alpha: 0.06),
                  ]
                : [
                    BrandColors.bgCard(context).withValues(alpha: 0.85),
                    BrandColors.bg(context).withValues(alpha: 0.65),
                  ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: earned
                ? accent.withValues(alpha: 0.55)
                : AppColors.purple.withValues(alpha: 0.16),
          ),
          boxShadow: earned
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.30),
                    blurRadius: 18,
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: earned
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                definition.gradientStart,
                                definition.gradientEnd,
                              ],
                            )
                          : null,
                      color: earned
                          ? null
                          : BrandColors.bg(context).withValues(alpha: 0.55),
                    ),
                    child: Icon(
                      definition.icon,
                      size: 28,
                      color: earned
                          ? Colors.white
                          : BrandColors.inkFaint(context)
                              .withValues(alpha: 0.7),
                    ),
                  ),
                  if (!earned)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 18,
                        height: 18,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: BrandColors.bgCard(context),
                          border: Border.all(
                            color: BrandColors.inkFaint(context)
                                .withValues(alpha: 0.55),
                          ),
                        ),
                        child: Icon(
                          Icons.lock_rounded,
                          size: 10,
                          color: BrandColors.inkDim(context),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              definition.title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.bricolageGrotesque(
                color: earned ? BrandColors.ink(context) : BrandColors.inkDim(context),
                fontSize: 13,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            if (!earned) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  height: 4,
                  child: Stack(
                    children: [
                      Container(
                        color: BrandColors.bg(context).withValues(alpha: 0.7),
                      ),
                      FractionallySizedBox(
                        widthFactor: progress.clamp(0, 1).toDouble(),
                        child: Container(
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _progressLabel(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: BrandColors.inkFaint(context),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ] else
              Text(
                'EARNED',
                style: TextStyle(
                  color: accent,
                  fontSize: 9,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _progressLabel() {
    final clamped = currentCount.clamp(0, definition.threshold);
    return '$clamped / ${definition.threshold}';
  }

  void _showLockedDetail(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: BrandColors.bgCard(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lock_rounded,
                  color: BrandColors.inkDim(context),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  definition.title,
                  style: GoogleFonts.bricolageGrotesque(
                    color: BrandColors.ink(context),
                    fontSize: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              definition.description,
              style: TextStyle(
                color: BrandColors.inkSoft(context),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Progress: ${currentCount.clamp(0, definition.threshold)} '
              '/ ${definition.threshold}',
              style: TextStyle(
                color: BrandColors.inkDim(context),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              'Close',
              style: TextStyle(
                color: AppColors.purpleLight,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
