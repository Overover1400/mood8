import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/daily_data.dart';
import '../models/insight.dart';
import '../models/insight_type.dart';
import '../services/insights_ai_service.dart';
import '../services/insights_engine.dart';
import '../services/insights_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/ai_summary_card.dart';
import '../widgets/featured_insight_card.dart';
import '../widgets/insight_card.dart';
import '../widgets/insights_empty_state.dart';

enum _InsightFilter { strong, all, warnings, discoveries, actions }

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final InsightsEngine _engine = InsightsEngine();
  final InsightsRepository _repo = InsightsRepository();
  final InsightsAiService _ai = InsightsAiService();

  late final ValueListenable<Box<Insight>> _listenable =
      _repo.watchInsights();

  _InsightFilter _filter = _InsightFilter.strong;
  bool _refreshing = false;
  bool _summaryLoading = false;
  String? _summary;
  bool _autoRanDiscover = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoDiscover());
  }

  Future<void> _maybeAutoDiscover() async {
    if (_autoRanDiscover) return;
    _autoRanDiscover = true;
    final tracked = _engine.trackedDays();
    final existing = _repo.getAllInsights();
    final stale = existing.isEmpty ||
        DateTime.now()
                .difference(_repo.mostRecent()?.discoveredAt ?? DateTime(2000))
                .inHours >=
            12;
    if (tracked >= 7 && stale && !_refreshing) {
      await _refresh(silent: true);
    }
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await _engine.discover();
      if (!silent) HapticFeedback.lightImpact();
    } catch (e) {
      debugPrint('InsightsScreen.refresh failed: $e');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _generateSummary() async {
    if (_summaryLoading) return;
    setState(() => _summaryLoading = true);
    try {
      final context = await DailyData.gather();
      final insights = _repo.getActiveInsights();
      final text = await _ai.generateNarrative(insights, context: context);
      if (!mounted) return;
      setState(() => _summary = text);
    } catch (_) {
      if (!mounted) return;
      setState(() => _summary =
          'Mood8 couldn’t reach the coach. Try again in a moment.');
    } finally {
      if (mounted) setState(() => _summaryLoading = false);
    }
  }

  @override
  void dispose() {
    _ai.close();
    super.dispose();
  }

  List<Insight> _applyFilter(List<Insight> all) {
    switch (_filter) {
      case _InsightFilter.strong:
        return all.where((i) => i.confidence.abs() >= 0.5).toList();
      case _InsightFilter.all:
        return all;
      case _InsightFilter.warnings:
        return all.where((i) => i.type == InsightType.warning).toList();
      case _InsightFilter.discoveries:
        return all
            .where((i) =>
                i.type == InsightType.discovery ||
                i.type == InsightType.timePattern ||
                i.type == InsightType.rhythm ||
                i.type == InsightType.streakPattern)
            .toList();
      case _InsightFilter.actions:
        return all.where((i) => i.actionable).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          const _BackgroundGlow(),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 580),
                child: ValueListenableBuilder<Box<Insight>>(
                  valueListenable: _listenable,
                  builder: (context, _, _) {
                    final all = _repo.getActiveInsights();
                    final tracked = _engine.trackedDays();
                    final hasData = tracked >= 7;

                    if (!hasData) {
                      return SingleChildScrollView(
                        physics:
                            const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                            20, 16, 20, 180),
                        child: Column(
                          children: [
                            const _Header(),
                            const SizedBox(height: 24),
                            InsightsEmptyState(
                              daysTracked: tracked,
                              daysRequired: 7,
                            ),
                          ],
                        ),
                      );
                    }

                    final filtered = _applyFilter(all);
                    final featured = all.isEmpty ? null : all.first;
                    final rest = featured == null
                        ? filtered
                        : filtered
                            .where((i) => i.id != featured.id)
                            .toList();

                    return SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding:
                          const EdgeInsets.fromLTRB(20, 16, 20, 180),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _TopBar(
                            refreshing: _refreshing,
                            onRefresh: () => _refresh(),
                          ),
                          const SizedBox(height: 8),
                          const _Header(),
                          const SizedBox(height: 16),
                          _FilterStrip(
                            value: _filter,
                            onChanged: (f) =>
                                setState(() => _filter = f),
                          ),
                          const SizedBox(height: 18),
                          if (featured != null)
                            FeaturedInsightCard(
                              insight: featured,
                              onTap: () {},
                              onAction: () => _onAction(featured),
                            )
                                .animate()
                                .fadeIn(duration: 400.ms)
                                .slideY(
                                    begin: 0.05,
                                    end: 0,
                                    curve: Curves.easeOut),
                          if (featured != null)
                            const SizedBox(height: 18),
                          if (filtered.isEmpty && featured != null)
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text(
                                  'No insights matching this filter.',
                                  style: TextStyle(
                                    color: AppColors.inkDim,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          for (var i = 0; i < rest.length; i++) ...[
                            InsightCard(
                              insight: rest[i],
                              onDismiss: () =>
                                  _repo.dismissInsight(rest[i].id),
                              onAction: () => _onAction(rest[i]),
                            )
                                .animate(delay: (40 * i).ms)
                                .fadeIn(duration: 320.ms)
                                .slideY(
                                    begin: 0.04,
                                    end: 0,
                                    curve: Curves.easeOut),
                            if (i < rest.length - 1)
                              const SizedBox(height: 12),
                          ],
                          const SizedBox(height: 24),
                          AiSummaryCard(
                            summary: _summary,
                            loading: _summaryLoading,
                            onReload: _generateSummary,
                          ),
                          if (_summary == null) ...[
                            const SizedBox(height: 10),
                            Center(
                              child: TextButton.icon(
                                onPressed: _summaryLoading
                                    ? null
                                    : _generateSummary,
                                icon: Icon(Icons.auto_awesome_rounded,
                                    color: AppColors.purpleLight,
                                    size: 16),
                                label: Text(
                                  'Generate weekly summary',
                                  style: TextStyle(
                                    color: AppColors.purpleLight,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onAction(Insight i) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Marked as actioned.'),
        backgroundColor: AppColors.bgCard,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
    _repo.markActionTaken(i.id);
  }
}

class _BackgroundGlow extends StatelessWidget {
  const _BackgroundGlow();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              top: -90,
              left: -70,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.purple.withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              right: -100,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.pink.withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
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

class _TopBar extends StatelessWidget {
  const _TopBar({required this.refreshing, required this.onRefresh});
  final bool refreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: refreshing ? null : onRefresh,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bgCard.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.purple.withValues(alpha: 0.22),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  refreshing
                      ? Container(
                          width: 14,
                          height: 14,
                          padding: const EdgeInsets.all(1),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(AppColors.pinkLight),
                          ),
                        )
                      : Icon(Icons.refresh_rounded,
                          color: AppColors.purpleLight, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    refreshing ? 'Refreshing…' : 'Refresh',
                    style: TextStyle(
                      color: AppColors.inkSoft,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Insights',
          style: Theme.of(context)
              .textTheme
              .displaySmall
              ?.copyWith(fontSize: 32),
        ),
        const SizedBox(height: 2),
        Text(
          'What we’ve discovered about you',
          style: TextStyle(
            color: AppColors.inkDim,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _FilterStrip extends StatelessWidget {
  const _FilterStrip({required this.value, required this.onChanged});
  final _InsightFilter value;
  final ValueChanged<_InsightFilter> onChanged;

  static const _labels = {
    _InsightFilter.strong: 'Strong',
    _InsightFilter.all: 'All',
    _InsightFilter.warnings: 'Warnings',
    _InsightFilter.discoveries: 'Discoveries',
    _InsightFilter.actions: 'Actions',
  };

  @override
  Widget build(BuildContext context) {
    final entries = _labels.entries.toList();
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = entries[i].key;
          final selected = f == value;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(f);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: selected ? AppColors.buttonGradient : null,
                color: selected
                    ? null
                    : AppColors.bgCard.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : AppColors.purple.withValues(alpha: 0.20),
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.pink.withValues(alpha: 0.35),
                          blurRadius: 14,
                        ),
                      ]
                    : null,
              ),
              child: Text(
                entries[i].value,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.inkSoft,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
