import 'package:flutter/material.dart';

import '../../../../core/strings/app_strings.dart';
import '../../../../core/widgets/status_chip.dart';

/// The three sync states the user can see. (SYNCING is shown as pending:
/// from the user's point of view it has not arrived yet.)
enum SyncChipKind { pending, synced, rejected }

/// Amber "Pending Sync", blue "Synced" or red "Rejected".
/// A rejected chip is a button: [onRejectedTap] opens the reason.
class SyncStatusChip extends StatelessWidget {
  const SyncStatusChip({super.key, required this.kind, this.onRejectedTap});

  final SyncChipKind kind;
  final VoidCallback? onRejectedTap;

  @override
  Widget build(BuildContext context) {
    return switch (kind) {
      SyncChipKind.pending => const StatusChip(
          label: AppStrings.pendingSync,
          tone: ChipTone.warning,
        ),
      SyncChipKind.synced => const StatusChip(
          label: AppStrings.synced,
          tone: ChipTone.success,
        ),
      SyncChipKind.rejected => StatusChip(
          label: AppStrings.rejected,
          tone: ChipTone.danger,
          onTap: onRejectedTap,
        ),
    };
  }
}
