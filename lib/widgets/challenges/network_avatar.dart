import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Round avatar that prefers a server-supplied image and falls back to
/// a gradient + first initial. Sized via [size]; pass the absolute URL
/// (`absoluteAvatarUrl(raw)`) — null/empty renders the fallback.
///
/// Used across the Challenges UI (creator row, participant tile, join
/// requests) so every screen renders real photos when present and
/// degrades to the same identity-initials chip when not.
class NetworkAvatar extends StatelessWidget {
  const NetworkAvatar({
    super.key,
    required this.name,
    required this.avatarUrl,
    required this.size,
    this.gradient,
    this.borderColor,
    this.borderWidth = 0,
  });

  final String name;
  final String? avatarUrl;
  final double size;
  final Gradient? gradient;
  final Color? borderColor;
  final double borderWidth;

  String get _letter =>
      name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient ?? AppColors.orbGradient,
      ),
      child: Text(
        _letter,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    final hasUrl = avatarUrl != null && avatarUrl!.isNotEmpty;
    final inner = hasUrl
        ? SizedBox(
            width: size,
            height: size,
            child: ClipOval(
              child: Image.network(
                avatarUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return fallback;
                },
              ),
            ),
          )
        : fallback;
    if (borderWidth <= 0) return inner;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor ?? Colors.transparent,
          width: borderWidth,
        ),
      ),
      child: ClipOval(child: inner),
    );
  }
}
