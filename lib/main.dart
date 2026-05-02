import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

void main() {
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
      home: const HomeScreen(),
    );
  }
}
