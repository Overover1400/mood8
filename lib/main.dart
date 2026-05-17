import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/user_profile.dart';
import 'screens/main_navigation.dart';
import 'screens/onboarding/onboarding_flow.dart';
import 'services/database_service.dart';
import 'services/routine_repository.dart';
import 'services/user_repository.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.init();
  if (UserRepository().isOnboardingComplete()) {
    await RoutineRepository().seedDefaultRoutines();
  }
  runApp(const Mood8App());
}

class Mood8App extends StatelessWidget {
  const Mood8App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mood8',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const _Root(),
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
