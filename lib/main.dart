import 'package:flutter/material.dart';

import 'screens/main_navigation.dart';
import 'services/database_service.dart';
import 'services/routine_repository.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.init();
  await RoutineRepository().seedDefaultRoutines();
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
      home: const MainNavigation(),
    );
  }
}
