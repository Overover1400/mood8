import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_service.dart';

/// Wraps the platform `GoogleSignIn` flow and posts the resulting ID
/// token to our backend.
///
/// Why `serverClientId` is the Web Client ID:
/// `google_sign_in` authenticates with the platform-native OAuth
/// client (Android client matched by SHA-1 + package, iOS client by
/// bundle id). To get back an **ID token** the backend can verify,
/// you have to ask for it to be issued for ANOTHER client — the Web
/// one. That's what `serverClientId` does. The token's `aud` claim
/// then equals the Web Client ID, which is what our
/// `_verify_google_id_token` checks against.
///
/// The Web Client ID is treated as a public identifier (it's in the
/// app binary and in the `aud` claim) — the Web SECRET is server-side
/// only and never reaches the client. We never ship the secret.
class GoogleSignInService {
  GoogleSignInService._();
  static final GoogleSignInService _instance = GoogleSignInService._();
  factory GoogleSignInService() => _instance;

  /// Web OAuth Client ID (Mood8 project). Public identifier.
  /// Cross-platform: this same id is used as `serverClientId` on
  /// both Android and iOS so the ID token always has the same
  /// audience claim regardless of which device the user signed in
  /// from.
  static const String webClientId =
      '322539199748-bonlhpebtrlsl01m3gs7s4n2d19en16v.apps.googleusercontent.com';

  final GoogleSignIn _gs = GoogleSignIn(
    // `email` minimum so we can match an existing Mood8 user, and
    // `profile` for the user's display name on first sign-in.
    scopes: const ['email', 'profile'],
    serverClientId: webClientId,
  );

  /// Runs the platform Google flow and posts the resulting ID token
  /// to `/api/auth/google`. Returns the same [AuthResult] surface as
  /// `AuthService.login` so callers can show errors / route through
  /// AuthGate identically.
  ///
  /// On the user pressing the OS-level "back/cancel" the Google
  /// plugin returns `null` from `signIn()`; we surface that as a
  /// failed result with a friendly message rather than letting it
  /// look like a server error.
  Future<AuthResult> signIn() async {
    try {
      // signOut() first so the user gets the account chooser even if
      // they're already signed into a Google account in the device.
      // Without this, repeated sign-ins silently reuse the last
      // account and the user can't switch — annoying when they're
      // troubleshooting which Google account is bound to which Mood8
      // user.
      await _gs.signOut();
    } catch (_) {/* non-fatal */}

    GoogleSignInAccount? account;
    try {
      account = await _gs.signIn();
    } catch (e) {
      debugPrint('[GoogleSignIn] signIn() threw: $e');
      return AuthResult.fail(
          "Couldn't reach Google. Check your connection and try again.");
    }
    if (account == null) {
      // User dismissed the chooser.
      return AuthResult.fail('Sign-in cancelled.');
    }

    GoogleSignInAuthentication auth;
    try {
      auth = await account.authentication;
    } catch (e) {
      debugPrint('[GoogleSignIn] authentication threw: $e');
      return AuthResult.fail(
          "Google returned an unexpected response. Try again.");
    }
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      // This means `serverClientId` wasn't accepted by Google for the
      // current package/SHA — usually a Google Cloud Console
      // configuration drift.
      debugPrint('[GoogleSignIn] idToken null — '
          'check serverClientId + Android/iOS client setup');
      return AuthResult.fail(
          "Google didn't issue an ID token. Contact support — "
          "your Google account may need to be re-linked.");
    }

    return AuthService().signInWithGoogleIdToken(idToken);
  }

  /// Sign out of Google AND clear the local AuthService state.
  /// Caller is responsible for calling AuthGate-side cleanup
  /// (Hive wipe, subscription clear, etc.) — this just disconnects
  /// the Google session.
  Future<void> signOutFromGoogle() async {
    try {
      await _gs.signOut();
    } catch (e) {
      debugPrint('[GoogleSignIn] signOut: $e');
    }
  }
}
