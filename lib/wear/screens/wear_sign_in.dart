import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

/// Minimal Wear OS sign-in. The watch is a standalone install (no
/// shared storage with the phone), so the user has to authenticate
/// here once. After login the wear app pulls the user's data via
/// SyncService.fullRestore (driven by the wear AuthGate) and every
/// subsequent check-in syncs back to the same account, visible on
/// phone + web within ~2 minutes.
class WearSignInScreen extends StatefulWidget {
  const WearSignInScreen({super.key});

  @override
  State<WearSignInScreen> createState() => _WearSignInScreenState();
}

class _WearSignInScreenState extends State<WearSignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final email = _email.text.trim();
    final pw = _password.text;
    if (email.isEmpty || pw.length < 6) {
      setState(() => _error = 'Email + password (6+ chars).');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await AuthService().login(email: email, password: pw);
    if (!mounted) return;
    if (!r.success) {
      HapticFeedback.heavyImpact();
      setState(() {
        _busy = false;
        _error = r.message;
      });
      return;
    }
    HapticFeedback.mediumImpact();
    // No pop — the WearAuthGate's ValueListenableBuilder will rebuild
    // with the new user and route to the home screen automatically.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),
              Text(
                'Sign in',
                style: GoogleFonts.bricolageGrotesque(
                  color: BrandColors.ink(context),
                  fontSize: 18,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'to sync with your phone',
                style: TextStyle(
                  color: BrandColors.inkDim(context),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              _WearField(
                controller: _email,
                hint: 'Email',
                keyboard: TextInputType.emailAddress,
              ),
              const SizedBox(height: 6),
              _WearField(
                controller: _password,
                hint: 'Password',
                obscure: true,
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFFF6B81),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _busy ? null : _submit,
                child: Container(
                  height: 38,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    gradient: AppColors.buttonGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: _busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'Sign in',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
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
    );
  }
}

class _WearField extends StatelessWidget {
  const _WearField({
    required this.controller,
    required this.hint,
    this.keyboard,
    this.obscure = false,
  });
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboard;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.25),
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        obscureText: obscure,
        style: TextStyle(
          color: BrandColors.ink(context),
          fontSize: 12,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: BrandColors.inkDim(context),
            fontSize: 11,
          ),
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
