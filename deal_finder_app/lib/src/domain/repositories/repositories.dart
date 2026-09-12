import '../models/target.dart';
import '../models/deal.dart';
import '../models/listing.dart';
import '../models/run_snapshot.dart';
import '../models/sync_job.dart';
import '../models/run_configuration.dart';

abstract interface class TargetRepository {
  Stream<List<Target>> watchTargets();
  Future<List<Target>> loadTargets();
  Future<void> saveTarget(Target target);
  Future<void> importTargets(List<Target> targets, List<Target> expectedLocal);
  Future<void> deleteTarget(String id);
}

abstract interface class DealRepository {
  Stream<List<Deal>> watchDeals();
  Stream<List<Deal>> watchCurrentDeals();
  Future<RunSnapshot?> loadLatestSnapshot();
  Future<void> persistDeals(
    List<Deal> deals,
    String runId, {
    List<Listing> listings = const [],
    List<Target> targets = const [],
  });
  Future<void> setDealFlags(String id, {bool? favorite, bool? dismissed});
}

final class RunRecord {
  const RunRecord({
    required this.id,
    required this.startedAt,
    required this.stage,
    this.finishedAt,
    this.scraped = 0,
    this.deals = 0,
    this.error,
    this.auditReport,
    this.configuration,
  });
  final String id, stage;
  final DateTime startedAt;
  final DateTime? finishedAt;
  final int scraped, deals;
  final String? error, auditReport;
  final RunConfiguration? configuration;
}

abstract interface class RunRepository {
  Stream<List<RunRecord>> watchRuns();
  Future<void> saveRun(RunRecord run);
  Future<void> recoverInterruptedRuns();
}

abstract interface class AppPreferencesRepository {
  Future<bool> hasCompletedOnboarding();
  Future<void> completeOnboarding();
}

abstract interface class SyncRepository {
  Future<void> saveSyncJob(SyncJob job);
  Stream<List<SyncJob>> watchSyncJobs();
}
