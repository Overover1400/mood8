import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../models/chat_message.dart';
import '../theme/app_theme.dart';

class ChatBubble extends StatelessWidget {
  const ChatBubble({super.key, required this.message});

  static final DateFormat _kTimeFmt = DateFormat('HH:mm');

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final time = _kTimeFmt.format(message.timestamp);

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        gradient: isUser
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.purple.withValues(alpha: 0.85),
                  AppColors.pink.withValues(alpha: 0.70),
                ],
              )
            : null,
        color:
            isUser ? null : AppColors.bgCard.withValues(alpha: 0.85),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isUser ? 18 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 18),
        ),
        border: Border.all(
          color: isUser
              ? AppColors.pinkLight.withValues(alpha: 0.30)
              : AppColors.purple.withValues(alpha: 0.18),
        ),
        boxShadow: isUser
            ? [
                BoxShadow(
                  color: AppColors.pink.withValues(alpha: 0.30),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Text(
        message.content,
        style: TextStyle(
          color: isUser ? Colors.white : AppColors.ink,
          fontSize: 14,
          height: 1.4,
        ),
      ),
    );

    final row = Row(
      mainAxisAlignment:
          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (!isUser) const _AiAvatar(),
        if (!isUser) const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment:
                isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              bubble,
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  time,
                  style: TextStyle(
                    color: AppColors.inkDim,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return row
        .animate()
        .fadeIn(duration: 280.ms)
        .slideX(
          begin: isUser ? 0.05 : -0.05,
          end: 0,
          curve: Curves.easeOut,
        );
  }
}

class _AiAvatar extends StatelessWidget {
  const _AiAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.orbGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.pink.withValues(alpha: 0.40),
            blurRadius: 10,
          ),
        ],
      ),
    );
  }
}
