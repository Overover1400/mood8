import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../theme/app_theme.dart';
import '../widgets/round_button.dart';
import '../widgets/wear_slider.dart';

class WearCheckinScreen extends StatefulWidget {
  const WearCheckinScreen({super.key});

  @override
  State<WearCheckinScreen> createState() => _WearCheckinScreenState();
}

class _WearCheckinScreenState extends State<WearCheckinScreen> {
  static const _labels = ['Mood', 'Energy', 'Focus'];
  final _values = [0.7, 0.7, 0.7];
  int _step = 0;

  void _next() {
    HapticFeedback.selectionClick();
    if (_step < 2) {
      setState(() => _step += 1);
    } else {
      _save();
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now().toIso8601String();
    await prefs.setString('last_checkin', now);
    await prefs.setDouble('last_mood', _values[0]);
    await prefs.setDouble('last_energy', _values[1]);
    await prefs.setDouble('last_focus', _values[2]);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  void _adjust(double delta) {
    final next = (_values[_step] + delta).clamp(0.0, 1.0);
    if (next != _values[_step]) {
      HapticFeedback.selectionClick();
      setState(() => _values[_step] = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRound = MediaQuery.of(context).size.aspectRatio > 0.95 &&
        MediaQuery.of(context).size.aspectRatio < 1.05;
    final score = (_values[_step] * 10).round();

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            _adjust(event.scrollDelta.dy < 0 ? 0.05 : -0.05);
          }
        },
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isRound ? 24 : 14,
              vertical: 8,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  _labels[_step],
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '$score',
                  style: GoogleFonts.instrumentSerif(
                    color: AppColors.ink,
                    fontStyle: FontStyle.italic,
                    fontSize: 36,
                    height: 1.0,
                  ),
                ),
                const SizedBox(height: 8),
                WearSlider(
                  value: _values[_step],
                  onChanged: (v) => setState(() => _values[_step] = v),
                ),
                const SizedBox(height: 8),
                _StepDots(step: _step, total: 3),
                const SizedBox(height: 8),
                PillButton(
                  label: _step < 2 ? 'Next' : 'Save',
                  onTap: _next,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({required this.step, required this.total});

  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == step;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 12 : 6,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(3),
            color: active ? AppColors.pinkLight : AppColors.inkFaint,
          ),
        );
      }),
    );
  }
}
