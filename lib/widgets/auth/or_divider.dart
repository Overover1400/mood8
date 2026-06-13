import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// "or" rule used between the primary submit button and the Google
/// sign-in button on the Sign In + Register screens. Shared so the
/// two flows feel symmetric.
class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final lineColor = AppColors.purple.withValues(alpha: 0.20);
    return Row(
      children: [
        Expanded(child: Divider(color: lineColor, height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Text(
            'or',
            style: TextStyle(
              color: BrandColors.inkDim(context),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Expanded(child: Divider(color: lineColor, height: 1)),
      ],
    );
  }
}
