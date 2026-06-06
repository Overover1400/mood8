import 'package:flutter/foundation.dart';

/// In-process ring buffer that captures every `[Notif] …` event the
/// notification stack emits. The diagnostics screen reads it so a
/// tester can see the actual sequence of init / schedule / cancel
/// results AT THE TIME the system fired them — without needing a
/// USB cable + `adb logcat`.
///
/// Each entry is `HH:MM:SS message`. We keep the last [maxEntries]
/// (60) so the buffer is always tail-relevant even on a long session.
class NotifLog {
  NotifLog._();

  static const int maxEntries = 60;

  static final List<String> _entries = <String>[];

  /// Subscribe to redraw a diagnostics view whenever a new line lands.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Append a line. Also forwards to debugPrint so `flutter logs` /
  /// logcat still shows the same trail for devs who prefer the wire.
  static void log(String msg) {
    final ts = DateTime.now().toIso8601String().substring(11, 19);
    _entries.add('$ts  $msg');
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
    revision.value = revision.value + 1;
    debugPrint('[Notif] $msg');
  }

  static List<String> snapshot() => List<String>.unmodifiable(_entries);

  static void clear() {
    _entries.clear();
    revision.value = revision.value + 1;
  }
}
