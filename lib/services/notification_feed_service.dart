import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';

/// Wraps `/api/notifications` for the bell-icon feed (separate from
/// system push notifications). Singleton, owns one http client, polls
/// on demand. Exposes ValueNotifiers for the unread count + the
/// loaded list so the bell + screen rebuild reactively.
class NotificationFeedService {
  NotificationFeedService._();
  static final NotificationFeedService _instance = NotificationFeedService._();
  factory NotificationFeedService() => _instance;

  static const String _baseUrl = 'https://mood8.app/api';
  static const Duration _timeout = Duration(seconds: 15);

  final http.Client _client = http.Client();

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);
  final ValueNotifier<List<AppNotification>> notifications =
      ValueNotifier<List<AppNotification>>(const []);

  bool _loading = false;
  bool get isLoading => _loading;

  Map<String, String> get _authHeaders {
    final t = AuthService().token;
    return {
      if (t != null) 'authorization': 'Bearer $t',
      'content-type': 'application/json',
    };
  }

  /// Fetch the latest notifications. Silently no-ops when not signed in.
  Future<void> refresh() async {
    if (AuthService().token == null) {
      unreadCount.value = 0;
      notifications.value = const [];
      return;
    }
    if (_loading) return;
    _loading = true;
    try {
      final res = await _client
          .get(Uri.parse('$_baseUrl/notifications'), headers: _authHeaders)
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('[Notify] refresh ${res.statusCode}: ${res.body}');
        return;
      }
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      unreadCount.value = (body['unread_count'] as num?)?.toInt() ?? 0;
      notifications.value = ((body['notifications'] as List?) ?? const [])
          .map((n) => AppNotification.fromJson(n as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[Notify] refresh error: $e');
    } finally {
      _loading = false;
    }
  }

  /// Mark one read. Optimistic — flips local state before the
  /// network round-trip and rolls back on error.
  Future<void> markRead(int id) async {
    final before = notifications.value;
    final beforeUnread = unreadCount.value;
    notifications.value = [
      for (final n in before)
        if (n.id == id) n.copyWith(isRead: true) else n,
    ];
    unreadCount.value = (beforeUnread - 1).clamp(0, 1 << 30);
    try {
      final res = await _client
          .post(Uri.parse('$_baseUrl/notifications/$id/read'),
              headers: _authHeaders)
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('[Notify] markRead ${res.statusCode}: ${res.body}');
        notifications.value = before;
        unreadCount.value = beforeUnread;
      }
    } catch (e) {
      debugPrint('[Notify] markRead error: $e');
      notifications.value = before;
      unreadCount.value = beforeUnread;
    }
  }

  Future<void> markAllRead() async {
    final before = notifications.value;
    final beforeUnread = unreadCount.value;
    notifications.value = [
      for (final n in before) n.copyWith(isRead: true),
    ];
    unreadCount.value = 0;
    try {
      final res = await _client
          .post(Uri.parse('$_baseUrl/notifications/read-all'),
              headers: _authHeaders)
          .timeout(_timeout);
      if (res.statusCode < 200 || res.statusCode >= 300) {
        debugPrint('[Notify] markAllRead ${res.statusCode}: ${res.body}');
        notifications.value = before;
        unreadCount.value = beforeUnread;
      }
    } catch (e) {
      debugPrint('[Notify] markAllRead error: $e');
      notifications.value = before;
      unreadCount.value = beforeUnread;
    }
  }
}

/// One notification row as returned by the API.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.relatedId,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  final String type;
  final String title;
  final String body;
  final int? relatedId;
  final bool isRead;
  final DateTime createdAt;

  AppNotification copyWith({
    int? id,
    String? type,
    String? title,
    String? body,
    int? relatedId,
    bool? isRead,
    DateTime? createdAt,
  }) =>
      AppNotification(
        id: id ?? this.id,
        type: type ?? this.type,
        title: title ?? this.title,
        body: body ?? this.body,
        relatedId: relatedId ?? this.relatedId,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt ?? this.createdAt,
      );

  factory AppNotification.fromJson(Map<String, dynamic> json) =>
      AppNotification(
        id: (json['id'] as num).toInt(),
        type: (json['type'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        body: (json['body'] as String?) ?? '',
        relatedId: (json['related_id'] as num?)?.toInt(),
        isRead: json['is_read'] as bool? ?? false,
        createdAt:
            DateTime.tryParse(json['created_at'] as String? ?? '') ??
                DateTime.now(),
      );
}
