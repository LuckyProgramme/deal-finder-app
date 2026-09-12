import '../../domain/repositories/backup_repository.dart';
import '../pipeline/pipeline_controller.dart';
import '../sync/sync_coordinator.dart';

/// Keep external writes and scans quiescent throughout file selection, preview,
/// and replacement. The repository separately checks for intervening local edits.
final class BackupCoordinator {
  BackupCoordinator(this.repository, this.pipeline, this.sheets);
  final BackupRepository repository;
  final PipelineController pipeline;
  final SyncCoordinator sheets;

  Future<T> exclusive<T>(Future<T> Function(BackupRepository) action) async {
    final maintenance = pipeline.acquireMaintenance();
    SheetsOperation? operation;
    try {
      operation = sheets.acquire();
      return await action(repository);
    } finally {
      if (operation != null) sheets.release(operation);
      pipeline.releaseMaintenance(maintenance);
    }
  }
}
