import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth/auth_button.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/auth/code_input.dart';
import '../../widgets/responsive_container.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key, required this.email});
  final String email;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  String _code = '';
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code from your email.');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => _error = "Passwords don't match.");
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await AuthService().resetPassword(
      email: widget.email,
      code: _code,
      newPassword: _password.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (!result.success) {
      HapticService().heavy();
      setState(() => _error = result.message);
      return;
    }
    HapticService().medium();
    Navigator.of(context).popUntil((r) => r.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Password updated. Sign in with your new password.'),
        backgroundColor: BrandColors.bgCard(context),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
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
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Create new password.',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 6),
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      color: BrandColors.inkDim(context),
                      fontSize: 14,
                    ),
                    children: [
                      const TextSpan(text: 'Enter the code we sent to '),
                      TextSpan(
                        text: widget.email,
                        style: TextStyle(
                          color: BrandColors.inkSoft(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                CodeInput(
                  enabled: !_loading,
                  onComplete: (v) => _code = v,
                ),
                const SizedBox(height: 22),
                AuthTextField(
                  label: 'New password',
                  hint: 'At least 8 characters',
                  icon: Icons.lock_outline_rounded,
                  controller: _password,
                  obscure: true,
                  autofillHints: const [AutofillHints.newPassword],
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  label: 'Confirm new password',
                  icon: Icons.lock_outline_rounded,
                  controller: _confirm,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFFF6B81),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                AuthButton(
                  label: 'Reset password',
                  loading: _loading,
                  onTap: _loading ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
