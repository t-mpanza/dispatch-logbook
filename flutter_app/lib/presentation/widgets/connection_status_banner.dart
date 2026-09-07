import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/haptics.dart';
import '../../data/models/sync_state.dart';
import '../../data/repositories/entry_repository.dart';

/// Quiet status chip: invisible when healthy, gently informative when
/// syncing, and tappable (retry) when something went wrong.
class ConnectionStatusBanner extends StatelessWidget {
  const ConnectionStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EntryRepository>(
      builder: (context, repo, _) {
        final state = repo.syncState;
        if (state.status == SyncStatus.synced ||
            state.status == SyncStatus.idle) {
          return const SizedBox.shrink();
        }

        final isLight = AppColors.isLight(context);
        final isSyncing = state.status == SyncStatus.syncing;
        final isOffline = state.status == SyncStatus.offline;
        final color = isSyncing
            ? AppColors.dynamicAccent(context)
            : (isOffline
                  ? AppColors.dynamicTextSecondary(context)
                  : AppColors.error);
        final label = isSyncing
            ? 'Syncing changes…'
            : (isOffline
                  ? 'Offline — entries saved on this device'
                  : (state.errorMessage ?? 'Sync problem — tap to retry'));

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: GestureDetector(
            onTap: state.status == SyncStatus.error
                ? () {
                    AppHaptics.medium();
                    repo.syncNow();
                  }
                : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: isLight ? 0.1 : 0.12),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSyncing)
                    SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    )
                  else
                    Icon(
                      isOffline
                          ? Icons.cloud_off_rounded
                          : Icons.error_outline_rounded,
                      size: 14,
                      color: color,
                    ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
