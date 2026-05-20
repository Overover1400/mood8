import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../services/auth_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth/auth_button.dart';
import '../../widgets/auth/auth_text_field.dart';
import '../../widgets/responsive_container.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _emailNode = FocusNode();
  final _passwordNode = FocusNode();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _emailNode.dispose();
    _passwordNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (!EmailValidator.validate(email)) {
      setState(() => _error = 'Enter a valid email.');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final result =
        await AuthService().login(email: email, password: password);
    if (!mounted) return;
    if (!result.success) {
      debugPrint('[SignInScreen] ❌ login failed: ${result.message}');
      HapticService().heavy();
      setState(() {
        _loading = false;
        _error = result.message;
      });
      return;
    }
    debugPrint(
        '[SignInScreen] ✅ logged in ${result.user?.email}. Popping back to AuthGate.');
    HapticService().medium();
    // AuthGate has rebuilt (via currentUserNotifier) — pop everything above
    // it so MainNavigation / OnboardingFlow becomes the visible route.
    Navigator.of(context).popUntil((route) => route.isFirst);
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
                  'Welcome back.',
                  style: Theme.of(context).textTheme.headlineLarge,
                )
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: 0.05, end: 0, curve: Curves.easeOut),
                const SizedBox(height: 6),
                Text(
                  'Sign in to keep building.',
                  style: TextStyle(
                    color: BrandColors.inkDim(context),
                    fontSize: 14,
                  ),
                ).animate().fadeIn(delay: 80.ms, duration: 400.ms),
                const SizedBox(height: 28),
                AuthTextField(
                  label: 'Email',
                  hint: 'you@example.com',
                  icon: Icons.alternate_email_rounded,
                  controller: _email,
                  focusNode: _emailNode,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  autofillHints: const [AutofillHints.email],
                  onSubmitted: (_) => _passwordNode.requestFocus(),
                ),
                const SizedBox(height: 16),
                AuthTextField(
                  label: 'Password',
                  hint: '••••••••',
                  icon: Icons.lock_outline_rounded,
                  controller: _password,
                  focusNode: _passwordNode,
                  obscure: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.password],
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ForgotPasswordScreen(),
                      ),
                    ),
                    child: Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: AppColors.purpleLight,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 4),
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
                  label: 'Sign in',
                  loading: _loading,
                  onTap: _loading ? null : _submit,
                ),
                const SizedBox(height: 18),
                Center(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.of(context).pushReplacement(MaterialPageRoute(
                      builder: (_) => const RegisterScreen(),
                    )),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: "Don't have an account? ",
                            style: TextStyle(
                              color: BrandColors.inkDim(context),
                              fontSize: 13,
                            ),
                          ),
                          TextSpan(
                            text: 'Create one',
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
