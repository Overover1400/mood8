import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth/auth_button.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/responsive_container.dart';
import 'sign_in_screen.dart';
import 'verify_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _agreed = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _password.addListener(_rebuild);
    _confirm.addListener(_rebuild);
    _email.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  int get _strength {
    final p = _password.text;
    if (p.length < 6) return 0;
    var score = 0;
    if (p.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(p)) score++;
    if (RegExp(r'[0-9]').hasMatch(p)) score++;
    if (RegExp(r'[!@#\$%^&*()_\-+=,.?]').hasMatch(p)) score++;
    return score.clamp(0, 4);
  }

  bool get _canSubmit {
    if (!_agreed) return false;
    if (!EmailValidator.validate(_email.text.trim())) return false;
    if (_password.text.length < 8) return false;
    if (_password.text != _confirm.text) return false;
    return true;
  }

  Future<void> _submit() async {
    if (!_canSubmit || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await AuthService().register(
      email: _email.text.trim(),
      password: _password.text,
      name: _name.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (!result.success) {
      HapticService().heavy();
      setState(() => _error = result.message);
      return;
    }
    HapticService().medium();
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => VerifyEmailScreen(email: _email.text.trim()),
    ));
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
                  'Create your account.',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 6),
                Text(
                  '60 seconds. We never sell your data.',
                  style: TextStyle(
                    color: BrandColors.inkDim(context),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 28),
                AuthTextField(
                  label: 'Name',
                  hint: 'What should we call you?',
                  icon: Icons.person_outline_rounded,
                  controller: _name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.givenName],
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  label: 'Email',
                  hint: 'you@example.com',
                  icon: Icons.alternate_email_rounded,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.newUsername, AutofillHints.email],
                ),
                const SizedBox(height: 14),
                AuthTextField(
                  label: 'Password',
                  hint: 'At least 8 characters',
                  icon: Icons.lock_outline_rounded,
                  controller: _password,
                  obscure: true,
                  autofillHints: const [AutofillHints.newPassword],
                ),
                const SizedBox(height: 8),
                _StrengthBar(score: _strength),
                const SizedBox(height: 14),
                AuthTextField(
                  label: 'Confirm password',
                  hint: 'Type it again',
                  icon: Icons.lock_outline_rounded,
                  controller: _confirm,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  errorText: _confirm.text.isNotEmpty &&
                          _confirm.text != _password.text
                      ? "Passwords don't match"
                      : null,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Checkbox(
                      value: _agreed,
                      onChanged: (v) => setState(() => _agreed = v ?? false),
                      checkColor: Colors.white,
                      activeColor: AppColors.pink,
                      side: BorderSide(
                        color: AppColors.purple.withValues(alpha: 0.5),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _agreed = !_agreed),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text.rich(
                            TextSpan(
                              style: TextStyle(
                                color: BrandColors.inkSoft(context),
                                fontSize: 12,
                                height: 1.5,
                              ),
                              children: [
                                const TextSpan(text: 'I agree to the '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: TextStyle(
                                    color: AppColors.pinkLight,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Terms',
                                  style: TextStyle(
                                    color: AppColors.pinkLight,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const TextSpan(text: '.'),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Color(0xFFFF6B81),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                AuthButton(
                  label: 'Create account',
                  loading: _loading,
                  onTap: _canSubmit && !_loading ? _submit : null,
                ),
                const SizedBox(height: 14),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const SignInScreen(),
                      ),
                    ),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'Already have an account? ',
                            style: TextStyle(
                              color: BrandColors.inkDim(context),
                              fontSize: 13,
                            ),
                          ),
                          TextSpan(
                            text: 'Sign in',
                            style: TextStyle(
                              color: AppColors.pinkLight,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
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
}

class _StrengthBar extends StatelessWidget {
  const _StrengthBar({required this.score});
  final int score;

  String get _label {
    switch (score) {
      case 0:
        return 'Too short';
      case 1:
        return 'Weak';
      case 2:
        return 'Okay';
      case 3:
        return 'Strong';
      default:
        return 'Very strong';
    }
  }

  Color get _color {
    if (score <= 1) return const Color(0xFFFF6B81);
    if (score == 2) return AppColors.purple;
    if (score == 3) return AppColors.pink;
    return AppColors.pinkLight;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: 4,
              decoration: BoxDecoration(
                color: i < score
                    ? _color
                    : BrandColors.bg(context).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          if (i < 3) const SizedBox(width: 4),
        ],
        const SizedBox(width: 10),
        SizedBox(
          width: 80,
          child: Text(
            _label,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: _color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
        ),
      ],
    );
  }
}
