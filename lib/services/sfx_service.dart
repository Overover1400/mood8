import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sfx_type.dart';

/// Singleton SFX manager.
///
/// Each SfxType is preloaded into its own [AudioPlayer]. Playback is
/// shaped through a code-side envelope (fade-in, gentle target volume,
/// fade-out near natural end) so the source MP3s — which have hard
/// attacks and cuts — feel soft and premium without needing to rework
/// the audio files themselves.
///
/// On web, the browser's autoplay policy blocks audio until a user
/// gesture, so preload is best-effort and [play] falls back to creating
/// a fresh [AudioPlayer] inside the gesture handler if the preloaded
/// one errors.
class SfxService extends ChangeNotifier {
  SfxService._();
  static final SfxService _instance = SfxService._();
  factory SfxService() => _instance;

  static const String _kEnabledKey = 'mood8.sfxEnabled';
  static const String _kVolumeKey = 'mood8.sfxVolume';
  static const String _kTag = '[Sfx]';

  // Envelope timing. Picked so the fade is perceptible enough to round
  // off a sharp attack but short enough that the sound still feels
  // responsive to the tap.
  static const int _kFadeInMs = 160;
  static const int _kFadeOutMs = 150;
  static const int _kFadeInSteps = 10;
  static const int _kFadeOutSteps = 10;
  // Rapid re-triggers of the SAME sound (e.g. mash + on a counter) are
  // dropped within this window so the user doesn't get a harsh stack.
  static const int _kDebounceMs = 150;

