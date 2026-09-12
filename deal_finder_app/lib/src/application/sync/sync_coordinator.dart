import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../domain/models/run_snapshot.dart';
import '../../domain/models/sync_job.dart';
import '../../domain/repositories/repositories.dart';
import '../../data/sheets/sheets_gateway.dart';
import '../pipeline/cancellation.dart';
import 'sheets_sync_service.dart';

/// Ownership of the app-wide Sheets operation lock, including preview/connect.
final class SheetsOperation {
  SheetsOperation._();
  bool _executing = false;
}

final class SyncCoordinator {
  SyncCoordinator(this.repository);
  final SyncRepository repository;
  SheetsOperation? _active;
  bool get busy => _active != null;
  SheetsOperation acquire() {
    if (busy) throw StateError('Another Sheets operation is still running.');
    return _active = SheetsOperation._();
  }

  void release(SheetsOperation operation) {
    if (!identical(_active, operation) || operation._executing) {
      throw StateError('Sheets operation ownership is invalid.');
    }
    _active = null;
  }

  static String hash(RunSnapshot snapshot) =>
      sha256.convert(utf8.encode(jsonEncode(snapshot.toJson()))).toString();
  Future<SyncJob> enqueue(RunSnapshot snapshot, String destination) async {
    final id = '${snapshot.runId}:$destination';
    final existing = (await repository.watchSyncJobs().first)
        .where((job) => job.id == id)
        .firstOrNull;
    if (existing != null) return existing;
    final job = SyncJob(
      id: id,
      destination: destination,
      snapshot: snapshot,
      payloadHash: hash(snapshot),
    );
    await repository.saveSyncJob(job);
    return job;
  }

  Future<void> execute(
    SyncJob initial,
    SheetsGateway gateway,
    Cancellation c, {
    SheetsOperation? operation,
  }) async {
    final lease = operation ?? acquire();
    if (!identical(_active, lease) || lease._executing) {
      throw StateError('Another Sheets operation is still running.');
    }
    lease._executing = true;
    try {
      await _execute(initial, gateway, c);
    } finally {
      lease._executing = false;
      if (operation == null) release(lease);
    }
  }

  Future<void> _execute(
    SyncJob initial,
    SheetsGateway gateway,
    Cancellation c,
  ) async {
    if (initial.state == 'completed') return;
    if (hash(initial.snapshot) != initial.payloadHash) {
      throw StateError('Saved sync payload failed its integrity check.');
    }
    var job = initial.progress(
      attempts: initial.attempts + 1,
      state: 'uploading',
    );
    try {
      await repository.saveSyncJob(job);
      await SheetsSyncService(gateway).sync(
        job.snapshot,
        c,
        completedTabs: job.completedTabs,
        checkpoint: (tab) async {
          job = job.progress(completedTabs: {...job.completedTabs, tab});
          await repository.saveSyncJob(job);
        },
      );
      job = job.progress(state: 'completed');
      await repository.saveSyncJob(job);
    } catch (_) {
      job = job.progress(
        state: c.cancelled ? 'cancelled' : 'failed',
        error: 'Sync is incomplete. Retry will use the original run and completed-tab checkpoints.',
      );
      await repository.saveSyncJob(job);
      rethrow;
    }
  }
}
