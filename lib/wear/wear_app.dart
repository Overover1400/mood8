import 'package:flutter/material.dart';

import '../models/auth_user.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import 'screens/wear_home.dart';
import 'screens/wear_sign_in.dart';

class WearApp extends StatelessWidget {
  const WearApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mood8 Wear',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const _WearAuthGate(),
    );
  }
}

/// Wear-side AuthGate. Mirrors the phone/web AuthGate but stripped to
/// the watch essentials — if the user is signed in, show home; if
/// not, show the wear sign-in screen. On first sign-in (no local
/// data yet) we pull the user's data so the streak / today's mood
/// reflect what they recorded on phone/web.
class _WearAuthGate extends StatefulWidget {
  const _WearAuthGate();
  @override
  State<_WearAuthGate> createState() => _WearAuthGateState();
}

class _WearAuthGateState extends State<_WearAuthGate> {
  String? _lastUserId;
  bool _hydrating = false;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AuthUser?>(
      valueListenable: AuthService().currentUserNotifier,
      builder: (context, user, _) {
        if (user == null) {
          _lastUserId = null;
          return const WearSignInScreen();
        }
        if (user.id != _lastUserId) {
          final isFirstSignIn = _lastUserId == null;
          _lastUserId = user.id;
          if (isFirstSignIn) {
            _hydrating = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _hydrate();
            });
          }
        }
        if (_hydrating) return const _WearHydratingScreen();
        return const WearHomeScreen();
      },
    );
  }

  Future<void> _hydrate() async {
    try {
      await SyncService().fullRestore();
      SyncService().startPeriodicSync();
    } catch (_) {
      // Best-effort — the watch falls back to whatever's already in
      // Hive (empty on a fresh sign-in). The next periodic tick will
      // try again.
    } finally {
      if (mounted) setState(() => _hydrating = false);
    }
  }
}

class _WearHydratingScreen extends StatelessWidget {
  const _WearHydratingScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BrandColors.bgDeep(context),
      body: const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            valueColor: AlwaysStoppedAnimation(Color(0xFFF472B6)),
          ),
        ),
      ),
    );
  }
}
