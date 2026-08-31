import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/glass_decorations.dart';
import '../../data/models/sync_state.dart';
import '../../data/repositories/entry_repository.dart';

class ConnectionStatusBanner extends StatelessWidget {
  const ConnectionStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EntryRepository>(
      builder: (context, repo, _) {
        final state = repo.syncState;
        if (state.status == SyncStatus.synced || state.status == SyncStatus.idle) {
          return const SizedBox.shrink();
        }

        Color bgColor;
        Color textColor;
        IconData icon;
        String label;

        switch (state.status) {
          case SyncStatus.syncing:
            bgColor = AppColors.primary.withValues(alpha: 0.2);
            textColor = AppColors.primaryGlow;
            icon = Icons.sync;
            label = 'Syncing with cloud…';
            break;
          case SyncStatus.offline:
            bgColor = Colors.grey.withValues(alpha: 0.2);
            textColor = AppColors.textSecondary;
            icon = Icons.cloud_off;
            label = 'Offline — saving locally';
            break;
          case SyncStatus.error:
            bgColor = AppColors.errorBg;
            textColor = AppColors.error;
            icon = Icons.error_outline;
            label = state.errorMessage ?? 'Sync error — tap dock to retry';
            break;
          default:
            return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: GlassDecorations.glassCard(
            color: bgColor,
            borderRadius: 14,
            borderColor: textColor.withValues(alpha: 0.3),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.status == SyncStatus.syncing)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(textColor),
                  ),
                )
              else
                Icon(icon, size: 14, color: textColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
