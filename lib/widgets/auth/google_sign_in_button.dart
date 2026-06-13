import 'package:flutter/material.dart';

import '../../services/google_sign_in_service.dart';
import '../../services/haptic_service.dart';
import '../../theme/app_theme.dart';

/// "Continue with Google" button.
///
/// Visual: white background, Google "G" mark, dark text — close to
/// Google's brand guidelines for sign-in buttons. The component owns
/// the in-flight spinner so callers don't have to thread their own
/// `loading` state through; on completion it fires
/// `onResultMessage(...)` with whatever the backend returned so the
/// parent can surface an error inline (or do nothing on success
/// because AuthGate routes the user away).
class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({
    super.key,
    required this.onResultMessage,
    this.label = 'Continue with Google',
  });

  /// Called with a friendly error message on failure (cancellation,
  /// network, server rejection). NOT called on success — on success
  /// AuthService.currentUserNotifier flips and AuthGate routes the
  /// user to MainNavigation, so the source widget is unmounted.
  final ValueChanged<String> onResultMessage;
  final String label;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _busy = false;

  Future<void> _onTap() async {
    if (_busy) return;
    HapticService().light();
    setState(() => _busy = true);
    try {
      final r = await GoogleSignInService().signIn();
      if (!mounted) return;
      if (!r.success) {
        widget.onResultMessage(r.message);
      }
      // r.success → AuthGate handles the route change; nothing else
      // for us to do.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        elevation: 0,
        child: InkWell(
          onTap: _busy ? null : _onTap,
          borderRadius: BorderRadius.circular(28),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppColors.purple.withValues(alpha: 0.18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                if (_busy)
                  const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      valueColor:
                          AlwaysStoppedAnimation(Color(0xFF4285F4)),
                    ),
                  )
                else
                  const _GoogleGlyph(),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _busy ? 'Signing in…' : widget.label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF202124),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                // Spacer so the text is visually centered around the
                // baseline ignoring the leading glyph.
                const SizedBox(width: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pixel-accurate "G" mark — the four Google brand colours, drawn via
/// CustomPaint so we don't ship a PNG asset just for the auth screen.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GoogleGlyphPainter()),
    );
  }
}

class _GoogleGlyphPainter extends CustomPainter {
  const _GoogleGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Approximation of the Google "G" — outer arc in four brand
    // colours + the inner crossbar. Close enough for a 22-px button
    // glyph; users recognise the colour split instantly.
    final cx = size.width / 2;
    final cy = size.height / 2;
    final radius = size.width / 2 - 0.5;
    final innerRadius = radius * 0.55;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);
    final innerRect =
        Rect.fromCircle(center: Offset(cx, cy), radius: innerRadius);

    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius - innerRadius
      ..strokeCap = StrokeCap.butt;

    // Top arc (blue) — 12 o'clock → 3 o'clock.
    canvas.drawArc(
      rect.deflate(stroke.strokeWidth / 2),
      -1.5708, // -π/2
      1.5708, // π/2
      false,
      stroke..color = const Color(0xFF4285F4),
    );
    // Right arc (red) — top going down to crossbar.
    canvas.drawArc(
      rect.deflate(stroke.strokeWidth / 2),
      -3.1416 + 0.0, // π
      1.5708,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = const Color(0xFFEA4335),
    );
    // Bottom-left (yellow).
    canvas.drawArc(
      rect.deflate(stroke.strokeWidth / 2),
      -3.1416 + 1.5708,
      1.5708,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = const Color(0xFFFBBC05),
    );
    // Bottom-right (green) → meets the crossbar.
    canvas.drawArc(
      rect.deflate(stroke.strokeWidth / 2),
      0.0,
      1.5708,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke.strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = const Color(0xFF34A853),
    );

    // Crossbar — horizontal blue line going inward from the right
    // edge. Mimics the "G" notch.
    final bar = Paint()
      ..color = const Color(0xFF4285F4)
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(rect.right - stroke.strokeWidth / 2, cy),
      bar,
    );
    // Cap the inner hole with a tiny white circle so the painting
    // reads as a "G" not a wheel.
    canvas.drawCircle(
      Offset(cx, cy),
      innerRect.width / 2 - 0.5,
      Paint()..color = Colors.white,
    );
    // Re-draw a short blue stub for the notch (so it survives the
    // white cover).
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + innerRect.width / 2 - 0.5, cy),
      Paint()
        ..color = const Color(0xFF4285F4)
        ..strokeWidth = stroke.strokeWidth * 0.4
        ..strokeCap = StrokeCap.butt,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
