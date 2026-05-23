import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/analytics_models.dart';
import '../theme/app_theme.dart';

class HighlightCard extends StatelessWidget {
  const HighlightCard({super.key, required this.item});
  final HighlightItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: BrandColors.bgCard(context).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(item.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: BrandColors.inkDim(context),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            item.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.bricolageGrotesque(
              color: BrandColors.ink(context),
              fontSize: 19,
              height: 1.1,
            ),
          ),
          if (item.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              item.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: BrandColors.inkDim(context),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
