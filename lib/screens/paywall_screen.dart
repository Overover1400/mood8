import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/subscription.dart';
import '../services/deep_link_service.dart' show kDeepLinkReturnUrl;

import '../services/haptic_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mood_orb.dart';
import '../widgets/responsive_container.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({
    super.key,
    this.contextNote,
    this.highlightPlus = false,
  });

  /// Optional in-screen explanation of *why* the paywall fired
  /// (e.g. "Unlimited habits is a Premium feature").
  final String? contextNote;

  /// When true, the paywall opens on the Premium Plus tier toggle
  /// instead of Premium. Used by entry points where the paywall fires
  /// from a Plus-only feature (the AI Habit Packages screen).
  final bool highlightPlus;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  /// Which tier the user is shopping for right now — flips the price
  /// labels + the plan_key prefix sent to the backend. Premium Plus
  /// plan keys are `plus_monthly`/`plus_annual`/`plus_lifetime`.
  bool _shoppingPlus = false;
  String _selectedCadence = 'annual'; // default-on most-value plan
  bool _loading = false;
  String? _error;

  /// Stripe-computed quote for the currently selected plan when it
  /// would be an in-place upgrade (Premium → Premium Plus, same
  /// billing cadence family). Null when not applicable (free user,
  /// fresh checkout, lifetime, downgrade, same tier).
  UpgradePreview? _preview;
  bool _previewLoading = false;
  String? _previewedPlanKey;

  @override
  void initState() {
    super.initState();
    _shoppingPlus = widget.highlightPlus;
    SubscriptionService().addListener(_onSubscriptionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshPreview());
  }

  @override
  void dispose() {
    SubscriptionService().removeListener(_onSubscriptionChanged);
    super.dispose();
  }

  void _onSubscriptionChanged() {
    if (!mounted) return;
    setState(() {});
    _refreshPreview();
  }

  String get _selectedPlan =>
      _shoppingPlus ? 'plus_$_selectedCadence' : _selectedCadence;

  // ─── Plan-relationship helpers ─────────────────────────────────────
  // These collapse the user's current tier into the actions a paywall
  // card should expose: is this row their current plan, an upgrade, a
  // downgrade, or a fresh purchase? The CTA label + the prorated
  // preview both branch off these. See _CTAAction enum below.

  SubscriptionTier get _currentTier => SubscriptionService().tier;

  bool get _currentIsPlus =>
      _currentTier == SubscriptionTier.premiumPlus ||
      _currentTier == SubscriptionTier.premiumPlusLifetime;
  bool get _currentIsRecurring =>
      _currentTier == SubscriptionTier.premium ||
      _currentTier == SubscriptionTier.premiumPlus;

  /// True when this exact selection matches what the user already pays
  /// for. Renders the CTA as a disabled "Current plan" affordance.
  bool get _isOnCurrentPlan {
    if (_shoppingPlus) {
      if (_selectedCadence == 'lifetime') {
        return _currentTier == SubscriptionTier.premiumPlusLifetime;
      }
      return _currentTier == SubscriptionTier.premiumPlus;
    }
    if (_selectedCadence == 'lifetime') {
      return _currentTier == SubscriptionTier.premiumLifetime;
    }
    return _currentTier == SubscriptionTier.premium;
  }

  /// True when the selection is a strict downgrade — Plus user
  /// shopping a Premium-only plan. Surfaced as a "Downgrade" CTA so
  /// the user understands what happens.
  bool get _isDowngrade => _currentIsPlus && !_shoppingPlus;

  /// True when the selection is an in-place subscription change that
  /// Stripe will prorate (recurring → recurring, not a downgrade, not
  /// the plan they already have). Lifetime targets short-circuit out
  /// because Stripe Checkout creates a separate one-off invoice and
  /// the webhook handler cancels the recurring sub afterwards. We
  /// surface the prorated quote any time this is true so the user
  /// sees the real number before tapping (covers Premium → Plus and
  /// also same-tier cadence swaps like monthly → annual).
  bool get _isInPlaceUpgrade =>
      _currentIsRecurring &&
      !_isOnCurrentPlan &&
      !_isDowngrade &&
      _selectedCadence != 'lifetime';

  Future<void> _refreshPreview() async {
    if (!_isInPlaceUpgrade) {
      if (_preview != null || _previewLoading) {
        setState(() {
          _preview = null;
          _previewLoading = false;
          _previewedPlanKey = null;
        });
      }
      return;
    }
    final planKey = _selectedPlan;
    if (_previewedPlanKey == planKey && _preview != null) return;
    setState(() {
      _previewLoading = true;
      _preview = null;
      _previewedPlanKey = planKey;
    });
    final quote = await SubscriptionService().previewUpgrade(planKey);
    if (!mounted || _previewedPlanKey != planKey) return;
    setState(() {
      _preview = quote;
      _previewLoading = false;
    });
  }

  void _onCadenceTapped(String cadence) {
    if (_selectedCadence == cadence) return;
    setState(() => _selectedCadence = cadence);
    _refreshPreview();
  }

  void _onTierToggled(bool plus) {
    if (_shoppingPlus == plus) return;
    setState(() => _shoppingPlus = plus);
    _refreshPreview();
  }

  Future<void> _startCheckout() async {
    if (_loading) return;
    if (_isOnCurrentPlan) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    HapticService().light();
    // Native clients deep-link back; web stays on the existing
    // ?checkout=success page handled by AuthGate.
    final returnUrl = kIsWeb ? null : kDeepLinkReturnUrl;
    final url = await SubscriptionService()
        .startCheckout(_selectedPlan, returnUrl: returnUrl);
    if (!mounted) return;
    if (url == null) {
      setState(() {
        _loading = false;
        _error = "Couldn't open checkout. Check your connection and sign-in.";
      });
      return;
    }
    final uri = Uri.parse(url);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_self',
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (!launched) {
      setState(() => _error = "Couldn't open Stripe checkout.");
    }
  }

  List<Widget> _buildPlanCards() {
    final spec = _shoppingPlus ? _kPlusPlans : _kPremiumPlans;
    final out = <Widget>[];
    for (var i = 0; i < spec.length; i++) {
      final p = spec[i];
      final isCurrent = _isCadenceCurrent(p.cadence);
      out.add(_PlanCard(
        title: p.title,
        price: p.price,
        cadence: p.cadenceLabel,
        monthlyEquivalent: p.subtitle,
        badge: isCurrent ? 'Current plan' : p.badge,
        selected: _selectedCadence == p.cadence,
        accent: p.accent,
        onTap: () => _onCadenceTapped(p.cadence),
      ));
      if (i < spec.length - 1) out.add(const SizedBox(height: 10));
    }
    return out;
  }

  bool _isCadenceCurrent(String cadence) {
    if (_shoppingPlus) {
      if (cadence == 'lifetime') {
        return _currentTier == SubscriptionTier.premiumPlusLifetime;
      }
      return _currentTier == SubscriptionTier.premiumPlus;
    }
    if (cadence == 'lifetime') {
      return _currentTier == SubscriptionTier.premiumLifetime;
    }
    return _currentTier == SubscriptionTier.premium;
  }

  String _ctaLabel() {
    if (_loading) return 'Opening…';
    if (_isOnCurrentPlan) return 'Current plan';
    if (_isDowngrade) return 'Switch to Premium';
    if (_isInPlaceUpgrade) return 'Upgrade to Premium Plus';
    return _shoppingPlus ? 'Start Premium Plus' : 'Start Premium';
  }

  Future<void> _restore() async {
    HapticService().light();
    await SubscriptionService().refreshStatus();
    if (!mounted) return;
    final isPremium = SubscriptionService().isPremium;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isPremium
              ? 'Premium restored. Thanks for being here.'
              : 'No active subscription on this account.',
        ),
      ),
    );
    if (isPremium && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      body: Stack(
        children: [
          const _BackgroundGlow(),
          SafeArea(
            child: ResponsiveContainer(
              maxWidth: 560,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: BrandColors.inkSoft(context),
                        ),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: const MoodOrb(size: 120),
                    )
                        .animate()
                        .fadeIn(duration: 500.ms)
                        .scaleXY(begin: 0.85, end: 1.0, duration: 600.ms),
                    const SizedBox(height: 24),
                    Text(
                      'Unlock your full',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.bricolageGrotesque(
                        color: BrandColors.ink(context),
                        fontSize: 42,
                        height: 1.0,
                      ),
                    ),
                    GradientText(
                      'potential.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.bricolageGrotesque(
                        fontSize: 42,
                        height: 1.05,
                      ),
                    ),
                    if (widget.contextNote != null) ...[
                      const SizedBox(height: 14),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.pink.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.pinkLight
                                  .withValues(alpha: 0.50),
                            ),
                          ),
                          child: Text(
                            widget.contextNote!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.pinkLight,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    _TierToggle(
                      plus: _shoppingPlus,
                      onChanged: _onTierToggled,
                    ),
                    const SizedBox(height: 18),
                    ..._buildPlanCards(),
                    const SizedBox(height: 18),
                    if (_isInPlaceUpgrade) _ProratedBanner(
                      preview: _preview,
                      loading: _previewLoading,
                    ),
                    if (_isDowngrade) const _DowngradeNotice(),
                    const SizedBox(height: 18),
                    _CTAButton(
                      label: _ctaLabel(),
                      onTap: (_loading || _isOnCurrentPlan)
                          ? null
                          : _startCheckout,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.pinkLight,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Center(
                      child: TextButton(
                        onPressed: _restore,
                        child: Text(
                          'Restore purchase',
                          style: TextStyle(
                            color: BrandColors.inkSoft(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _FeatureList(plus: _shoppingPlus),
                    const SizedBox(height: 26),
                    _Testimonials(),
                    const SizedBox(height: 26),
                    _FAQ(),
                    const SizedBox(height: 24),
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
            ),
          ),
        ],
      ),
    );
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
              top: -120,
              right: -80,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.purple.withValues(alpha: 0.32),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              left: -100,
              child: Container(
                width: 340,
                height: 340,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.pink.withValues(alpha: 0.25),
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

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.cadence,
    required this.monthlyEquivalent,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.badge,
  });
  final String title;
  final String price;
  final String cadence;
  final String monthlyEquivalent;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.30),
                    accent.withValues(alpha: 0.10),
                  ],
                )
              : null,
          color: selected
              ? null
              : BrandColors.bgCard(context).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? accent.withValues(alpha: 0.75)
                : AppColors.purple.withValues(alpha: 0.20),
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.30),
                    blurRadius: 18,
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: selected ? AppColors.buttonGradient : null,
                color: selected ? null : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? Colors.transparent
                      : BrandColors.inkFaint(context).withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.bricolageGrotesque(
                          color: BrandColors.ink(context),
                          fontSize: 22,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.20),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: accent.withValues(alpha: 0.45),
                            ),
                          ),
                          child: Text(
                            badge!,
                            style: TextStyle(
                              color: accent,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    monthlyEquivalent,
                    style: TextStyle(
                      color: BrandColors.inkDim(context),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: GoogleFonts.bricolageGrotesque(
                    color: BrandColors.ink(context),
                    fontSize: 22,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cadence,
                  style: TextStyle(
                    color: BrandColors.inkDim(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CTAButton extends StatelessWidget {
  const _CTAButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.6 : 1.0,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.buttonGradient,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.pink.withValues(alpha: 0.50),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: AppColors.purple.withValues(alpha: 0.40),
                blurRadius: 30,
                spreadRadius: -4,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_open_rounded,
                  color: Colors.white, size: 20),
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
      ),
    );
  }
}

class _FeatureList extends StatelessWidget {
  const _FeatureList({required this.plus});
  final bool plus;

  static const _premiumFeatures = [
    'Unlimited habits and routines',
    'Unlimited AI Coach messages',
    '3 streak freezes per week',
    'Premium cinematic effects',
    'Custom identity themes',
    'Advanced insights + pattern alerts',
    'Weekly recap emails',
    'Priority support',
  ];

  static const _plusExtras = [
    'Everything in Premium',
    '10 curated Habit Packages — science-backed routines',
    'Personalized AI Habit Packages designed by Mood8 for your goals',
    'AI Coach can add the habits it suggests, in one tap',
  ];

  @override
  Widget build(BuildContext context) {
    final features = plus ? _plusExtras : _premiumFeatures;
    final title = plus ? "What's in Premium Plus" : "What's included";
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.bricolageGrotesque(
              color: BrandColors.ink(context),
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 12),
          for (final f in features) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppColors.pinkLight.withValues(alpha: 0.85),
                        AppColors.purple.withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 14),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    f,
                    style: TextStyle(
                      color: BrandColors.inkSoft(context),
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// Wire-level plan spec for the paywall — separates copy from the
/// build loop so the same widget renders both Premium and Premium Plus
/// without an if/else cascade per row.
class _PaywallPlanSpec {
  const _PaywallPlanSpec({
    required this.cadence,
    required this.title,
    required this.price,
    required this.cadenceLabel,
    required this.subtitle,
    required this.accent,
    this.badge,
  });
  final String cadence; // "annual" | "monthly" | "lifetime"
  final String title;
  final String price;
  final String cadenceLabel;
  final String subtitle;
  final Color accent;
  final String? badge;
}

final List<_PaywallPlanSpec> _kPremiumPlans = [
  const _PaywallPlanSpec(
    cadence: 'annual',
    title: 'Annual',
    price: r'$29',
    cadenceLabel: '/year',
    subtitle: r'$2.42 / mo',
    accent: AppColors.pinkLight,
    badge: 'Best value — save 39%',
  ),
  const _PaywallPlanSpec(
    cadence: 'monthly',
    title: 'Monthly',
    price: r'$3.99',
    cadenceLabel: '/month',
    subtitle: 'Try it. Cancel anytime.',
    accent: AppColors.purpleLight,
  ),
  const _PaywallPlanSpec(
    cadence: 'lifetime',
    title: 'Lifetime',
    price: r'$129',
    cadenceLabel: 'one-time',
    subtitle: 'Pay once. Forever.',
    accent: AppColors.blueAccent,
    badge: 'Pay once',
  ),
];

final List<_PaywallPlanSpec> _kPlusPlans = [
  const _PaywallPlanSpec(
    cadence: 'annual',
    title: 'Annual',
    price: r'$49',
    cadenceLabel: '/year',
    subtitle: r'$4.08 / mo',
    accent: AppColors.pinkLight,
    badge: 'Best value — save 41%',
  ),
  const _PaywallPlanSpec(
    cadence: 'monthly',
    title: 'Monthly',
    price: r'$6.99',
    cadenceLabel: '/month',
    subtitle: 'Try it. Cancel anytime.',
    accent: AppColors.purpleLight,
  ),
  const _PaywallPlanSpec(
    cadence: 'lifetime',
    title: 'Lifetime',
    price: r'$199',
    cadenceLabel: 'one-time',
    subtitle: 'Pay once. Forever.',
    accent: AppColors.blueAccent,
    badge: 'Pay once',
  ),
];

/// Banner shown above the CTA when the user is upgrading an existing
/// Premium recurring sub to Premium Plus. The amount comes from
/// Stripe via /api/stripe/preview-upgrade — we never compute proration
/// client-side. While the preview is in-flight we show a quiet
/// placeholder so the UI doesn't jump when the number arrives.
class _ProratedBanner extends StatelessWidget {
  const _ProratedBanner({required this.preview, required this.loading});
  final UpgradePreview? preview;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.purpleLight.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppColors.buttonGradient,
            ),
            child: const Icon(Icons.bolt_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (loading || preview == null)
                  Text(
                    loading
                        ? 'Calculating prorated price…'
                        : "You'll be charged the prorated difference today.",
                    style: TextStyle(
                      color: BrandColors.ink(context),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                else ...[
                  Text(
                    "You'll be charged ${preview!.formattedAmountDue} today",
                    style: TextStyle(
                      color: BrandColors.ink(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview!.prorationCreditCents > 0
                        ? '(prorated · ${preview!.formattedCredit} credit from your current plan)'
                        : '(prorated by Stripe — unused time on your current plan is credited)',
                    style: TextStyle(
                      color: BrandColors.inkSoft(context),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
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
}

/// Small note shown when a Plus subscriber is shopping a Premium-only
/// plan — sets expectations before they tap "Switch to Premium".
class _DowngradeNotice extends StatelessWidget {
  const _DowngradeNotice();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.blueAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.blueAccent.withValues(alpha: 0.40),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              color: AppColors.blueAccent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "You'll lose access to AI Habit Packages. Unused time on Premium Plus is credited.",
              style: TextStyle(
                color: BrandColors.inkSoft(context),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Testimonials extends StatelessWidget {
  static const _quotes = [
    ('"Mood8 finally got me to journal daily."', 'Maya · 7-month streak'),
    ('"The AI Coach feels like a thoughtful friend."', 'Noah · 12 weeks in'),
    ('"Worth it just for the weekly recap."', 'Sara · annual subscriber'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'What people say',
          style: GoogleFonts.bricolageGrotesque(
            color: BrandColors.ink(context),
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 10),
        for (final q in _quotes) ...[
          Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              color: BrandColors.bgCard(context).withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.pinkLight.withValues(alpha: 0.18),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  q.$1,
                  style: GoogleFonts.bricolageGrotesque(
                    color: BrandColors.ink(context),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  q.$2,
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
      ],
    );
  }
}

class _FAQ extends StatefulWidget {
  @override
  State<_FAQ> createState() => _FAQState();
}

class _FAQState extends State<_FAQ> {
  int? _open;

  static const _items = [
    (
      'Can I cancel anytime?',
      'Yes. One tap from Settings opens the Stripe billing portal and you '
          'can cancel in seconds. No phone calls, no forms.'
    ),
    (
      'What happens to my data if I cancel?',
      'Everything stays. Your habits, routines, reflections, and history '
          'remain — you just stop getting Premium-only features.'
    ),
    (
      'Will it sync between devices?',
      "Multi-device sync is coming soon. For now Mood8 is per-device with "
          "an export/import option."
    ),
    (
      "What's the difference between annual and lifetime?",
      "Annual is the best ongoing value. Lifetime is one payment forever — "
          "ideal if you know you're in for the long haul."
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Questions, answered',
          style: GoogleFonts.bricolageGrotesque(
            color: BrandColors.ink(context),
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < _items.length; i++)
          _FAQRow(
            question: _items[i].$1,
            answer: _items[i].$2,
            expanded: _open == i,
            onTap: () => setState(() => _open = _open == i ? null : i),
          ),
      ],
    );
  }
}

class _FAQRow extends StatelessWidget {
  const _FAQRow({
    required this.question,
    required this.answer,
    required this.expanded,
    required this.onTap,
  });
  final String question;
  final String answer;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: BrandColors.bgCard(context).withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.purple.withValues(alpha: 0.22),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    question,
                    style: TextStyle(
                      color: BrandColors.ink(context),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 220),
                  child: Icon(
                    Icons.expand_more_rounded,
                    color: BrandColors.inkSoft(context),
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 2),
                child: Text(
                  answer,
                  style: TextStyle(
                    color: BrandColors.inkSoft(context),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
              crossFadeState: expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 240),
            ),
          ],
        ),
      ),
    );
  }
}

/// Premium ↔ Premium Plus segmented toggle. Visually mirrors the
/// other segmented controls in the app (Progress/Insights, freq
/// picker, etc.) but with a pink-tinted "PLUS" side and a small
/// "+ Habit Packages" badge on the Plus end to signal what the extra
/// $3/mo buys.
class _TierToggle extends StatelessWidget {
  const _TierToggle({required this.plus, required this.onChanged});

  final bool plus;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          _TierTab(
            label: 'Premium',
            selected: !plus,
            gradient: AppColors.buttonGradient,
            onTap: () => onChanged(false),
          ),
          _TierTab(
            label: 'Premium Plus',
            sub: '+ Habit Packages',
            selected: plus,
            gradient: const LinearGradient(
              colors: [
                Color(0xFFA855F7),
                Color(0xFFEC4899),
                Color(0xFFF472B6),
              ],
            ),
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _TierTab extends StatelessWidget {
  const _TierTab({
    required this.label,
    required this.selected,
    required this.gradient,
    required this.onTap,
    this.sub,
  });

  final String label;
  final String? sub;
  final bool selected;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticService().selection();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected ? gradient : null,
            borderRadius: BorderRadius.circular(18),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.pink.withValues(alpha: 0.35),
                      blurRadius: 14,
                      spreadRadius: -3,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? Colors.white
                      : BrandColors.inkSoft(context),
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.2,
                ),
              ),
              if (sub != null)
                Text(
                  sub!,
                  style: TextStyle(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.92)
                        : BrandColors.inkDim(context),
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    letterSpacing: 0.4,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
