import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../models/chat_message.dart';
import '../theme/app_theme.dart';

class ChatBubble extends StatefulWidget {
  const ChatBubble({
    super.key,
    required this.message,
    this.reveal = false,
    this.onRevealComplete,
  });

  static final DateFormat _kTimeFmt = DateFormat('HH:mm');

  final ChatMessage message;

  /// When true, the bubble reveals its text word-by-word (typing
  /// effect) instead of showing it all at once. The coach screen flips
  /// this on for the single assistant message that just arrived so
  /// older messages don't re-animate when you scroll back.
  final bool reveal;

  /// Fires once when the reveal finishes (or immediately on mount when
  /// [reveal] is false). Lets the coach screen drop the "currently
  /// revealing" marker so a later send doesn't re-animate the same
  /// message.
  final VoidCallback? onRevealComplete;

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble>
    with SingleTickerProviderStateMixin {
  /// Words revealed so far. Starts at 0 for the live reveal, or at the
  /// full length immediately for non-revealing bubbles.
  int _wordsShown = 0;
  late final List<String> _tokens;
  Timer? _ticker;

  /// Comfortable typing pace — fast enough not to feel slow, slow
  /// enough that you can read along. 60ms / word ≈ ~200 wpm.
  static const Duration _tickInterval = Duration(milliseconds: 60);

  @override
  void initState() {
    super.initState();
    _tokens = _splitForReveal(widget.message.content);
    if (!widget.reveal || _tokens.isEmpty) {
      _wordsShown = _tokens.length;
      // Defer the completion callback so callers can read state mid-build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onRevealComplete?.call();
      });
    } else {
      _ticker = Timer.periodic(_tickInterval, (_) {
        if (!mounted) return;
        setState(() {
          _wordsShown = (_wordsShown + 1).clamp(0, _tokens.length);
        });
        if (_wordsShown >= _tokens.length) {
          _ticker?.cancel();
          _ticker = null;
          widget.onRevealComplete?.call();
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant ChatBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the message content swaps in place (rare — the coach repo
    // does immutable inserts), restart the reveal so we don't show
    // half of the old text.
    if (oldWidget.message.content != widget.message.content) {
      _ticker?.cancel();
      _tokens
        ..clear()
        ..addAll(_splitForReveal(widget.message.content));
      _wordsShown = widget.reveal ? 0 : _tokens.length;
      if (widget.reveal && _tokens.isNotEmpty) {
        _ticker = Timer.periodic(_tickInterval, (_) {
          if (!mounted) return;
          setState(() {
            _wordsShown = (_wordsShown + 1).clamp(0, _tokens.length);
          });
          if (_wordsShown >= _tokens.length) {
            _ticker?.cancel();
            _ticker = null;
            widget.onRevealComplete?.call();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Tokenise on whitespace, keeping the trailing whitespace attached
  /// to each word so re-joining preserves the original spacing.
  static List<String> _splitForReveal(String text) {
    if (text.isEmpty) return const [];
    final out = <String>[];
    final buf = StringBuffer();
    var inWhitespace = false;
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      final isWs = ch.trim().isEmpty;
      if (isWs) {
        inWhitespace = true;
        buf.write(ch);
      } else {
        if (inWhitespace && buf.isNotEmpty) {
          out.add(buf.toString());
          buf.clear();
          inWhitespace = false;
        }
        buf.write(ch);
      }
    }
    if (buf.isNotEmpty) out.add(buf.toString());
    return out;
  }

  String get _visible {
    if (_wordsShown >= _tokens.length) return widget.message.content;
    if (_wordsShown == 0) return '';
    return _tokens.take(_wordsShown).join();
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;
    final time = ChatBubble._kTimeFmt.format(widget.message.timestamp);
    final visible = _visible;

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
            isUser ? null : BrandColors.bgCard(context).withValues(alpha: 0.85),
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
        visible,
        style: TextStyle(
          color: isUser ? Colors.white : BrandColors.ink(context),
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
                    color: BrandColors.inkDim(context),
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
