import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/deep_link_service.dart' show kDeepLinkReturnUrl;

import '../services/haptic_service.dart';
import '../services/subscription_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mood_orb.dart';
import '../widgets/responsive_container.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key, this.contextNote});

  /// Optional in-screen explanation of *why* the paywall fired
  /// (e.g. "Unlimited habits is a Premium feature").
  final String? contextNote;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  String _selectedPlan = 'annual'; // default-on most-value plan
  bool _loading = false;
  String? _error;

  Future<void> _startCheckout() async {
    if (_loading) return;
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
                      style: GoogleFonts.instrumentSerif(
                        color: BrandColors.ink(context),
                        fontSize: 42,
                        height: 1.0,
                      ),
                    ),
                    Text(
                      'potential.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.instrumentSerif(
                        color: AppColors.ink,
                        fontStyle: FontStyle.italic,
                        fontSize: 42,
                        height: 1.05,
                        foreground: Paint()
                          ..shader = AppColors.primaryGradient.createShader(
                            const Rect.fromLTWH(0, 0, 320, 70),
                          ),
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
                    const SizedBox(height: 26),
                    _PlanCard(
                      title: 'Annual',
                      price: r'$29',
                      cadence: '/year',
                      monthlyEquivalent: r'$2.42 / mo',
                      badge: 'Best value — save 39%',
                      selected: _selectedPlan == 'annual',
                      accent: AppColors.pinkLight,
                      onTap: () =>
                          setState(() => _selectedPlan = 'annual'),
                    ),
                    const SizedBox(height: 10),
                    _PlanCard(
                      title: 'Monthly',
                      price: r'$3.99',
                      cadence: '/month',
                      monthlyEquivalent: 'Try it. Cancel anytime.',
                      selected: _selectedPlan == 'monthly',
                      accent: AppColors.purpleLight,
                      onTap: () =>
                          setState(() => _selectedPlan = 'monthly'),
                    ),
                    const SizedBox(height: 10),
                    _PlanCard(
                      title: 'Lifetime',
                      price: r'$129',
                      cadence: 'one-time',
                      monthlyEquivalent: 'Pay once. Forever.',
                      badge: 'Pay once',
                      selected: _selectedPlan == 'lifetime',
                      accent: AppColors.blueAccent,
                      onTap: () =>
                          setState(() => _selectedPlan = 'lifetime'),
                    ),
                    const SizedBox(height: 24),
                    _CTAButton(
                      label: _loading ? 'Opening…' : 'Start Premium',
                      onTap: _loading ? null : _startCheckout,
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
                    _FeatureList(),
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
                        style: GoogleFonts.instrumentSerif(
                          color: BrandColors.ink(context),
                          fontStyle: FontStyle.italic,
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
                  style: GoogleFonts.instrumentSerif(
                    color: BrandColors.ink(context),
                    fontStyle: FontStyle.italic,
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
  static const _features = [
    'Unlimited habits and routines',
    'Unlimited AI Coach messages',
    '3 streak freezes per week',
    'Premium cinematic effects',
    'Custom identity themes',
    'Advanced insights + pattern alerts',
    'Weekly recap emails',
    'Priority support',
  ];

  @override
  Widget build(BuildContext context) {
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
            "What's included",
            style: GoogleFonts.instrumentSerif(
              color: BrandColors.ink(context),
              fontStyle: FontStyle.italic,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 12),
          for (final f in _features) ...[
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
          style: GoogleFonts.instrumentSerif(
            color: BrandColors.ink(context),
            fontStyle: FontStyle.italic,
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
                  style: GoogleFonts.instrumentSerif(
                    color: BrandColors.ink(context),
                    fontStyle: FontStyle.italic,
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
          style: GoogleFonts.instrumentSerif(
            color: BrandColors.ink(context),
            fontStyle: FontStyle.italic,
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
