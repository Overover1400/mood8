import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';

import '../models/pattern_alert.dart';
import '../services/haptic_service.dart';
import '../services/pattern_detection_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pattern_alert_card.dart';
import '../widgets/responsive_container.dart';
import 'main_navigation.dart';
import '../widgets/bottom_nav.dart';
import 'habit_detail_screen.dart';

class PatternsScreen extends StatefulWidget {
  const PatternsScreen({super.key});

  @override
  State<PatternsScreen> createState() => _PatternsScreenState();
}

class _PatternsScreenState extends State<PatternsScreen> {
  final PatternDetectionService _service = PatternDetectionService();
  PatternCategory? _filter;

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
          'Patterns noticed',
          style: GoogleFonts.instrumentSerif(
            color: BrandColors.ink(context),
            fontStyle: FontStyle.italic,
            fontSize: 22,
          ),
        ),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 600,
          child: ValueListenableBuilder<Box<PatternAlert>>(
            valueListenable: _service.watch(),
            builder: (context, _, _) {
              final all = _service.all();
              final filtered = _filter == null
                  ? all
                  : all.where((a) => a.category == _filter).toList();
              return Column(
                children: [
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _Chip(
                          label: 'All',
                          selected: _filter == null,
                          onTap: () => setState(() => _filter = null),
                        ),
                        for (final c in PatternCategory.values)
                          _Chip(
                            label: c.label,
                            selected: _filter == c,
                            onTap: () => setState(() => _filter = c),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: filtered.isEmpty
                        ? const _EmptyState()
                        : ListView.separated(
                            padding:
                                const EdgeInsets.fromLTRB(16, 12, 16, 32),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final a = filtered[i];
                              return PatternAlertCard(
                                alert: a,
                                onAction: () => _handleAction(a),
                                onDismiss: () => _service.dismiss(a),
                              )
                                  .animate(delay: (35 * i).ms)
                                  .fadeIn(duration: 280.ms)
                                  .slideY(
                                      begin: 0.04,
                                      end: 0,
                                      curve: Curves.easeOut);
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleAction(PatternAlert a) {
    HapticService().light();
    _service.markViewed(a);
    final route = a.actionRoute;
    if (route == null) {
      Navigator.of(context).maybePop();
      return;
    }
    Navigator.of(context).maybePop();
    if (route == 'coach') {
      MainNavigation.goToTab(context, kCoachTabIndex);
    } else if (route == 'habits') {
      MainNavigation.goToTab(context, kHabitsTabIndex);
    } else if (route == 'progress') {
      MainNavigation.goToTab(context, kProgressTabIndex);
    } else if (route == 'home') {
      MainNavigation.goToTab(context, 0);
    } else if (route.startsWith('habit:')) {
      final id = route.substring('habit:'.length);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HabitDetailScreen(habitId: id),
        ),
      );
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: selected ? AppColors.buttonGradient : null,
            color: selected
                ? null
                : BrandColors.bgCard(context).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : AppColors.purple.withValues(alpha: 0.22),
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
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 48),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.purpleLight.withValues(alpha: 0.45),
                    Colors.transparent,
                  ],
                ),
              ),
              child: const Icon(
                Icons.insights_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Nothing here yet',
              style: GoogleFonts.instrumentSerif(
                color: BrandColors.ink(context),
                fontStyle: FontStyle.italic,
                fontSize: 22,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Patterns will appear as we learn about you. Keep checking in.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: BrandColors.inkDim(context),
                fontSize: 13,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
String _relativeTime(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return DateFormat('MMM d').format(when);
}
