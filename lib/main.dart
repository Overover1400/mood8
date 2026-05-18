import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/user_profile.dart';
import 'screens/main_navigation.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'services/database_service.dart';
import 'services/haptic_service.dart';
import 'services/preferences_service.dart';
import 'services/routine_repository.dart';
import 'services/sfx_service.dart';
import 'services/subscription_service.dart';
import 'services/user_repository.dart';
import 'theme/app_theme.dart';
import 'theme/app_theme_light.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.init();
  if (UserRepository().isOnboardingComplete()) {
    await RoutineRepository().seedDefaultRoutines();
  }
  // Load preferences synchronously so the first frame paints the right theme.
  await PreferencesService.instance.load();
  await SubscriptionService().load();
  // Fire-and-forget so a slow audio load doesn't block first paint.
  // Both services degrade silently when assets or capabilities are missing.
  HapticService().initialize();
  SfxService().initialize();
  runApp(const Mood8App());
}

class Mood8App extends StatelessWidget {
  const Mood8App({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: PreferencesService.instance.themeModeNotifier,
      builder: (context, themeMode, _) {
        return MaterialApp(
          title: 'Mood8',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: AppLightTheme.theme,
          darkTheme: AppTheme.dark,
          home: const _Root(),
        );
      },
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Box<UserProfile>>(
      valueListenable: UserRepository().watchUser(),
      builder: (context, box, _) {
        final user = box.get(UserRepository.userKey);
        if (user?.hasCompletedOnboarding ?? false) {
          return const MainNavigation();
        }
        return const OnboardingFlow();
      },
    );
  }
}
