import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'screens/wear_home.dart';

class WearApp extends StatelessWidget {
  const WearApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mood8 Wear',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const WearHomeScreen(),
    );
  }
}
