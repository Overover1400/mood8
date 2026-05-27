import 'package:flutter/material.dart';

import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/subscription_service.dart';
import 'services/sync_service.dart';
import 'wear/wear_app.dart';

/// Wear OS entrypoint. Initializes the exact same Hive + auth + sync
/// stack the phone/web app uses so a check-in from the watch lands
/// in the same `mood_entries` Hive box, gets the same `updatedAt`
/// stamp, and rides the same /api/sync/push path back up to the
/// server — the phone then pulls it on its next sync tick.
///
/// Wear OS apps are standalone installs (not a companion process of
/// the phone APK), so we can't share SharedPreferences/Hive across
/// devices. The watch needs its own sign-in. That's wired through
/// [WearApp] → WearSignInScreen when no token is present.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.init();
  await SubscriptionService().load();
  await AuthService().initialize();
  await SyncService.warmUp();
  // If a token survived the last session, fire a background pull so
  // the watch boots with the latest server state. Periodic sync runs
  // every 2 minutes (same cadence as phone) so a check-in from one
  // device shows up on the other within that window.
  if (AuthService().token != null) {
    // ignore: discarded_futures
    SubscriptionService().refreshStatus();
    // ignore: discarded_futures
    SyncService().pullChanges();
    SyncService().startPeriodicSync();
  }
  runApp(const WearApp());
}
