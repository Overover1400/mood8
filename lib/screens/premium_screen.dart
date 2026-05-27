import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/subscription.dart';
import '../services/haptic_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_container.dart';
import 'paywall_screen.dart';

/// Settings → Membership. The "what tier am I on, what do I get, how
/// do I move tiers" page. Pricing here mirrors the paywall (single
/// source of truth — if you change prices, update both). For paying
/// users the CTA opens the Stripe billing portal; for upgrades it
/// drops into the paywall.
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key});

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
        title: Text('Membership',
            style: Theme.of(context).textTheme.headlineSmall),
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: SubscriptionService(),
          builder: (context, _) {
            final svc = SubscriptionService();
            final tier = svc.tier;
            return ResponsiveContainer(
              maxWidth: 600,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CurrentPlanCard(tier: tier, expiresAt: svc.expiresAt)
                        .animate()
                        .fadeIn(duration: 380.ms)
                        .slideY(
                            begin: 0.04, end: 0, curve: Curves.easeOut),
                    const SizedBox(height: 22),
                    _TierBenefitsCard(
                      title: 'Mood8 Premium',
                      tagline: 'Everything that compounds.',
                      priceLine: r'From $3.99/month · $29/year · $129 lifetime',
                      isCurrent: tier == SubscriptionTier.premium ||
                          tier == SubscriptionTier.premiumLifetime,
                      isLockedBecausePlus: tier.isPlus,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFA855F7),
                          Color(0xFFEC4899),
                        ],
                      ),
                      bullets: const [
                        'Unlimited habits and routines',
                        'Unlimited AI Coach messages',
                        'Multi-device sync (web, Android, watch)',
                        '3 streak freezes per week',
                        'Premium cinematic celebrations',
                        'Advanced insights + pattern alerts',
                        'Weekly recap emails',
                        'Custom identity themes',
                      ],
                    ),
                    const SizedBox(height: 14),
                    _TierBenefitsCard(
                      title: 'Mood8 Premium Plus',
                      tagline: 'Premium + AI-designed packages.',
                      priceLine: r'From $6.99/month · $49/year · $199 lifetime',
                      isCurrent: tier.isPlus,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFA855F7),
                          Color(0xFFEC4899),
                          Color(0xFFF472B6),
                        ],
                      ),
                      bullets: const [
                        'Everything in Premium',
                        '10 curated Habit Packages',
                        'Personalized AI Habit Packages designed by Mood8 for your goals',
                        'AI Coach can add the habits it suggests, in one tap',
                      ],
                    ),
                    const SizedBox(height: 22),
                    _CTAStack(tier: tier),
                    const SizedBox(height: 18),
                    Center(
                      child: Text(
                        'Secure checkout by Stripe · cancel anytime',
                        style: TextStyle(
                          color: BrandColors.inkDim(context),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  const _CurrentPlanCard({required this.tier, required this.expiresAt});
  final SubscriptionTier tier;
  final DateTime? expiresAt;

  @override
  Widget build(BuildContext context) {
    final isPaid = tier.isPaid;
    final gradient = isPaid
        ? AppColors.buttonGradient
        : LinearGradient(
            colors: [
              AppColors.purple.withValues(alpha: 0.22),
              AppColors.pink.withValues(alpha: 0.10),
            ],
          );
    final label = isPaid ? tier.label : 'Free';
    final sub = _subtitleFor(tier, expiresAt);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isPaid
              ? AppColors.pinkLight.withValues(alpha: 0.55)
              : AppColors.purple.withValues(alpha: 0.30),
        ),
        boxShadow: isPaid
            ? [
                BoxShadow(
                  color: AppColors.pink.withValues(alpha: 0.40),
                  blurRadius: 26,
                  spreadRadius: -6,
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: isPaid ? 0.22 : 0.06),
              border: Border.all(
                color: Colors.white.withValues(alpha: isPaid ? 0.42 : 0.18),
                width: 1.2,
              ),
            ),
            child: Icon(
              isPaid
                  ? Icons.workspace_premium_rounded
                  : Icons.lock_open_rounded,
              color: isPaid ? Colors.white : AppColors.pinkLight,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENT PLAN',
                  style: TextStyle(
                    color: isPaid
                        ? Colors.white.withValues(alpha: 0.85)
                        : BrandColors.inkDim(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: GoogleFonts.bricolageGrotesque(
                    color: isPaid ? Colors.white : BrandColors.ink(context),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    sub,
                    style: TextStyle(
                      color: isPaid
                          ? Colors.white.withValues(alpha: 0.92)
                          : BrandColors.inkSoft(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String? _subtitleFor(SubscriptionTier tier, DateTime? expiresAt) {
    if (!tier.isPaid) return "Upgrade any time — your data stays.";
    if (tier.isLifetime) return 'Paid once. Yours forever.';
    if (expiresAt != null) {
      final d = expiresAt;
      final mm = d.month.toString().padLeft(2, '0');
      final dd = d.day.toString().padLeft(2, '0');
      return 'Renews $mm/$dd/${d.year}';
    }
    return 'Active subscription.';
  }
}

class _TierBenefitsCard extends StatelessWidget {
  const _TierBenefitsCard({
    required this.title,
    required this.tagline,
    required this.priceLine,
    required this.bullets,
    required this.gradient,
    required this.isCurrent,
    this.isLockedBecausePlus = false,
  });

  final String title;
  final String tagline;
  final String priceLine;
  final List<String> bullets;
  final Gradient gradient;
  final bool isCurrent;
  /// True when the user is on Premium Plus and we're rendering the
  /// "regular Premium" tier card. Premium Plus is a strict superset,
  /// so a Plus subscriber already gets everything below — we badge it
  /// "Included" instead of "Current plan" or "Upgrade".
  final bool isLockedBecausePlus;

  @override
  Widget build(BuildContext context) {
    final badge = isCurrent
        ? 'Current plan'
        : isLockedBecausePlus
            ? 'Included in Plus'
            : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isCurrent
              ? AppColors.pinkLight.withValues(alpha: 0.55)
              : AppColors.purple.withValues(alpha: 0.22),
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: AppColors.pink.withValues(alpha: 0.25),
                  blurRadius: 22,
                  spreadRadius: -6,
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: gradient,
                ),
                child: const Icon(Icons.diamond_outlined,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.bricolageGrotesque(
                        color: BrandColors.ink(context),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tagline,
                      style: TextStyle(
                        color: BrandColors.inkSoft(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: isCurrent ? gradient : null,
                    color: isCurrent
                        ? null
                        : AppColors.purple.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: AppColors.pinkLight.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Text(
                    badge.toUpperCase(),
                    style: TextStyle(
                      color: isCurrent
                          ? Colors.white
                          : AppColors.pinkLight,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            priceLine,
            style: TextStyle(
              color: BrandColors.inkDim(context),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          for (final b in bullets) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_rounded,
                    color: AppColors.pinkLight, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    b,
                    style: TextStyle(
                      color: BrandColors.ink(context),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _CTAStack extends StatelessWidget {
  const _CTAStack({required this.tier});
  final SubscriptionTier tier;

  @override
  Widget build(BuildContext context) {
    if (!tier.isPaid) {
      return _GradientCTA(
        label: 'See plans',
        icon: Icons.lock_open_rounded,
        onTap: () => _openPaywall(context, plus: false),
      );
    }
    if (tier.isPlus) {
      return Column(
        children: [
          _GradientCTA(
            label: 'Manage subscription',
            icon: Icons.tune_rounded,
            onTap: () => _openBillingPortal(context),
          ),
        ],
      );
    }
    // Premium (non-Plus).
    return Column(
      children: [
        _GradientCTA(
          label: 'Upgrade to Premium Plus',
          icon: Icons.diamond_outlined,
          onTap: () => _openPaywall(context, plus: true),
        ),
        const SizedBox(height: 10),
        _SecondaryCTA(
          label: 'Manage subscription',
          icon: Icons.tune_rounded,
          onTap: () => _openBillingPortal(context),
        ),
      ],
    );
  }

  void _openPaywall(BuildContext context, {required bool plus}) {
    HapticService().light();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PaywallScreen(highlightPlus: plus),
      ),
    );
  }

  Future<void> _openBillingPortal(BuildContext context) async {
    HapticService().light();
    final messenger = ScaffoldMessenger.of(context);
    final url = await SubscriptionService().openBillingPortal();
    if (url == null) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't open billing portal. Check your connection.",
          ),
        ),
      );
      return;
    }
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: kIsWeb ? '_self' : null,
    );
  }
}

class _GradientCTA extends StatelessWidget {
  const _GradientCTA({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

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
              color: AppColors.pink.withValues(alpha: 0.45),
              blurRadius: 22,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryCTA extends StatelessWidget {
  const _SecondaryCTA({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: BrandColors.bgCard(context).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.purple.withValues(alpha: 0.32),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: BrandColors.inkSoft(context), size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: BrandColors.ink(context),
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
