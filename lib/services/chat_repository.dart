import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import 'database_service.dart';
import 'sync_service.dart';

class ChatRepository {
  ChatRepository({DatabaseService? db})
      : _db = db ?? DatabaseService.instance;

  static const String _conversationKey = 'mood8.currentConversationId';

  final DatabaseService _db;
  final Uuid _uuid = const Uuid();
  String? _cachedConversationId;

  Box<ChatMessage> get _box => _db.chatBox;

  Future<String> _ensureConversationId() async {
    if (_cachedConversationId != null) return _cachedConversationId!;
    try {
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString(_conversationKey);
      if (id == null) {
        id = _uuid.v4();
        await prefs.setString(_conversationKey, id);
      }
      _cachedConversationId = id;
      return id;
    } catch (e) {
      _cachedConversationId = _uuid.v4();
      return _cachedConversationId!;
    }
  }

  Future<ChatMessage> addMessage({
    required String role,
    required String content,
  }) async {
    final conversationId = await _ensureConversationId();
    final msg = ChatMessage(
      id: _uuid.v4(),
      role: role,
      content: content,
      timestamp: DateTime.now(),
      conversationId: conversationId,
      updatedAt: DateTime.now(),
    );
    try {
      await _box.put(msg.id, msg);
      SyncService().debouncedPush();
    } catch (e, st) {
      debugPrint('ChatRepository.addMessage failed: $e\n$st');
      rethrow;
    }
    return msg;
  }

  Future<List<ChatMessage>> getCurrentConversation() async {
    final id = await _ensureConversationId();
    return _box.values
        .where((m) => m.conversationId == id)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  List<ChatMessage> getCurrentConversationSync() {
    final id = _cachedConversationId;
    if (id == null) return const [];
    return _box.values.where((m) => m.conversationId == id).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  Future<void> clearCurrentConversation() async {
    final id = await _ensureConversationId();
    final keys = _box.values
        .where((m) => m.conversationId == id)
        .map((m) => m.id)
        .toList();
    try {
      for (final k in keys) {
        await SyncService().recordTombstone('chat_message', k);
      }
      await _box.deleteAll(keys);
      SyncService().debouncedPush();
      final prefs = await SharedPreferences.getInstance();
      final newId = _uuid.v4();
      await prefs.setString(_conversationKey, newId);
      _cachedConversationId = newId;
    } catch (e, st) {
      debugPrint('ChatRepository.clearCurrentConversation failed: $e\n$st');
      rethrow;
    }
  }

  Map<String, List<ChatMessage>> getAllConversations() {
    final grouped = <String, List<ChatMessage>>{};
    for (final m in _box.values) {
      grouped.putIfAbsent(m.conversationId, () => []).add(m);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    }
    return grouped;
  }

  ValueListenable<Box<ChatMessage>> watchMessages() => _box.listenable();
}
