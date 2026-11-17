import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../dispatch/models/slip_tyre.dart';

/// D11 — one tyre, one block. Two columns on a small screen.
///
/// The important stuff, per the floor's spec: SLIP number, SERIAL, MAKE,
/// PATTERN — plus the customer (prominent) and a solid RED **D** badge
/// for anything rejected (scrap or dump — the marker covers both).
/// White until scanned, green after. UIDs never render (D9).
class TyreBlock extends StatelessWidget {
  const TyreBlock({
    super.key,
    required this.tyre,
    this.scanned = false,
    this.onTap,
  });

  final SlipTyre tyre;
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
    final customer = tyre.customerName?.trim() ?? '';
    final makePattern = [
      if (tyre.make != null && tyre.make!.isNotEmpty) tyre.make!,
      if (tyre.pattern != null && tyre.pattern!.isNotEmpty) tyre.pattern!,
    ].join(' · ');

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
                    tyre.slipNumber?.toString() ?? tyre.serial ?? '?',
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
                if (tyre.isScrap) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.errorStrong(context),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'D',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (customer.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                customer,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: scanned
                      ? AppColors.successStrong(context)
                      : AppColors.dynamicTextPrimary(context),
                ),
              ),
            ],
            if (tyre.serial != null && tyre.serial!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                tyre.serial!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'monospace',
                  letterSpacing: 0.5,
                  color: AppColors.dynamicTextSecondary(context),
                ),
              ),
            ],
            if (makePattern.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                makePattern,
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
            for (final block in blocks) SizedBox(width: width, child: block),
          ],
        );
      },
    );
  }
}
