import 'dart:async';

import 'package:flutter/foundation.dart';

/// Coordinates "is the screen currently showing a celebration / reward
/// overlay" so other things (notably the tutorial) can hold off until
/// every active celebration has dismissed.
///
/// Producers tick [push] when they show an overlay and [pop] when it
/// dismisses. Consumers await [whenIdle] (or listen to [activeCount])
/// to gate their own surfaces.
class OverlayCoordinator {
  OverlayCoordinator._();
  static final OverlayCoordinator _instance = OverlayCoordinator._();
  factory OverlayCoordinator() => _instance;

  /// Number of celebration overlays currently on-screen. > 0 means at
  /// least one badge / effect / reward is being displayed.
  final ValueNotifier<int> activeCount = ValueNotifier<int>(0);

  void push() {
    activeCount.value = activeCount.value + 1;
  }

  void pop() {
    activeCount.value = (activeCount.value - 1).clamp(0, 1 << 30);
  }

  bool get isBusy => activeCount.value > 0;

  /// Completes once the counter drops to zero. Returns immediately when
  /// already idle. Polls via the notifier — no busy-wait, no timers.
  Future<void> whenIdle() {
    if (activeCount.value == 0) return Future.value();
    final completer = Completer<void>();
    late void Function() listener;
    listener = () {
      if (activeCount.value == 0) {
        activeCount.removeListener(listener);
        if (!completer.isCompleted) completer.complete();
      }
    };
    activeCount.addListener(listener);
    return completer.future;
  }
}
