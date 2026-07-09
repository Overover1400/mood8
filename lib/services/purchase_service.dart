import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

import 'subscription_service.dart';

/// Outcome of a purchase attempt. `ok=true` with a non-null
/// [checkoutUrl] means the caller should open that URL; `ok=false`
/// carries a friendly [message] the caller can show inline.
class PurchaseResult {
  const PurchaseResult({
    required this.ok,
    this.checkoutUrl,
    this.message,
  });

  const PurchaseResult.success(String url)
      : ok = true,
        checkoutUrl = url,
        message = null;

  const PurchaseResult.failure(this.message)
      : ok = false,
        checkoutUrl = null;

  const PurchaseResult.unavailable(this.message)
      : ok = false,
        checkoutUrl = null;

  final bool ok;
  final String? checkoutUrl;
  final String? message;
}

/// Platform-abstracted purchase gateway. Web routes purchases
/// through Stripe checkout; native mobile currently exposes NO
/// in-app purchase surface (Google Play Billing / StoreKit
/// integration comes later) and instead points the user at
/// mood8.app to manage their subscription from the browser.
///
/// Callers must gate on [supportsInAppPurchase] before showing any
/// checkout affordance. When it returns false the paywall renders
/// [unavailableReason] and offers the [manageInBrowserUrl] as an
/// external link.
abstract class PurchaseService {
  factory PurchaseService() {
    if (kIsWeb) return _WebStripePurchaseService();
    // Every native target (Android / iOS / desktop) currently uses
    // the "managed on mood8.app" placeholder. When Play Billing
    // ships we'll branch on defaultTargetPlatform here to return a
    // dedicated _PlayBillingPurchaseService for Android.
    return _NativeUnavailablePurchaseService();
  }

  /// Whether the current platform supports completing a purchase
  /// inside the app. When false, the paywall must NOT expose any
  /// checkout button — Google Play + Apple both reject apps that
  /// route digital-goods payments through a browser workaround.
  bool get supportsInAppPurchase;

  /// User-facing sentence explaining WHY no in-app purchase is
  /// available on this platform. Empty when
  /// [supportsInAppPurchase] is true.
  String get unavailableReason;

  /// URL the user should visit to manage / start their subscription
  /// when in-app purchase is unavailable. Rendered as an "Open
  /// mood8.app" button on the placeholder card.
  String get manageInBrowserUrl;

  /// Kicks off a purchase for the given plan key ("monthly",
  /// "annual", "lifetime"). On success returns a [PurchaseResult]
  /// with the Stripe-hosted checkout URL for the caller to open.
  /// Returns [PurchaseResult.unavailable] on platforms that don't
  /// support in-app purchase — callers should already have gated
  /// on [supportsInAppPurchase] but this is a safe backstop.
  Future<PurchaseResult> startPurchase(
    String plan, {
    String? returnUrl,
  });
}

class _WebStripePurchaseService implements PurchaseService {
  @override
  bool get supportsInAppPurchase => true;

  @override
  String get unavailableReason => '';

  @override
  String get manageInBrowserUrl => 'https://mood8.app';

  @override
  Future<PurchaseResult> startPurchase(
    String plan, {
    String? returnUrl,
  }) async {
    final url = await SubscriptionService()
        .startCheckout(plan, returnUrl: returnUrl);
    if (url == null || url.isEmpty) {
      return const PurchaseResult.failure(
        "Couldn't open checkout. Check your connection and sign-in.",
      );
    }
    return PurchaseResult.success(url);
  }
}

/// Placeholder impl for native mobile (Android + iOS). Ships with
/// zero purchase surface for launch — the paywall shows benefits +
/// a "managed on mood8.app" card. When Play Billing lands this
/// will be replaced by a real `_PlayBillingPurchaseService` for
/// Android; the abstract interface stays the same so the paywall
/// doesn't have to change.
class _NativeUnavailablePurchaseService implements PurchaseService {
  @override
  bool get supportsInAppPurchase => false;

  @override
  String get unavailableReason =>
      'Premium is managed on mood8.app — sign in there to upgrade.';

  @override
  String get manageInBrowserUrl => 'https://mood8.app';

  @override
  Future<PurchaseResult> startPurchase(
    String plan, {
    String? returnUrl,
  }) async {
    return PurchaseResult.unavailable(unavailableReason);
  }
}

/// Open [PurchaseService.manageInBrowserUrl] in the platform
/// browser. Extracted here so paywall + membership screens share a
/// single implementation.
Future<bool> openManageInBrowser() async {
  final url = PurchaseService().manageInBrowserUrl;
  return launchUrl(
    Uri.parse(url),
    mode: LaunchMode.externalApplication,
  );
}
