import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// D11 — one tyre, one block. Two columns on a small screen.
///
/// Slip number is the identity (UIDs are never rendered — D9), the
/// customer is prominent, a scrap tyre carries a D badge, and the block
/// is white until scanned, green after.
class TyreBlock extends StatelessWidget {
  const TyreBlock({
    super.key,
    required this.slipNumber,
    this.customer,
    this.detail,
    this.isScrap = false,
    this.scanned = false,
    this.onTap,
  });

  final String slipNumber;
  final String? customer;
  final String? detail;
  final bool isScrap;
  final bool scanned;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final border = scanned
        ? AppColors.successStrong(context)
        : AppColors.dynamicTextMuted(context).withValues(alpha: 0.35);
    final fill = scanned
        ? AppColors.successStrong(context).withValues(alpha: 0.14)
        : AppColors.dynamicSurfaceRaised(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    slipNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      fontFamily: 'monospace',
                      color: AppColors.dynamicTextPrimary(context),
                    ),
                  ),
                ),
                if (isScrap)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.errorStrong(
                        context,
                      ).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'D',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.errorStrong(context),
                      ),
                    ),
                  ),
              ],
            ),
            if (customer != null && customer!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                customer!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: scanned
                      ? AppColors.successStrong(context)
                      : AppColors.dynamicTextPrimary(context),
                ),
              ),
            ],
            if (detail != null && detail!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                detail!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.dynamicTextMuted(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Non-scrolling two-column grid of [TyreBlock]s for use inside lists.
class TyreBlockGrid extends StatelessWidget {
  const TyreBlockGrid({super.key, required this.blocks});

  final List<TyreBlock> blocks;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 2;
        const spacing = 10.0;
        final width = (constraints.maxWidth - spacing) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final block in blocks)
              SizedBox(width: width, child: block),
          ],
        );
      },
    );
  }
}
