import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/habit_packages.dart';
import '../services/habit_repository.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_container.dart';
import 'paywall_screen.dart';

/// Browse + start the 10 AI Habit Packages (Premium Plus). Free /
/// Premium users see the full grid but a "Plus required" overlay on
/// each detail screen with a Paywall CTA. Plus users get an active
/// Start button + a list of already-running packages.
class HabitPackagesScreen extends StatefulWidget {
  const HabitPackagesScreen({super.key});

  @override
  State<HabitPackagesScreen> createState() => _HabitPackagesScreenState();
}

class _HabitPackagesScreenState extends State<HabitPackagesScreen> {
  final HabitRepository _repo = HabitRepository();

  Set<String> get _running => _repo.activePackageIds().toSet();

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
          'Habit Packages',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 720,
          child: ListenableBuilder(
            listenable: SubscriptionService(),
            builder: (context, _) {
              final running = _running;
              final isPlus = SubscriptionService().isPremiumPlus;
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _HeaderCard(isPlus: isPlus),
                    const SizedBox(height: 20),
                    for (var i = 0; i < kHabitPackages.length; i++) ...[
                      _PackageTile(
                        pkg: kHabitPackages[i],
                        running: running.contains(kHabitPackages[i].id),
                        isPlus: isPlus,
                        onTap: () => _openDetail(kHabitPackages[i]),
                      )
                          .animate(delay: (40 * i).ms)
                          .fadeIn(duration: 320.ms)
                          .slideY(
                              begin: 0.04, end: 0, curve: Curves.easeOut),
                      if (i < kHabitPackages.length - 1)
                        const SizedBox(height: 12),
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

  Future<void> _openDetail(HabitPackage pkg) async {
    HapticFeedback.lightImpact();
    final didStart = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _PackageDetailScreen(pkg: pkg),
      ),
    );
    if (didStart == true && mounted) {
      // Trigger rebuild — Set built in build() is fresh, just need to
      // re-evaluate `_running`.
      setState(() {});
    }
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.isPlus});
  final bool isPlus;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.purple.withValues(alpha: 0.32),
            AppColors.pink.withValues(alpha: 0.22),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.pinkLight.withValues(alpha: 0.42),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.pink.withValues(alpha: 0.22),
            blurRadius: 22,
            spreadRadius: -10,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.buttonGradient,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPlus ? 'Choose your next program' : 'Premium Plus',
                  style: GoogleFonts.bricolageGrotesque(
                    color: BrandColors.ink(context),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isPlus
                      ? 'Curated multi-week programs — each one ships a'
                          ' fresh set of habits + a dedicated tab.'
                      : 'Ten curated multi-week programs designed to'
                          ' build a specific identity. Upgrade to start.',
                  style: TextStyle(
                    color: BrandColors.inkSoft(context),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
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

class _PackageTile extends StatelessWidget {
  const _PackageTile({
    required this.pkg,
    required this.running,
    required this.isPlus,
    required this.onTap,
  });

  final HabitPackage pkg;
  final bool running;
  final bool isPlus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                BrandColors.bgCard(context).withValues(alpha: 0.94),
                BrandColors.bg(context).withValues(alpha: 0.86),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: pkg.accent.withValues(alpha: 0.36),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      pkg.accent.withValues(alpha: 0.60),
                      pkg.accent.withValues(alpha: 0.12),
                    ],
                  ),
                  border: Border.all(
                    color: pkg.accent.withValues(alpha: 0.45),
                  ),
                ),
                child: Text(pkg.emoji,
                    style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            pkg.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.bricolageGrotesque(
                              color: BrandColors.ink(context),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (running) ...[
                          const SizedBox(width: 6),
                          const _RunningPill(),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pkg.tagline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: BrandColors.inkSoft(context),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 12, color: BrandColors.inkDim(context)),
                        const SizedBox(width: 4),
                        Text(
                          '${pkg.durationDays} days',
                          style: TextStyle(
                            color: BrandColors.inkDim(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(Icons.checklist_rounded,
                            size: 12, color: BrandColors.inkDim(context)),
                        const SizedBox(width: 4),
                        Text(
                          '${pkg.habitCount} habits',
                          style: TextStyle(
                            color: BrandColors.inkDim(context),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                isPlus
                    ? Icons.chevron_right_rounded
                    : Icons.lock_outline_rounded,
                color: isPlus
                    ? BrandColors.inkSoft(context)
                    : AppColors.pinkLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RunningPill extends StatelessWidget {
  const _RunningPill();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.pinkLight.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.pinkLight.withValues(alpha: 0.42),
        ),
      ),
      child: Text(
        'RUNNING',
        style: TextStyle(
          color: AppColors.pinkLight,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

/// Detail screen for a single package. Lists every habit, then a CTA:
/// Start (Plus user) or "Unlock Premium Plus" (everyone else).
class _PackageDetailScreen extends StatefulWidget {
  const _PackageDetailScreen({required this.pkg});
  final HabitPackage pkg;

  @override
  State<_PackageDetailScreen> createState() => _PackageDetailScreenState();
}

class _PackageDetailScreenState extends State<_PackageDetailScreen> {
  final HabitRepository _repo = HabitRepository();
  bool _starting = false;

  bool get _alreadyRunning =>
      _repo.activePackageIds().contains(widget.pkg.id);

  Future<void> _start() async {
    setState(() => _starting = true);
    try {
      final created = await _repo.startPackage(widget.pkg);
      HapticFeedback.mediumImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            created.isEmpty
                ? '${widget.pkg.name} is already running.'
                : '${widget.pkg.name} started — ${created.length} '
                    'habit${created.length == 1 ? '' : 's'} added.',
          ),
          backgroundColor: BrandColors.bgCard(context),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _starting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Couldn't start: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pkg = widget.pkg;
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
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: SubscriptionService(),
          builder: (context, _) {
            final isPlus = SubscriptionService().isPremiumPlus;
            return ResponsiveContainer(
              maxWidth: 640,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  _Hero(pkg: pkg),
                  const SizedBox(height: 20),
                  Text(
                    'What you’ll do',
                    style: TextStyle(
                      color: BrandColors.inkDim(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final item in pkg.items) ...[
                    _ItemRow(item: item, accent: pkg.accent),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 22),
                  if (_alreadyRunning)
                    _RunningCard(name: pkg.name)
                  else if (isPlus)
                    _StartButton(
                      label: _starting ? 'Starting…' : 'Start ${pkg.name}',
                      onTap: _starting ? null : _start,
                    )
                  else
                    _LockedCard(
                      onUpgrade: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const PaywallScreen(
                              contextNote:
                                  'AI Habit Packages are a Premium Plus feature.',
                              highlightPlus: true,
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.pkg});
  final HabitPackage pkg;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 80,
          height: 80,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                pkg.accent.withValues(alpha: 0.65),
                pkg.accent.withValues(alpha: 0.12),
              ],
            ),
            border: Border.all(
              color: pkg.accent.withValues(alpha: 0.50),
            ),
          ),
          child: Text(pkg.emoji, style: const TextStyle(fontSize: 38)),
        ),
        const SizedBox(height: 16),
        Text(
          pkg.name,
          style: GoogleFonts.bricolageGrotesque(
            color: BrandColors.ink(context),
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _Chip(icon: Icons.schedule_rounded, text: '${pkg.durationDays} days'),
            const SizedBox(width: 8),
            _Chip(
                icon: Icons.checklist_rounded,
                text: '${pkg.habitCount} habits'),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          pkg.goal,
          style: TextStyle(
            color: BrandColors.inkSoft(context),
            fontSize: 14.5,
            fontWeight: FontWeight.w500,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.purpleLight),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: BrandColors.inkSoft(context),
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item, required this.accent});
  final HabitPackageItem item;
  final Color accent;

  String _frequencyLabel() {
    switch (item.frequency.name) {
      case 'daily':
        return 'Daily';
      case 'weekdays':
        return 'Weekdays';
      case 'weekends':
        return 'Weekends';
      case 'xPerWeek':
        return '${item.targetValue ?? 1}× per week';
      default:
        return 'Custom';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  accent.withValues(alpha: 0.45),
                  accent.withValues(alpha: 0.10),
                ],
              ),
            ),
            child: Text(item.icon, style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: BrandColors.ink(context),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _frequencyLabel(),
                  style: TextStyle(
                    color: BrandColors.inkDim(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
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

class _StartButton extends StatelessWidget {
  const _StartButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppColors.buttonGradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.pink.withValues(alpha: 0.42),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 15,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

class _RunningCard extends StatelessWidget {
  const _RunningCard({required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: AppColors.pinkLight.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: AppColors.pinkLight.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, color: AppColors.pinkLight),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "$name is already running — its tab is on the Habits screen.",
              style: TextStyle(
                color: BrandColors.ink(context),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedCard extends StatelessWidget {
  const _LockedCard({required this.onUpgrade});
  final VoidCallback onUpgrade;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFA855F7), Color(0xFFEC4899)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.pink.withValues(alpha: 0.42),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded,
              color: Colors.white, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Premium Plus required',
                  style: GoogleFonts.bricolageGrotesque(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Unlock all 10 packages + everything in Premium.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onUpgrade,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55)),
              ),
              child: const Text(
                'See plans',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
