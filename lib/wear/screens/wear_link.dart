import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/auth_service.dart';
import '../../services/device_link_service.dart';
import '../../theme/app_theme.dart';

/// Wear OS device-linking screen. Replaces the old email/password sign-in.
///
/// The watch requests a short pairing code, shows it with a countdown, and
/// polls the server every ~3s. When the user enters the code in the
/// signed-in phone/web app, the poll returns a JWT — we establish the
/// session from it and the WearAuthGate routes into the app. This is a
/// one-time setup; the token persists across launches.
class WearLinkScreen extends StatefulWidget {
  const WearLinkScreen({super.key});

  @override
  State<WearLinkScreen> createState() => _WearLinkScreenState();
}

enum _Phase { loading, active, expired, error }

class _WearLinkScreenState extends State<WearLinkScreen> {
  final _service = DeviceLinkService();

  _Phase _phase = _Phase.loading;
  String? _code;
  String? _pollToken;
  DateTime? _expiresAt;
  Timer? _pollTimer;
  Timer? _tick;
  bool _redeeming = false;

  @override
  void initState() {
    super.initState();
    _requestCode();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  void _stopTimers() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _tick?.cancel();
    _tick = null;
  }

  Future<void> _requestCode() async {
    _stopTimers();
    setState(() => _phase = _Phase.loading);
    final req = await _service.requestCode();
    if (!mounted) return;
    if (req == null) {
      setState(() => _phase = _Phase.error);
      return;
    }
    setState(() {
      _code = req.code;
      _pollToken = req.pollToken;
      _expiresAt = req.expiresAt;
      _phase = _Phase.active;
    });
    // Poll status every 3s, and tick the countdown every 1s.
    _pollTimer =
        Timer.periodic(const Duration(seconds: 3), (_) => _poll());
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft() <= 0) {
        _stopTimers();
        setState(() => _phase = _Phase.expired);
      } else {
        setState(() {}); // refresh the countdown label
      }
    });
  }

  Future<void> _poll() async {
    final pt = _pollToken;
    if (pt == null || _redeeming) return;
    final status = await _service.pollStatus(pt);
    if (!mounted) return;
    switch (status.state) {
      case DeviceLinkState.approved:
        final token = status.token;
        if (token == null || token.isEmpty) return;
        _redeeming = true;
        _stopTimers();
        HapticFeedback.mediumImpact();
        final r = await AuthService().establishSessionFromToken(token);
        if (!mounted) return;
        if (!r.success) {
          // Token was rejected — start over with a fresh code.
          _redeeming = false;
          setState(() => _phase = _Phase.expired);
        }
        // On success the WearAuthGate's listener swaps this screen for
        // the home screen — nothing else to do here.
        break;
      case DeviceLinkState.expired:
        _stopTimers();
        setState(() => _phase = _Phase.expired);
        break;
      case DeviceLinkState.pending:
        break;
    }
  }

  int _secondsLeft() {
    final exp = _expiresAt;
    if (exp == null) return 0;
    return exp.difference(DateTime.now()).inSeconds;
  }

  String _countdownLabel() {
    final s = _secondsLeft().clamp(0, 3599);
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: _buildBody(context),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    switch (_phase) {
      case _Phase.loading:
        return const _WearSpinner();
      case _Phase.error:
        return _WearMessage(
          title: "Couldn't get a code",
          subtitle: 'Check the connection.',
          buttonLabel: 'Retry',
          onButton: _requestCode,
        );
      case _Phase.expired:
        return _WearMessage(
          title: 'Code expired',
          subtitle: 'Grab a fresh one.',
          buttonLabel: 'Get a new code',
          onButton: _requestCode,
        );
      case _Phase.active:
        return _buildActive(context);
    }
  }

  Widget _buildActive(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Enter this code on',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: BrandColors.inkSoft(context),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          'mood8.app',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.pinkLight,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 8),
        // The code itself — large, spaced, easy to read + copy onto a phone.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            gradient: AppColors.softGradient,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.purple.withValues(alpha: 0.35),
            ),
          ),
          child: Text(
            _spaced(_code ?? ''),
            style: GoogleFonts.bricolageGrotesque(
              color: BrandColors.ink(context),
              fontSize: 26,
              height: 1.0,
              letterSpacing: 2.0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined,
                size: 11, color: BrandColors.inkDim(context)),
            const SizedBox(width: 4),
            Text(
              'Expires in ${_countdownLabel()}',
              style: TextStyle(
                color: BrandColors.inkDim(context),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Insert a thin space between characters so the code reads clearly on
  /// a small screen (e.g. "3ZRAA6" → "3 Z R A A 6").
  String _spaced(String code) => code.split('').join(' ');
}

class _WearSpinner extends StatelessWidget {
  const _WearSpinner();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 26,
      height: 26,
      child: CircularProgressIndicator(
        strokeWidth: 2.4,
        valueColor: AlwaysStoppedAnimation(Color(0xFFF472B6)),
      ),
    );
  }
}

class _WearMessage extends StatelessWidget {
  const _WearMessage({
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onButton,
  });
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onButton;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.bricolageGrotesque(
            color: BrandColors.ink(context),
            fontSize: 15,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: BrandColors.inkDim(context),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: onButton,
          child: Container(
            height: 34,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            decoration: BoxDecoration(
              gradient: AppColors.buttonGradient,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              buttonLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
