import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper around [HapticFeedback] that respects a user toggle and
/// notifies listeners so Settings UI can stay in sync.
class HapticService extends ChangeNotifier {
  HapticService._();
  static final HapticService _instance = HapticService._();
  factory HapticService() => _instance;

  static const String _kEnabledKey = 'mood8.hapticEnabled';

  bool _enabled = true;
  bool _initialized = false;

  bool get isEnabled => _enabled;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_kEnabledKey) ?? true;
    } catch (e) {
      debugPrint('HapticService.initialize failed: $e');
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> setEnabled(bool value) async {
    if (value == _enabled) return;
    _enabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabledKey, value);
    } catch (e) {
      debugPrint('HapticService.setEnabled failed: $e');
    }
  }

  Future<void> light() async {
    if (!_enabled) return;
    try {
      await HapticFeedback.lightImpact();
    } catch (_) {}
  }

  Future<void> medium() async {
    if (!_enabled) return;
    try {
      await HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  Future<void> heavy() async {
    if (!_enabled) return;
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  Future<void> selection() async {
    if (!_enabled) return;
    try {
      await HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
