import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

import 'subscription_service.dart';

/// The custom-scheme URL Stripe redirects to after checkout. Mirrors
/// the AndroidManifest intent-filter for `<data android:scheme="mood8"/>`.
const String kDeepLinkReturnUrl = 'mood8://checkout-complete';

/// Listens for incoming `mood8://...` deep links and routes them. Used
/// for Stripe checkout returns today; any future deep-link routes can
/// add a branch in [_handle].
///
/// Web (kIsWeb) is a no-op — the `?checkout=success` query parameter
/// is already handled by `_maybeHandleCheckoutReturn` in AuthGate.
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService _instance = DeepLinkService._();
  factory DeepLinkService() => _instance;

  AppLinks? _appLinks;
  StreamSubscription<Uri>? _sub;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (kIsWeb) return;
    try {
      _appLinks = AppLinks();
      // Cold-start link (app launched by the deep link, not yet running).
      final initial = await _appLinks!.getInitialLink();
      if (initial != null) {
        // Defer so the rest of bootstrap completes (notifier listeners
        // need to be attached before we fire the celebration).
        // ignore: discarded_futures
        Future<void>.delayed(const Duration(milliseconds: 600), () {
          _handle(initial);
        });
      }
      _sub = _appLinks!.uriLinkStream.listen(
        _handle,
        onError: (Object e) =>
            debugPrint('[DeepLink] stream error: $e'),
      );
    } catch (e) {
      debugPrint('[DeepLink] initialize failed: $e');
    }
  }

  Future<void> _handle(Uri uri) async {
    debugPrint('[DeepLink] received $uri');
    if (uri.scheme != 'mood8') return;
    if (uri.host == 'checkout-complete' || uri.path.contains('checkout-complete')) {
      // Clear the in-progress flag so the resume hook doesn't double-fire.
      await SubscriptionService().consumeCheckoutInProgress();
      // status=success refresh and announce; status=cancelled just
      // refresh (silently — server state unchanged).
      final justUnlocked = await SubscriptionService().refreshStatus();
      debugPrint(
          '[DeepLink] checkout-complete · status=${uri.queryParameters['status']} '
          'justUnlocked=$justUnlocked');
      // If premium hasn't propagated yet, retry once after a beat — the
      // webhook may still be in flight when the success_url fires.
      if (uri.queryParameters['status'] == 'success' &&
          !justUnlocked &&
          !SubscriptionService().isPremium) {
        await Future<void>.delayed(const Duration(seconds: 3));
        await SubscriptionService().refreshStatus();
      }
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _initialized = false;
  }
}
