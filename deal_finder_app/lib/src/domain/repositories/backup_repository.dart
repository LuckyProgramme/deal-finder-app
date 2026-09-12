import '../models/backup_archive.dart';

abstract interface class BackupRepository {
  /// A consistent SQLite read snapshot, excluding credentials and preferences.
  Future<BackupArchive> exportBackup();
  Future<String> backupFingerprint();

  /// All validation precedes replacement. Compare local state in the same
  /// transaction so a stale preview can never overwrite intervening user edits.
  Future<void> restoreBackup(
    BackupArchive archive, {
    required String expectedFingerprint,
  });
}
