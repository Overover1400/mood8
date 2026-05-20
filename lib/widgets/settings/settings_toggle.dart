import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

class SettingsToggle extends StatelessWidget {
  const SettingsToggle({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.disabled = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.purpleLight.withValues(alpha: 0.18),
            ),
            child: Icon(icon, size: 16, color: AppColors.purpleLight),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: disabled ? BrandColors.inkDim(context) : BrandColors.ink(context),
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
          Switch.adaptive(
            value: value,
            onChanged: disabled || onChanged == null
                ? null
                : (v) {
                    HapticFeedback.selectionClick();
                    onChanged!(v);
                  },
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.pink,
            inactiveThumbColor: BrandColors.inkSoft(context),
            inactiveTrackColor: BrandColors.bg(context),
          ),
        ],
      ),
    );
  }
}
