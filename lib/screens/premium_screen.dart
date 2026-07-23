import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/subscription.dart';
import '../services/haptic_service.dart';
import '../services/purchase_service.dart';
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
                      priceLine: r'$6.99/month · $49/year · $199 lifetime',
                      isCurrent: tier.isPaid,
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFFA855F7),
                          Color(0xFFEC4899),
                          Color(0xFFF472B6),
                        ],
                      ),
                      // Streak freezes bullet removed for launch —
                      // gated by kStreakFreezeEnabled. Re-add
                      // alongside re-enabling the flag.
                      bullets: const [
                        'Unlimited habits and routines',
                        'Unlimited AI Coach messages',
                        '10 curated Habit Packages',
                        'Personalized AI Habit Packages designed by Mood8 for your goals',
                        'AI Coach can add the habits it suggests, in one tap',
                        'Multi-device sync (web, Android, watch)',
                        'Premium cinematic celebrations',
                        'Advanced insights + pattern alerts',
                        'Weekly recap emails',
                        'Custom identity themes',
                      ],
                    ),
                    const SizedBox(height: 22),
                    _CTAStack(tier: tier),
                    const SizedBox(height: 18),
                    // Checkout footer hidden during the promo (no upsell).
                    if (!svc.freeModeActive)
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
                    // "Have a code?" — free-access redemption. Deliberately
                    // separate from all pricing/checkout above: it never
                    // mentions money and never opens a purchase flow, so
                    // it's safe to show inside the Android app.
                    const SizedBox(height: 26),
                    const _RedeemCodeCard(),
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
  });

  final String title;
  final String tagline;
  final String priceLine;
  final List<String> bullets;
  final Gradient gradient;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final badge = isCurrent ? 'Current plan' : null;
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
    final canPurchaseInApp = PurchaseService().supportsInAppPurchase;
    // During the free-mode promo, suppress the upgrade CTA for non-payers
    // and show a single tasteful line instead (no checkout surface).
    if (!tier.isPaid && SubscriptionService().freeModeActive) {
      return const _FreeModeNotice();
    }
    if (!tier.isPaid) {
      // Free user. On web → normal "See plans" opens the paywall
      // with a live checkout button. On native mobile (Play Billing
      // not wired yet) → CTA opens mood8.app directly, which is
      // where the subscription actually gets created; the app will
      // pick up Premium status from the backend on the next
      // refresh, no restart needed.
      return _GradientCTA(
        label: canPurchaseInApp ? 'See plans' : 'Upgrade on mood8.app',
        icon: canPurchaseInApp
            ? Icons.lock_open_rounded
            : Icons.open_in_new_rounded,
        onTap: () => canPurchaseInApp
            ? _openPaywall(context)
            : _openManageInBrowser(context),
      );
    }
    // Paid user. On web → open Stripe billing portal in place.
    // On native mobile → point the user to mood8.app to manage
    // billing so we don't ship an in-app path to Stripe's hosted
    // billing page (technically account management, but keeping
    // the mobile app free of ALL billing surfaces is the safest
    // compliance posture for launch).
    return _GradientCTA(
      label: canPurchaseInApp
          ? 'Manage subscription'
          : 'Manage on mood8.app',
      icon: canPurchaseInApp
          ? Icons.tune_rounded
          : Icons.open_in_new_rounded,
      onTap: () => canPurchaseInApp
          ? _openBillingPortal(context)
          : _openManageInBrowser(context),
    );
  }

  void _openPaywall(BuildContext context) {
    HapticService().light();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PaywallScreen(),
      ),
    );
  }

  Future<void> _openManageInBrowser(BuildContext context) async {
    HapticService().light();
    final messenger = ScaffoldMessenger.of(context);
    final ok = await openManageInBrowser();
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't open mood8.app — try opening it in your browser.",
          ),
        ),
      );
    }
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

/// Shown in place of the upgrade CTA during the free-mode promo. Purely
/// informational — no prices, no checkout, Play-safe on Android.
class _FreeModeNotice extends StatelessWidget {
  const _FreeModeNotice();

  static const List<String> _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    final ends = SubscriptionService().freeModeEndsAt;
    final line = ends == null
        ? 'Every Premium feature is free right now — enjoy 💜'
        : 'Every Premium feature is free until '
            '${_months[ends.month - 1]} ${ends.day} — enjoy 💜';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.purple.withValues(alpha: 0.18),
            AppColors.pink.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.pinkLight.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_rounded,
              color: Color(0xFFF472B6), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              line,
              style: TextStyle(
                color: BrandColors.ink(context),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Have a code?" — redeem a comp / free-access code for Premium time.
/// Free path only: no prices, no checkout, no store links (Play-safe on
/// Android). On success the app's Premium status refreshes immediately.
class _RedeemCodeCard extends StatefulWidget {
  const _RedeemCodeCard();

  @override
  State<_RedeemCodeCard> createState() => _RedeemCodeCardState();
}

class _RedeemCodeCardState extends State<_RedeemCodeCard> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _busy = false;
  String? _message;
  bool _ok = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    if (_busy) return;
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() {
        _ok = false;
        _message = 'Enter a code to redeem.';
      });
      return;
    }
    FocusScope.of(context).unfocus();
    HapticService().light();
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await SubscriptionService().redeemPromoCode(code);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _ok = result.success;
      _message = result.message;
    });
    if (result.success) {
      HapticService().reward();
      _controller.clear();
    } else {
      HapticService().medium();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.redeem_rounded,
                  color: AppColors.pinkLight, size: 20),
              const SizedBox(width: 10),
              Text(
                'Have a code?',
                style: GoogleFonts.bricolageGrotesque(
                  color: BrandColors.ink(context),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Redeem a Mood8 access code for Premium.',
            style: TextStyle(
              color: BrandColors.inkSoft(context),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _redeem(),
                  style: TextStyle(
                    color: BrandColors.ink(context),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter code',
                    hintStyle: TextStyle(
                      color: BrandColors.inkDim(context),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                    filled: true,
                    fillColor: BrandColors.bgDeep(context)
                        .withValues(alpha: 0.5),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppColors.purple.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppColors.pinkLight.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _busy ? null : _redeem,
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.buttonGradient,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.pink.withValues(alpha: 0.35),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Redeem',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),
            ],
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _ok
                      ? Icons.check_circle_rounded
                      : Icons.error_outline_rounded,
                  color: _ok
                      ? const Color(0xFF34D399)
                      : AppColors.pinkLight,
                  size: 17,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _message!,
                    style: TextStyle(
                      color: _ok
                          ? const Color(0xFF34D399)
                          : BrandColors.inkSoft(context),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

