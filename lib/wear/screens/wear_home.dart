import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_theme.dart';
import '../widgets/round_button.dart';
import '../widgets/wear_orb.dart';
import 'wear_checkin.dart';

class WearHomeScreen extends StatefulWidget {
  const WearHomeScreen({super.key});

  @override
  State<WearHomeScreen> createState() => _WearHomeScreenState();
}

class _WearHomeScreenState extends State<WearHomeScreen> {
  int _streak = 12;
  int _waterCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _streak = prefs.getInt('streak') ?? 12;
      _waterCount = prefs.getInt('water_today') ?? 0;
    });
  }

  Future<void> _quickLog(String key) async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('${key}_today') ?? 0;
    await prefs.setInt('${key}_today', current + 1);
    if (!mounted) return;
    if (key == 'water') setState(() => _waterCount = current + 1);
  }

  Future<void> _openCheckin() async {
    HapticFeedback.selectionClick();
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const WearCheckinScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final aspect = size.aspectRatio;
    final isRound = aspect > 0.95 && aspect < 1.05;
    final hPad = isRound ? size.width * 0.12 : 14.0;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 10),
          child: Column(
            children: [
              const SizedBox(height: 4),
              Text(
                'Hi, Hamed',
                style: GoogleFonts.instrumentSerif(
                  color: AppColors.ink,
                  fontStyle: FontStyle.italic,
                  fontSize: 16,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              const WearOrb(size: 50),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _openCheckin,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'How are you?',
                    style: TextStyle(
                      color: AppColors.inkSoft,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  RoundButton(
                    icon: Icons.water_drop_outlined,
                    label: 'Water',
                    onTap: () => _quickLog('water'),
                  ),
                  RoundButton(
                    icon: Icons.self_improvement,
                    label: 'Calm',
                    onTap: () => _quickLog('calm'),
                  ),
                  RoundButton(
                    icon: Icons.directions_run,
                    label: 'Move',
                    onTap: () => _quickLog('move'),
                  ),
                ],
              ),
              if (_waterCount > 0) ...[
                const SizedBox(height: 4),
                Text(
                  '$_waterCount water today',
                  style: const TextStyle(
                    color: AppColors.inkDim,
                    fontSize: 9,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              _StreakCard(streak: _streak),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: AppColors.softGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$streak',
                  style: GoogleFonts.instrumentSerif(
                    color: AppColors.ink,
                    fontStyle: FontStyle.italic,
                    fontSize: 16,
                    height: 1.0,
                  ),
                ),
                const TextSpan(
                  text: ' day streak',
                  style: TextStyle(
                    color: AppColors.inkSoft,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          const Text('🔥', style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
