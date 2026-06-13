import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/services.dart' show PlatformException;
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

  /// Web vs mobile platform split. On web, `google_sign_in_web` reads
  /// the client id from the `<meta name="google-signin-client_id">`
  /// in index.html and must be constructed with `clientId:` instead
  /// of `serverClientId:` — passing both, or the wrong one, is what
  /// previously surfaced as a generic "couldn't reach Google" error
  /// on the web build. On Android/iOS, `serverClientId:` is what
  /// makes Google return an ID token issued FOR the web client (the
  /// audience the backend verifies against).
  final GoogleSignIn _gs = kIsWeb
      ? GoogleSignIn(
          clientId: webClientId,
          scopes: const ['email', 'profile'],
        )
      : GoogleSignIn(
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
    } on PlatformException catch (e, st) {
      debugPrint('[GoogleSignIn] PlatformException code=${e.code} '
          'message=${e.message} details=${e.details}\n$st');
      // ApiException code 10 = DEVELOPER_ERROR — usually package +
      // SHA-1 don't match Google Cloud Console's Android OAuth
      // client. Code 12500 = SIGN_IN_FAILED on Android (rare,
      // network/cache). Code 7 = NETWORK_ERROR.
      final friendly = _friendlyMessageFor(e);
      return AuthResult.fail(friendly);
    } catch (e, st) {
      debugPrint('[GoogleSignIn] signIn() unexpected: $e\n$st');
      return AuthResult.fail("Google sign-in failed: $e");
    }
    if (account == null) {
      return AuthResult.fail('Sign-in cancelled.');
    }

    GoogleSignInAuthentication auth;
    try {
      auth = await account.authentication;
    } on PlatformException catch (e, st) {
      debugPrint(
          '[GoogleSignIn] authentication PlatformException code=${e.code} '
          'message=${e.message}\n$st');
      return AuthResult.fail(_friendlyMessageFor(e));
    } catch (e, st) {
      debugPrint('[GoogleSignIn] authentication unexpected: $e\n$st');
      return AuthResult.fail('Google returned an unexpected response: $e');
    }
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      // Most common root cause: the Web Client ID configured as
      // `serverClientId` doesn't match what Google's Android OAuth
      // client is configured to issue tokens for. Verify in Google
      // Cloud Console:
      //   • Android client package_name == com.mood8.app
      //   • Android client SHA-1 == the release keystore SHA-1
      //   • Web client (322539199748-bonlhpe…) authorized JavaScript
      //     origins include https://mood8.app
      debugPrint('[GoogleSignIn] idToken null — accessToken='
          '${auth.accessToken == null ? 'null' : 'present'} · '
          'serverAuthCode=${auth.idToken == null ? 'null' : 'present'}');
      return AuthResult.fail(
          "Google didn't return an ID token (DEVELOPER_ERROR / package "
          "or SHA mismatch in Cloud Console).");
    }

    return AuthService().signInWithGoogleIdToken(idToken);
  }

  /// Maps PlatformException codes to friendly UI text. Codes from
  /// google_sign_in's Android channel + GIS web errors.
  String _friendlyMessageFor(PlatformException e) {
    switch (e.code) {
      case 'sign_in_canceled':
      case 'sign_in_cancelled':
        return 'Sign-in cancelled.';
      case 'sign_in_required':
        return 'Sign in to a Google account on this device first.';
      case 'network_error':
      case '7':
        return "Couldn't reach Google — check your connection.";
      case 'sign_in_failed':
      case '10':
        // DEVELOPER_ERROR on Android — package name / SHA-1 mismatch
        // in Google Cloud Console, or the Android OAuth client
        // doesn't exist at all.
        return 'Google rejected the app (DEVELOPER_ERROR ${e.code}). '
            'Check the Android OAuth client package + SHA-1.';
      case '12500':
        return 'Google sign-in failed (12500). Make sure Google Play '
            "services is up to date on this device.";
      case '12501':
        return 'Sign-in cancelled.';
      default:
        return 'Google sign-in failed (${e.code}): ${e.message}';
    }
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
