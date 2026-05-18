import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'database_service.dart';
import 'user_repository.dart';

enum FeedbackKind { bug, feature, general }

extension FeedbackKindLabel on FeedbackKind {
  String get label {
    switch (this) {
      case FeedbackKind.bug:
        return 'Bug report';
      case FeedbackKind.feature:
        return 'Feature request';
      case FeedbackKind.general:
        return 'General feedback';
    }
  }

  String get prefix {
    switch (this) {
      case FeedbackKind.bug:
        return '[Bug]';
      case FeedbackKind.feature:
        return '[Feature]';
      case FeedbackKind.general:
        return '[Feedback]';
    }
  }
}

class FeedbackService {
  FeedbackService._();
  static final FeedbackService _instance = FeedbackService._();
  factory FeedbackService() => _instance;

  static const String supportEmail = 'feedback@mood8.app';
  static const String appVersion = '0.1.0';

  /// Builds an opaque mailto: link with subject + prefilled body and copies
  /// it to the clipboard. Returns the body so the caller can show a
  /// preview / open via a future url_launcher integration.
  Future<String> compose({
    required FeedbackKind kind,
    required String message,
    bool includeSnapshot = false,
  }) async {
    final user = UserRepository().getCurrentUser();
    final db = DatabaseService.instance;
    final locale = _safeLocale();
    final body = StringBuffer()
      ..writeln(message.trim())
      ..writeln('')
      ..writeln('— Sent from Mood8 v$appVersion —')
      ..writeln('Platform: ${kIsWeb ? 'web' : defaultTargetPlatform.name}')
      ..writeln('Locale: ${locale.toLanguageTag()}');

    if (includeSnapshot) {
      final snapshot = {
        'name': user?.name,
        'identities': user?.identities,
        'chronotype': user?.chronotype.name,
        'counts': {
          'mood_entries': db.moodBox.length,
          'routines': db.routineBox.length,
          'habits': db.habitBox.length,
          'habit_logs': db.habitLogBox.length,
          'reflections': db.reflectionBox.length,
          'insights': db.insightBox.length,
        },
      };
      body
        ..writeln('')
        ..writeln('Anonymous snapshot:')
        ..writeln(const JsonEncoder.withIndent('  ').convert(snapshot));
    }

    final preview = message.trim().replaceAll(RegExp(r'\s+'), ' ');
    final truncated = preview.length > 50
        ? '${preview.substring(0, 50)}…'
        : preview;
    final subject = truncated.isEmpty
        ? '[Mood8 Feedback] ${kind.label}'
        : '[Mood8 Feedback] ${kind.label}: $truncated';
    final mailto =
        'mailto:$supportEmail?subject=${Uri.encodeComponent(subject)}'
        '&body=${Uri.encodeComponent(body.toString())}';

    try {
      await Clipboard.setData(ClipboardData(text: mailto));
    } catch (e) {
      debugPrint('FeedbackService.compose clipboard failed: $e');
    }
    return body.toString();
  }
}

Locale _safeLocale() {
  try {
    return WidgetsBinding.instance.platformDispatcher.locale;
  } catch (_) {
    return const Locale('en', 'US');
  }
}
