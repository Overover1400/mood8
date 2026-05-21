import 'package:hive/hive.dart';

part 'chat_message.g.dart';

@HiveType(typeId: 7)
class ChatMessage extends HiveObject {
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.timestamp,
    required this.conversationId,
    this.updatedAt,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String role;

  @HiveField(2)
  String content;

  @HiveField(3)
  DateTime timestamp;

  @HiveField(4)
  String conversationId;

  @HiveField(5)
  DateTime? updatedAt;

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
}