  /// Audio context applied to every SFX player so our UI feedback
  /// never preempts the user's music / podcast / video. See the
  /// long-form rationale on the global call in [initialize].
  static const AudioContext _kSfxAudioContext = AudioContext(
    android: AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: false,
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.assistanceSonification,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.ambient,
      options: [AVAudioSessionOptions.mixWithOthers],
    ),
  );
  // Hard upper bound on every SFX. Any clip whose duration exceeds
  // this gets a scheduled fade-out that lands at exactly 1000ms so
  // sounds never feel long-winded — the source files vary from
  // 200ms taps to 3s celebrations and we want the perceived length
  // to feel consistent + snappy.
  static const int _kMaxPlayMs = 1000;

  final Map<SfxType, AudioPlayer> _players = {};
  final Set<SfxType> _preloadFailed = {};
  final Map<SfxType, DateTime> _lastFireAt = {};
  final Map<SfxType, _Envelope> _active = {};

  bool _enabled = true;
  // The user's master gain — the per-sound `sfxBaseVolume` already
  // tunes each clip to a calm baseline, so this slider scales the
  // whole calm set up or down. Default to 0.85 so the first-time
  // listening experience is loud enough to hear without overwhelming.
  double _volume = 0.85;
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
      _volume = stored ?? 0.85;
      debugPrint(
          '$_kTag prefs loaded · enabled=$_enabled · volume=$_volume (stored=$stored)');
    } catch (e) {
      debugPrint('$_kTag prefs load failed: $e');
    }

    // Mood8 SFX are short UI feedback (tap, ping, celebration) — NEVER
    // long-form playback the user is choosing to consume. They must
    // not interrupt the user's music, podcast, or video in another
    // app. Configure the global audio context to:
    //   - Android: usage=ASSISTANCE_SONIFICATION, content=SONIFICATION,
    //     audioFocus=NONE — explicitly requests no focus, so the OS
    //     mixes our blip on top of whatever else is playing.
    //   - iOS:     AVAudioSessionCategory.ambient + mixWithOthers —
    //     the iOS equivalent of "I'm a side channel; don't steal the
    //     foreground".
    // Best-effort; failure is non-fatal (older devices, web, etc.).
    try {
      await AudioPlayer.global.setAudioContext(
        const AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.none,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: [AVAudioSessionOptions.mixWithOthers],
          ),
        ),
      );
      debugPrint('$_kTag global AudioContext set (mix, no focus)');
    } catch (e) {
      debugPrint('$_kTag global AudioContext setup failed: $e');
    }

    for (final entry in sfxAssetPaths.entries) {
      final type = entry.key;
      final path = entry.value;
      final bundlePath = 'assets/$path';

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
        // Per-player context so each SFX is independently flagged
        // as "side-channel, don't take focus" — see _kSfxAudioContext.
        try {
          await player.setAudioContext(_kSfxAudioContext);
        } catch (_) {}
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

  /// Final playback target for a given type — base volume × master.
  /// Clamped to [0, 1].
  double _targetFor(SfxType type) {
    final base = sfxBaseVolume[type] ?? 0.4;
    return (base * _volume).clamp(0.0, 1.0);
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

    // Debounce: same sound within the window is dropped to prevent a
    // harsh stack on rapid taps. Distinct sound types are unaffected.
    final now = DateTime.now();
    final last = _lastFireAt[type];
    if (last != null && now.difference(last).inMilliseconds < _kDebounceMs) {
      debugPrint('$_kTag debounced ${type.name}');
      return;
    }
    _lastFireAt[type] = now;

    final target = _targetFor(type);
    if (target <= 0.0) return;
    debugPrint(
        '$_kTag → play ${type.name} · target=${target.toStringAsFixed(2)} '
        '(base=${sfxBaseVolume[type]}, master=$_volume)');

    // Smoothly cancel any in-flight envelope for this type. We don't
    // hard-stop here — the new envelope's fade-in covers the silence
    // gracefully.
    final previous = _active.remove(type);
    previous?.cancel();

    final preloaded = _players[type];
    if (preloaded != null) {
      try {
        await _playWithEnvelope(type, preloaded, target,
            isLazy: false);
        return;
      } catch (e) {
        debugPrint(
            '$_kTag preloaded play failed · ${type.name} · $e · trying lazy');
      }
    }

    // Lazy fallback for web autoplay-blocked preloads.
    try {
      final player = AudioPlayer(playerId: 'sfx_lazy_${type.name}');
      await player.setReleaseMode(ReleaseMode.release);
      try {
        await player.setAudioContext(_kSfxAudioContext);
      } catch (_) {}
      await player.setSource(AssetSource(sfxAssetPaths[type]!));
      await _playWithEnvelope(type, player, target, isLazy: true);
    } catch (e) {
      debugPrint('$_kTag play FAILED · ${type.name} · $e');
    }
  }

  /// Start playback from silence, fade up to [target] over [_kFadeInMs],
  /// then schedule a symmetric fade-out so the tail of the clip never
  /// cuts hard. Both fades cancel cleanly if the same sound is
  /// re-triggered before its envelope finishes.
  Future<void> _playWithEnvelope(
    SfxType type,
    AudioPlayer player,
    double target, {
    required bool isLazy,
  }) async {
    await player.stop();
    await player.setVolume(0.0);
    await player.resume();

    final env = _Envelope(player: player);
    _active[type] = env;

    // FADE IN: linear ramp from 0 → target across _kFadeInMs.
    final inStep = (_kFadeInMs / _kFadeInSteps).round();
    var inIdx = 0;
    env.fadeInTimer = Timer.periodic(
      Duration(milliseconds: inStep),
      (t) {
        if (env.cancelled) {
          t.cancel();
          return;
        }
        inIdx += 1;
        final v = (target * inIdx / _kFadeInSteps).clamp(0.0, 1.0);
        // ignore: discarded_futures
        player.setVolume(v).catchError((_) {});
        if (inIdx >= _kFadeInSteps) t.cancel();
      },
    );

    // FADE OUT scheduling. The endMs is the earlier of (natural end)
    // and the hard _kMaxPlayMs cap — every sound stops at the 1s mark
    // at the latest. The fade window is the standard _kFadeOutMs
    // unless the effective length is so short the fade would
    // dominate, in which case it shrinks to half-runtime so the tail
    // still softens.
    int naturalEndMs = _kMaxPlayMs;
    try {
      final dur = await player.getDuration();
      if (dur != null && dur.inMilliseconds > 0) {
        naturalEndMs = dur.inMilliseconds;
      }
    } catch (e) {
      debugPrint(
          '$_kTag duration unavailable · ${type.name} · $e (using cap)');
    }
    final endMs =
        naturalEndMs < _kMaxPlayMs ? naturalEndMs : _kMaxPlayMs;
    final fadeWindowMs =
        endMs > _kFadeOutMs * 2 ? _kFadeOutMs : (endMs ~/ 2);
    final scheduleAt = endMs - fadeWindowMs;
    env.fadeOutScheduleTimer = Timer(
      Duration(milliseconds: scheduleAt.clamp(0, _kMaxPlayMs)),
      () => _startFadeOut(type, env, target,
          isLazy: isLazy, fadeMs: fadeWindowMs),
    );

    debugPrint(
        '$_kTag enveloped · ${type.name} · target=${target.toStringAsFixed(2)} '
        '(lazy=$isLazy · endMs=$endMs · fadeStart=$scheduleAt · fadeMs=$fadeWindowMs)');
  }

  void _startFadeOut(
    SfxType type,
    _Envelope env,
    double from, {
    required bool isLazy,
    required int fadeMs,
  }) {
    if (env.cancelled) return;
    env.fadeInTimer?.cancel();
    // Scale the step count down for short fades so we never schedule
    // a sub-1ms timer (which would coalesce in the event loop anyway).
    final steps =
        fadeMs >= _kFadeOutSteps ? _kFadeOutSteps : fadeMs.clamp(1, _kFadeOutSteps);
    final outStep = (fadeMs / steps).round().clamp(1, fadeMs);
    var outIdx = steps;
    env.fadeOutTimer = Timer.periodic(
      Duration(milliseconds: outStep),
      (t) {
        if (env.cancelled) {
          t.cancel();
          return;
        }
        outIdx -= 1;
        final v = (from * outIdx / steps).clamp(0.0, 1.0);
        // ignore: discarded_futures
        env.player.setVolume(v).catchError((_) {});
        if (outIdx <= 0) {
          t.cancel();
          // ignore: discarded_futures
          env.player.stop().catchError((_) {});
          // Lazy player isn't reused — dispose so it doesn't leak.
          if (isLazy) {
            // ignore: discarded_futures
            env.player.dispose().catchError((_) {});
          }
          if (identical(_active[type], env)) _active.remove(type);
        }
      },
    );
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
    for (final env in _active.values) {
      env.cancel();
    }
    _active.clear();
    for (final player in _players.values) {
      try {
        player.dispose();
      } catch (_) {}
    }
    _players.clear();
    super.dispose();
  }
}

/// Tracks the timers + player owned by a single playback so a
/// re-trigger of the same sound can cancel them cleanly.
class _Envelope {
  _Envelope({required this.player});
  final AudioPlayer player;
  Timer? fadeInTimer;
  Timer? fadeOutTimer;
  Timer? fadeOutScheduleTimer;
  bool cancelled = false;

  void cancel() {
    cancelled = true;
    fadeInTimer?.cancel();
    fadeOutTimer?.cancel();
    fadeOutScheduleTimer?.cancel();
  }
}
