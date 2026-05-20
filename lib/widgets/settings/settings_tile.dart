import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final iColor = destructive
        ? const Color(0xFFFF6B81)
        : (iconColor ?? AppColors.purpleLight);
    final tColor =
        destructive ? const Color(0xFFFF6B81) : BrandColors.ink(context);
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iColor.withValues(alpha: 0.18),
            ),
            child: Icon(icon, size: 16, color: iColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: tColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: BrandColors.inkDim(context),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            DefaultTextStyle.merge(
              style: TextStyle(
                color: BrandColors.inkSoft(context),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              child: trailing!,
            ),
          ],
          if (onTap != null && trailing == null) ...[
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded,
                color: BrandColors.inkDim(context), size: 18),
          ],
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: content,
      ),
    );
  }
}
