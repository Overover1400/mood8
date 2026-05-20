import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/sfx_type.dart';
import '../services/haptic_service.dart';
import '../services/sfx_service.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_container.dart';

class _Plan {
  const _Plan({
    required this.label,
    required this.price,
    required this.per,
    required this.savings,
    required this.highlight,
  });
  final String label;
  final String price;
  final String per;
  final String? savings;
  final bool highlight;
}

const List<_Plan> _kPlans = [
  _Plan(
    label: 'Monthly',
    price: '\$4.99',
    per: '/month',
    savings: null,
    highlight: false,
  ),
  _Plan(
    label: 'Yearly',
    price: '\$39',
    per: '/year',
    savings: 'Save 35%',
    highlight: true,
  ),
  _Plan(
    label: 'Lifetime',
    price: '\$99',
    per: 'once',
    savings: 'Best value',
    highlight: false,
  ),
];

const List<String> _kFeatures = [
  'Unlimited AI Coach reflections + chat',
  'Unlimited habits and routines',
  'Advanced insights and weekly narratives',
  'Multi-device sync (when shipped)',
  'Early access to new features',
  'Priority support',
];

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
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 560,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Hero().animate().fadeIn(duration: 500.ms),
                const SizedBox(height: 28),
                _FeatureList(),
                const SizedBox(height: 28),
                Text(
                  'CHOOSE YOUR PLAN',
                  style: TextStyle(
                    color: BrandColors.inkDim(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 12),
                for (final p in _kPlans) ...[
                  _PlanRow(plan: p),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 18),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: BrandColors.bgCard(context).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppColors.purple.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      'Billing launches soon · join the waitlist',
                      style: TextStyle(
                        color: BrandColors.inkSoft(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: TextButton.icon(
                    onPressed: () => _joinWaitlist(context),
                    icon: Icon(Icons.email_outlined,
                        color: AppColors.purpleLight, size: 16),
                    label: Text(
                      'Email me when it launches',
                      style: TextStyle(
                        color: AppColors.purpleLight,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _joinWaitlist(BuildContext context) async {
    HapticService().light();
    SfxService().fire(SfxType.checkInSuccess);
    await Clipboard.setData(
      const ClipboardData(text: 'hello@mood8.app'),
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Email copied: hello@mood8.app — send "premium" in the subject.',
        ),
        backgroundColor: BrandColors.bgCard(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.buttonGradient,
            boxShadow: [
              BoxShadow(
                color: AppColors.pink.withValues(alpha: 0.45),
                blurRadius: 22,
              ),
            ],
          ),
          child: const Icon(
            Icons.workspace_premium_rounded,
            color: Colors.white,
            size: 36,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Mood8 Premium',
          style: GoogleFonts.instrumentSerif(
            color: BrandColors.ink(context),
            fontStyle: FontStyle.italic,
            fontSize: 36,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Everything that compounds.',
          style: TextStyle(
            color: BrandColors.inkDim(context),
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _FeatureList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.20),
        ),
      ),
      child: Column(
        children: [
          for (var i = 0; i < _kFeatures.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_rounded,
                    color: AppColors.pinkLight, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _kFeatures[i],
                    style: TextStyle(
                      color: BrandColors.ink(context),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
            if (i < _kFeatures.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.plan});
  final _Plan plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: plan.highlight
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.purple.withValues(alpha: 0.30),
                  AppColors.pink.withValues(alpha: 0.18),
                ],
              )
            : null,
        color: plan.highlight ? null : BrandColors.bgCard(context).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: plan.highlight
              ? AppColors.pinkLight.withValues(alpha: 0.55)
              : AppColors.purple.withValues(alpha: 0.20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.label.toUpperCase(),
                  style: TextStyle(
                    color: plan.highlight
                        ? AppColors.pinkLight
                        : BrandColors.inkDim(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: plan.price,
                        style: GoogleFonts.instrumentSerif(
                          color: BrandColors.ink(context),
                          fontStyle: FontStyle.italic,
                          fontSize: 26,
                          height: 1.0,
                        ),
                      ),
                      TextSpan(
                        text: ' ${plan.per}',
                        style: TextStyle(
                          color: BrandColors.inkDim(context),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (plan.savings != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: AppColors.buttonGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                plan.savings!.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
