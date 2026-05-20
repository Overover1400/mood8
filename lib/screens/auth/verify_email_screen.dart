import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/auth_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth/auth_button.dart';
import '../../widgets/auth/code_input.dart';
import '../../widgets/mood_orb.dart';
import '../../widgets/responsive_container.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key, required this.email});
  final String email;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final GlobalKey<CodeInputState> _codeKey = GlobalKey<CodeInputState>();
  bool _loading = false;
  bool _resending = false;
  String? _error;
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void initState() {
    super.initState();
    _startResendCooldown();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendIn = 60;
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        if (_resendIn <= 0) {
          t.cancel();
          return;
        }
        _resendIn -= 1;
      });
    });
  }

  Future<void> _onCode(String code) async {
    if (_loading) return;
    debugPrint('[VerifyScreen] verifying ${widget.email} · code=$code');
    setState(() {
      _loading = true;
      _error = null;
    });
    final result =
        await AuthService().verify(email: widget.email, code: code);
    if (!mounted) return;
    if (!result.success) {
      debugPrint('[VerifyScreen] ❌ verify failed: ${result.message}');
      HapticService().heavy();
      setState(() {
        _loading = false;
        _error = result.message;
      });
      _codeKey.currentState?.clear();
      return;
    }
    debugPrint(
        '[VerifyScreen] ✅ verified ${result.user?.email}. Popping back to AuthGate.');
    HapticService().medium();
    // AuthGate (root route) has already rebuilt because
    // AuthService.currentUserNotifier was updated. Pop everything above it
    // so the new MainNavigation / OnboardingFlow becomes visible.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _resend() async {
    if (_resending || _resendIn > 0) return;
    setState(() => _resending = true);
    final result = await AuthService().register(
      email: widget.email,
      password: '__resend__',
      name: '',
    );
    if (!mounted) return;
    setState(() {
      _resending = false;
      if (result.success) {
        _error = null;
        _startResendCooldown();
      } else {
        _error = result.message;
      }
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
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 460,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: Column(
              children: [
                const SizedBox(height: 8),
                const MoodOrb(size: 110)
                    .animate()
                    .fadeIn(duration: 500.ms),
                const SizedBox(height: 22),
                Text(
                  'Check your email.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      color: BrandColors.inkDim(context),
                      fontSize: 14,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(text: 'We sent a 6-digit code to\n'),
                      TextSpan(
                        text: widget.email,
                        style: TextStyle(
                          color: BrandColors.inkSoft(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                CodeInput(
                  key: _codeKey,
                  enabled: !_loading,
                  onComplete: _onCode,
                ),
                const SizedBox(height: 16),
                if (_loading)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(AppColors.pinkLight),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Verifying…',
                        style: TextStyle(
                          color: BrandColors.inkSoft(context),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFFFF6B81),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const Spacer(),
                AuthButton(
                  label: _resendIn > 0
                      ? 'Resend in ${_resendIn}s'
                      : (_resending ? 'Sending…' : 'Resend code'),
                  outlined: true,
                  onTap: _resendIn > 0 || _resending ? null : _resend,
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(
                    'Wrong email? Go back',
                    style: TextStyle(
                      color: AppColors.purpleLight,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
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
}
