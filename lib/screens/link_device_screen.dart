import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/device_link_service.dart';
import '../services/haptic_service.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_container.dart';

/// Settings → Devices → Connect your watch.
///
/// The user's Wear OS watch shows a 6-char pairing code; they type it here
/// while signed in (via any method — password or Google) and we approve it,
/// which lets the watch pull a JWT for this account. Free path, no billing.
class LinkDeviceScreen extends StatefulWidget {
  const LinkDeviceScreen({super.key});

  @override
  State<LinkDeviceScreen> createState() => _LinkDeviceScreenState();
}

class _LinkDeviceScreenState extends State<LinkDeviceScreen> {
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

  Future<void> _submit() async {
    if (_busy) return;
    final code = _controller.text.trim();
    if (code.isEmpty) {
      setState(() {
        _ok = false;
        _message = 'Enter the code shown on your watch.';
      });
      return;
    }
    FocusScope.of(context).unfocus();
    HapticService().light();
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await DeviceLinkService().approveCode(code);
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
        title: Text('Connect your watch',
            style: Theme.of(context).textTheme.headlineSmall),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          maxWidth: 520,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.softGradient,
                    border: Border.all(
                      color: AppColors.purple.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Icon(Icons.watch_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(height: 16),
                Text(
                  'Link your Wear OS watch',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.bricolageGrotesque(
                    color: BrandColors.ink(context),
                    fontSize: 24,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Open Mood8 on your watch, then type the 6-character '
                  'code it shows here. Your watch will sign in to this '
                  'account — no password needed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: BrandColors.inkSoft(context),
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _controller,
                  focusNode: _focus,
                  enabled: !_busy,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  textInputAction: TextInputAction.done,
                  maxLength: 6,
                  onSubmitted: (_) => _submit(),
                  inputFormatters: [
                    UpperCaseTextFormatter(),
                    FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                  ],
                  style: GoogleFonts.bricolageGrotesque(
                    color: BrandColors.ink(context),
                    fontSize: 30,
                    letterSpacing: 8,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'ABC123',
                    hintStyle: TextStyle(
                      color: BrandColors.inkFaint(context),
                      letterSpacing: 8,
                      fontSize: 26,
                    ),
                    filled: true,
                    fillColor:
                        BrandColors.bgCard(context).withValues(alpha: 0.6),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppColors.purple.withValues(alpha: 0.3),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: AppColors.pinkLight.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _busy ? null : _submit,
                  child: Container(
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: AppColors.buttonGradient,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.pink.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'Link watch',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _ok
                            ? Icons.check_circle_rounded
                            : Icons.error_outline_rounded,
                        color:
                            _ok ? const Color(0xFF34D399) : AppColors.pinkLight,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _message!,
                          style: TextStyle(
                            color: _ok
                                ? const Color(0xFF34D399)
                                : BrandColors.inkSoft(context),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Forces typed characters to uppercase so the code field always matches
/// the server's uppercase codes as the user types.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
