import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sfx_type.dart';

/// Singleton SFX manager.
///
/// On native platforms each SfxType is preloaded into its own [AudioPlayer]
/// so playback is instant and overlapping calls don't fight a single player.
///
/// On web the browser's autoplay policy blocks audio until a user gesture,
/// so preload is best-effort and [play] falls back to creating a fresh
/// [AudioPlayer] inside the gesture handler if the preloaded one errors.
///
/// All paths log with the `[Sfx]` prefix so they're easy to filter in
/// browser DevTools console.
class SfxService extends ChangeNotifier {
  SfxService._();
  static final SfxService _instance = SfxService._();
  factory SfxService() => _instance;

  static const String _kEnabledKey = 'mood8.sfxEnabled';
  static const String _kVolumeKey = 'mood8.sfxVolume';
  static const String _kTag = '[Sfx]';

  final Map<SfxType, AudioPlayer> _players = {};
  final Set<SfxType> _preloadFailed = {};

  bool _enabled = true;
  // Default to full volume so first-time users hear sounds clearly. They can
  // turn it down in Settings → Sound & haptics. No per-sound attenuation —
  // the slider is the single source of truth.
  double _volume = 1.0;
  bool _initialized = false;
  bool _firstPlayLogged = false;

  bool get isEnabled => _enabled;
  double get volume => _volume;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    debugPrint(
        '$_kTag initialize() start · kIsWeb=$kIsWeb · ${sfxAssetPaths.length} sounds');

    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_kEnabledKey) ?? true;
      final stored = prefs.getDouble(_kVolumeKey);
      // Migrate legacy 0.5 default to 1.0 so existing testers who never
      // touched the slider get the same audible default as new users.
      if (stored == null || stored == 0.5) {
        _volume = 1.0;
      } else {
        _volume = stored;
      }
      debugPrint(
          '$_kTag prefs loaded · enabled=$_enabled · volume=$_volume (stored=$stored)');
    } catch (e) {
      debugPrint('$_kTag prefs load failed: $e');
    }

    for (final entry in sfxAssetPaths.entries) {
      final type = entry.key;
      final path = entry.value;
      final bundlePath = 'assets/$path';

      // Bundle check: does the declared asset actually exist? If this fails,
      // pubspec.yaml or the file is wrong — no point trying to play.
      try {
        final bytes = await rootBundle.load(bundlePath);
        debugPrint(
            '$_kTag bundle OK · ${type.name} · $bundlePath · ${bytes.lengthInBytes}B');
      } catch (e) {
        debugPrint(
            '$_kTag bundle MISS · ${type.name} · $bundlePath · $e');
        _preloadFailed.add(type);
        continue;
      }

      try {
        final player = AudioPlayer(playerId: 'sfx_${type.name}');
        await player.setReleaseMode(ReleaseMode.stop);
        await player.setSource(AssetSource(path));
        _players[type] = player;
        debugPrint('$_kTag preloaded · ${type.name}');
      } catch (e) {
        debugPrint(
            '$_kTag preload failed (will retry lazily) · ${type.name} · $e');
        _preloadFailed.add(type);
      }
    }

    _initialized = true;
    notifyListeners();
    debugPrint(
        '$_kTag initialize() done · preloaded=${_players.length} · failed=${_preloadFailed.length}');
  }

  Future<void> play(SfxType type) async {
    if (!_firstPlayLogged) {
      _firstPlayLogged = true;
      debugPrint(
          '$_kTag first play attempt · ${type.name} · enabled=$_enabled · initialized=$_initialized');
    }

    if (!_enabled) {
      debugPrint('$_kTag skip ${type.name} · disabled by user');
      return;
    }
    if (!_initialized) {
      debugPrint('$_kTag skip ${type.name} · not initialized yet');
      return;
    }

    // Single source of truth: the user's master volume. No per-sound
    // attenuation — that was halving everything (0.55 base × 0.5 master =
    // 0.275 final, which was inaudible on most laptops).
    final vol = _volume.clamp(0.0, 1.0);
    debugPrint('$_kTag → play ${type.name} · final vol=$vol (master=$_volume)');

    // Fast path: reuse the preloaded player.
    final preloaded = _players[type];
    if (preloaded != null) {
      try {
        await preloaded.stop();
        await preloaded.setVolume(vol);
        await preloaded.resume();
        debugPrint('$_kTag played (preloaded) · ${type.name} · vol=$vol');
        return;
      } catch (e) {
        debugPrint(
            '$_kTag preloaded play failed · ${type.name} · $e · trying lazy');
        // fall through to lazy path
      }
    }

    // Lazy path: create a fresh player inside the user gesture. Works around
    // browser autoplay restrictions when the preloaded player got blocked
    // before any user interaction.
    try {
      final player = AudioPlayer(playerId: 'sfx_lazy_${type.name}');
      await player.setReleaseMode(ReleaseMode.release);
      await player.setVolume(vol);
      await player.play(AssetSource(sfxAssetPaths[type]!));
      debugPrint('$_kTag played (lazy) · ${type.name} · vol=$vol');
    } catch (e) {
      debugPrint('$_kTag play FAILED · ${type.name} · $e');
    }
  }

  /// Fire-and-forget convenience. Same as [play] but doesn't return a future.
  void fire(SfxType type) {
    // ignore: discarded_futures
    play(type);
  }

  Future<void> setEnabled(bool value) async {
    if (value == _enabled) return;
    _enabled = value;
    notifyListeners();
    debugPrint('$_kTag setEnabled · $value');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabledKey, value);
    } catch (e) {
      debugPrint('$_kTag setEnabled persist failed: $e');
    }
  }

  Future<void> setVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    if (clamped == _volume) return;
    _volume = clamped;
    notifyListeners();
    debugPrint('$_kTag setVolume · $_volume');
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kVolumeKey, _volume);
    } catch (e) {
      debugPrint('$_kTag setVolume persist failed: $e');
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
