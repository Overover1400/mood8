import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sfx_type.dart';

/// Singleton SFX manager. Preloads each sound into its own [AudioPlayer]
/// so playback is instant and overlapping calls don't fight a single player.
///
/// Designed to fail silently: missing assets, web-autoplay restrictions, and
/// platform errors all degrade to "no sound" rather than crashing.
class SfxService extends ChangeNotifier {
  SfxService._();
  static final SfxService _instance = SfxService._();
  factory SfxService() => _instance;

  static const String _kEnabledKey = 'mood8.sfxEnabled';
  static const String _kVolumeKey = 'mood8.sfxVolume';

  final Map<SfxType, AudioPlayer> _players = {};
  bool _enabled = true;
  double _volume = 0.5;
  bool _initialized = false;

  bool get isEnabled => _enabled;
  double get volume => _volume;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_kEnabledKey) ?? true;
      _volume = prefs.getDouble(_kVolumeKey) ?? 0.5;
    } catch (e) {
      debugPrint('SfxService prefs load failed: $e');
    }

    for (final entry in sfxAssetPaths.entries) {
      try {
        final player = AudioPlayer();
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setSource(AssetSource(entry.value));
        _players[entry.key] = player;
      } catch (e) {
        debugPrint('SfxService failed to preload ${entry.key.name}: $e');
      }
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> play(SfxType type) async {
    if (!_enabled || !_initialized) return;
    final player = _players[type];
    if (player == null) return;
    try {
      final base = sfxBaseVolume[type] ?? 0.5;
      await player.stop();
      await player.setVolume((base * _volume).clamp(0.0, 1.0));
      await player.resume();
    } catch (e) {
      debugPrint('SfxService.play ${type.name} failed: $e');
    }
  }

  void fire(SfxType type) {
    unawaited(play(type));
  }

  Future<void> setEnabled(bool value) async {
    if (value == _enabled) return;
    _enabled = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabledKey, value);
    } catch (e) {
      debugPrint('SfxService.setEnabled failed: $e');
    }
  }

  Future<void> setVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    if (clamped == _volume) return;
    _volume = clamped;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kVolumeKey, _volume);
    } catch (e) {
      debugPrint('SfxService.setVolume failed: $e');
    }
  }

  @override
  void dispose() {
    for (final player in _players.values) {
      try {
        player.dispose();
      } catch (_) {}
    }
    _players.clear();
    super.dispose();
  }
}
