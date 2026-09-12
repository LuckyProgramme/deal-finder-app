import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:crypto/crypto.dart';

import '../../domain/models/target.dart';
import '../../domain/models/deal.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/run_snapshot.dart';
import '../../domain/models/sync_job.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/models/backup_archive.dart';
import '../../domain/models/run_configuration.dart';
import '../../domain/repositories/backup_repository.dart';

part 'app_database.g.dart';

class TargetRows extends Table {
  TextColumn get id => text()();
  TextColumn get normalizedName => text().unique()();
  TextColumn get payload => text()();
  IntColumn get revision => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class DealRows extends Table {
  TextColumn get id => text()();
  TextColumn get payload => text()();
  TextColumn get lastRunId => text()();
  IntColumn get savings => integer()();
  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
  BoolColumn get dismissed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get firstSeen => dateTime()();
  DateTimeColumn get lastSeen => dateTime()();
  @override
  Set<Column> get primaryKey => {id};
}

class RunRows extends Table {
  TextColumn get id => text()();
  TextColumn get stage => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  IntColumn get scraped => integer().withDefault(const Constant(0))();
  IntColumn get deals => integer().withDefault(const Constant(0))();
  TextColumn get error => text().nullable()();
  TextColumn get auditReport => text().nullable()();
  TextColumn get configuration => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class ScanSnapshots extends Table {
  TextColumn get runId => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime()();
  @override
  Set<Column> get primaryKey => {runId};
}

class AppStateRows extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column> get primaryKey => {key};
}

class SyncJobRows extends Table {
  TextColumn get id => text()();
  TextColumn get payload => text()();
  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [
    TargetRows,
    DealRows,
    RunRows,
    ScanSnapshots,
    AppStateRows,
    SyncJobRows,
  ],
)
class AppDatabase extends _$AppDatabase
    implements
        TargetRepository,
        DealRepository,
        RunRepository,
        AppPreferencesRepository,
        SyncRepository,
        BackupRepository {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'deal_finder'));
  @override
  int get schemaVersion => 4;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(scanSnapshots);
        await m.createTable(appStateRows);
      }
      if (from < 3 && to >= 3) {
        await m.addColumn(runRows, runRows.configuration);
      }
      if (from < 4 && to >= 4) {
        await m.createTable(syncJobRows);
        // Existing values stay byte-for-byte intact. Decoding/validation remains
        // at the repository boundary, exactly as it was in AppStateRows.
        await customStatement(
          "INSERT INTO sync_job_rows (id, payload) "
          "SELECT substr(key, 9), value FROM app_state_rows "
          "WHERE key LIKE 'syncJob:%'",
        );
        await (delete(
          appStateRows,
        )..where((r) => r.key.like('syncJob:%'))).go();
      }
    },
  );

  Target _target(TargetRow row) => Target.fromJson({
    ...jsonDecode(row.payload) as Map<String, dynamic>,
    'revision': row.revision,
  });
  Deal _deal(DealRow row) => Deal.fromJson({
    ...jsonDecode(row.payload) as Map<String, dynamic>,
    'isFavorite': row.favorite,
    'isDismissed': row.dismissed,
    'firstSeen': row.firstSeen.toUtc().toIso8601String(),
    'lastSeen': row.lastSeen.toUtc().toIso8601String(),
  });
  @override
  Stream<List<Target>> watchTargets() =>
      (select(targetRows)..orderBy([(t) => OrderingTerm.asc(t.normalizedName)]))
          .watch()
          .map((rows) => rows.map(_target).toList());
  @override
  Future<List<Target>> loadTargets() async =>
      (await (select(
            targetRows,
          )..orderBy([(t) => OrderingTerm.asc(t.normalizedName)])).get())
          .map(_target)
          .toList();
  @override
  Future<void> saveTarget(Target target) => transaction(() async {
    final existing = await (select(
      targetRows,
    )..where((r) => r.id.equals(target.id))).getSingleOrNull();
    if (existing != null && existing.revision != target.revision) {
      throw StateError('This target changed. Reload it before saving.');
    }
    final duplicate =
        await (select(targetRows)..where(
              (r) =>
                  r.normalizedName.equals(target.name.toLowerCase()) &
                  r.id.equals(target.id).not(),
            ))
            .getSingleOrNull();
    if (duplicate != null) {
      throw StateError('A target with this name already exists.');
    }
    final now = DateTime.now().toUtc();
    await into(targetRows).insertOnConflictUpdate(
      TargetRowsCompanion.insert(
        id: target.id,
        normalizedName: target.name.toLowerCase(),
        payload: jsonEncode(target.toJson()),
        revision: Value((existing?.revision ?? -1) + 1),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  });
  @override
  Future<void> deleteTarget(String id) async {
    await (delete(targetRows)..where((r) => r.id.equals(id))).go();
  }

  @override
  Future<bool> hasCompletedOnboarding() async =>
      await (select(appStateRows)
            ..where((row) => row.key.equals('onboardingCompleted')))
          .getSingleOrNull() !=
      null;

  @override
  Future<void> completeOnboarding() => into(appStateRows)
      .insertOnConflictUpdate(
        AppStateRowsCompanion.insert(key: 'onboardingCompleted', value: 'true'),
      );

  @override
  Future<void> importTargets(
    List<Target> incoming,
    List<Target> expectedLocal,
  ) => transaction(() async {
    String signature(List<Target> targets) => jsonEncode(
      (List<Target>.of(
        targets,
      )..sort((a, b) => a.id.compareTo(b.id))).map((t) => t.toJson()).toList(),
    );
    if (signature(await loadTargets()) != signature(expectedLocal)) {
      throw StateError(
        'Local targets changed after the preview. Review the import again.',
      );
    }
    for (final target in incoming) {
      await saveTarget(target);
    }
  });

  @override
  Future<void> saveSyncJob(SyncJob job) async {
    await into(syncJobRows).insertOnConflictUpdate(
      SyncJobRowsCompanion.insert(
        id: job.id,
        payload: jsonEncode(job.toJson()),
      ),
    );
  }

  @override
  Stream<List<SyncJob>> watchSyncJobs() => select(syncJobRows).watch().map(
    (rows) =>
        rows
            .map(
              (r) => SyncJob.fromJson(
                jsonDecode(r.payload) as Map<String, dynamic>,
              ),
            )
            .toList()
          ..sort(
            (a, b) => b.snapshot.createdAt.compareTo(a.snapshot.createdAt),
          ),
  );

  @override
  Stream<List<Deal>> watchDeals() =>
      (select(dealRows)..orderBy([
            (r) => OrderingTerm.desc(r.savings),
            (r) => OrderingTerm.desc(r.lastSeen),
          ]))
          .watch()
          .map((rows) => rows.map(_deal).toList());
  @override
  Future<void> persistDeals(
    List<Deal> deals,
    String runId, {
    List<Listing> listings = const [],
    List<Target> targets = const [],
  }) => transaction(() async {
    final snapshot = RunSnapshot(
      runId: runId,
      createdAt: DateTime.now().toUtc(),
      deals: deals,
      listings: listings,
      targets: targets,
    );
    for (final deal in deals) {
      final old = await (select(
        dealRows,
      )..where((r) => r.id.equals(deal.id))).getSingleOrNull();
      await into(dealRows).insertOnConflictUpdate(
        DealRowsCompanion.insert(
          id: deal.id,
          payload: jsonEncode(deal.toJson()),
          lastRunId: runId,
          savings: deal.savings.centavos,
          favorite: Value(old?.favorite ?? deal.isFavorite),
          dismissed: Value(old?.dismissed ?? deal.isDismissed),
          firstSeen: old?.firstSeen ?? deal.firstSeen,
          lastSeen: deal.lastSeen,
        ),
      );
    }
    await into(scanSnapshots).insertOnConflictUpdate(
      ScanSnapshotsCompanion.insert(
        runId: runId,
        payload: jsonEncode(snapshot.toJson()),
        createdAt: snapshot.createdAt,
      ),
    );
    await into(appStateRows).insertOnConflictUpdate(
      AppStateRowsCompanion.insert(key: 'currentRun', value: runId),
    );
  });
  @override
  Stream<List<Deal>> watchCurrentDeals() =>
      (select(dealRows).join([
        innerJoin(
          appStateRows,
          appStateRows.key.equals('currentRun') &
              dealRows.lastRunId.equalsExp(appStateRows.value),
          useColumns: false,
        ),
      ])..orderBy([OrderingTerm.desc(dealRows.savings)])).watch().map(
        (rows) => rows.map((row) => _deal(row.readTable(dealRows))).toList(),
      );

  @override
  Future<RunSnapshot?> loadLatestSnapshot() async {
    final state = await (select(
      appStateRows,
    )..where((r) => r.key.equals('currentRun'))).getSingleOrNull();
    if (state == null) return null;
    final snapshot = await (select(
      scanSnapshots,
    )..where((r) => r.runId.equals(state.value))).getSingleOrNull();
    return snapshot == null
        ? null
        : RunSnapshot.fromJson(
            jsonDecode(snapshot.payload) as Map<String, dynamic>,
          );
  }

  @override
  Future<void> setDealFlags(
    String id, {
    bool? favorite,
    bool? dismissed,
  }) async {
    await (update(dealRows)..where((r) => r.id.equals(id))).write(
      DealRowsCompanion(
        favorite: favorite == null ? const Value.absent() : Value(favorite),
        dismissed: dismissed == null ? const Value.absent() : Value(dismissed),
      ),
    );
  }

  @override
  Stream<List<RunRecord>> watchRuns() =>
      (select(runRows)
            ..orderBy([(r) => OrderingTerm.desc(r.startedAt)])
            ..limit(100))
          .watch()
          .map(
            (rows) => rows
                .map(
                  (r) => RunRecord(
                    id: r.id,
                    startedAt: r.startedAt,
                    stage: r.stage,
                    finishedAt: r.finishedAt,
                    scraped: r.scraped,
                    deals: r.deals,
                    error: r.error,
                    auditReport: r.auditReport,
                    configuration: r.configuration == null
                        ? null
                        : RunConfiguration.decode(r.configuration!),
                  ),
                )
                .toList(),
          );
  @override
  Future<void> saveRun(RunRecord run) async {
    await into(runRows).insertOnConflictUpdate(
      RunRowsCompanion.insert(
        id: run.id,
        stage: run.stage,
        startedAt: run.startedAt,
        finishedAt: Value(run.finishedAt),
        scraped: Value(run.scraped),
        deals: Value(run.deals),
        error: Value(run.error),
        auditReport: Value(run.auditReport),
        configuration: Value(run.configuration?.encode()),
      ),
    );
  }

  @override
  Future<void> recoverInterruptedRuns() async {
    await (update(runRows)..where((r) => r.finishedAt.isNull())).write(
      RunRowsCompanion(
        stage: const Value('interrupted'),
        finishedAt: Value(DateTime.now().toUtc()),
        error: const Value('The app closed before this scan finished.'),
      ),
    );
  }

  // Only explicitly listed library fields cross this boundary. In particular,
  // never export arbitrary app state or platform secure storage.
  Future<Map<String, Object?>> _backupData() async {
    final targets = await (select(
      targetRows,
    )..orderBy([(r) => OrderingTerm.asc(r.id)])).get();
    final deals = await (select(
      dealRows,
    )..orderBy([(r) => OrderingTerm.asc(r.id)])).get();
    final runs = await (select(
      runRows,
    )..orderBy([(r) => OrderingTerm.asc(r.id)])).get();
    final snapshots = await (select(
      scanSnapshots,
    )..orderBy([(r) => OrderingTerm.asc(r.runId)])).get();
    final jobs = await (select(
      syncJobRows,
    )..orderBy([(r) => OrderingTerm.asc(r.id)])).get();
    final current = await (select(
      appStateRows,
    )..where((r) => r.key.equals('currentRun'))).getSingleOrNull();
    String utc(DateTime time) => time.toUtc().toIso8601String();
    return {
      'format': 'deal-finder-library',
      'version': BackupArchive.version,
      'databaseSchema': schemaVersion,
      'targets': targets
          .map(
            (r) => {
              'target': _target(r).toJson(),
              'createdAt': utc(r.createdAt),
              'updatedAt': utc(r.updatedAt),
            },
          )
          .toList(),
      'deals': deals
          .map((r) => {'deal': _deal(r).toJson(), 'lastRunId': r.lastRunId})
          .toList(),
      'runs': runs
          .map(
            (r) => {
              'id': r.id,
              'stage': r.stage,
              'startedAt': utc(r.startedAt),
              'finishedAt': r.finishedAt == null ? null : utc(r.finishedAt!),
              'scraped': r.scraped,
              'deals': r.deals,
              'error': r.error,
              'auditReport': r.auditReport,
              'configuration': r.configuration == null
                  ? null
                  : RunConfiguration.decode(r.configuration!).toJson(),
            },
          )
          .toList(),
      'snapshots': snapshots.map((r) => jsonDecode(r.payload)).toList(),
      'syncJobs': jobs.map((r) => jsonDecode(r.payload)).toList(),
      'currentRunId': current?.value,
    };
  }

  static String _fingerprint(Map<String, Object?> data) =>
      sha256.convert(utf8.encode(jsonEncode(data))).toString();

  @override
  Future<String> backupFingerprint() =>
      transaction(() async => _fingerprint(await _backupData()));

  @override
  Future<BackupArchive> exportBackup() => transaction(
    () async => BackupArchive.decode(
      jsonEncode({
        ...await _backupData(),
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      }),
    ),
  );

  @override
  Future<void> restoreBackup(
    BackupArchive archive, {
    required String expectedFingerprint,
  }) async {
    // Decode returns a fresh copy of the immutable, fully validated archive.
    final data = archive.toJson();
    final jobs = (data['syncJobs'] as List)
        .map((j) => SyncJob.fromJson(j as Map<String, dynamic>))
        .toList();
    for (final job in jobs) {
      if (_fingerprint(job.snapshot.toJson()) != job.payloadHash) {
        throw const FormatException(
          'Backup sync payload failed its integrity check. No data was replaced.',
        );
      }
    }
    await transaction(() async {
      if (_fingerprint(await _backupData()) != expectedFingerprint) {
        throw StateError(
          'Local data changed after the preview. Review the backup again.',
        );
      }
      await delete(targetRows).go();
      await delete(dealRows).go();
      await delete(runRows).go();
      await delete(scanSnapshots).go();
      await delete(syncJobRows).go();
      // Preserve unrelated local preferences/state; restored jobs are never
      // submitted automatically, and secure storage is outside this database.
      await (delete(
        appStateRows,
      )..where((r) => r.key.equals('currentRun'))).go();
      for (final raw in data['targets'] as List) {
        final row = raw as Map<String, dynamic>;
        final target = Target.fromJson(row['target'] as Map<String, dynamic>);
        await into(targetRows).insert(
          TargetRowsCompanion.insert(
            id: target.id,
            normalizedName: target.name.toLowerCase(),
            payload: jsonEncode(target.toJson()),
            revision: Value(target.revision),
            createdAt: DateTime.parse(row['createdAt'] as String),
            updatedAt: DateTime.parse(row['updatedAt'] as String),
          ),
        );
      }
      for (final raw in data['deals'] as List) {
        final row = raw as Map<String, dynamic>;
        final deal = Deal.fromJson(row['deal'] as Map<String, dynamic>);
        await into(dealRows).insert(
          DealRowsCompanion.insert(
            id: deal.id,
            payload: jsonEncode(deal.toJson()),
            lastRunId: row['lastRunId'] as String,
            savings: deal.savings.centavos,
            favorite: Value(deal.isFavorite),
            dismissed: Value(deal.isDismissed),
            firstSeen: deal.firstSeen,
            lastSeen: deal.lastSeen,
          ),
        );
      }
      for (final raw in data['runs'] as List) {
        final row = raw as Map<String, dynamic>;
        await saveRun(
          RunRecord(
            id: row['id'] as String,
            stage: row['stage'] as String,
            startedAt: DateTime.parse(row['startedAt'] as String),
            finishedAt: row['finishedAt'] == null
                ? null
                : DateTime.parse(row['finishedAt'] as String),
            scraped: row['scraped'] as int,
            deals: row['deals'] as int,
            error: row['error'] as String?,
            auditReport: row['auditReport'] as String?,
            configuration: row['configuration'] == null
                ? null
                : RunConfiguration.fromJson(row['configuration']),
          ),
        );
      }
      for (final raw in data['snapshots'] as List) {
        final snapshot = RunSnapshot.fromJson(raw as Map<String, dynamic>);
        await into(scanSnapshots).insert(
          ScanSnapshotsCompanion.insert(
            runId: snapshot.runId,
            payload: jsonEncode(snapshot.toJson()),
            createdAt: snapshot.createdAt,
          ),
        );
      }
      if (data['currentRunId'] != null) {
        await into(appStateRows).insert(
          AppStateRowsCompanion.insert(
            key: 'currentRun',
            value: data['currentRunId'] as String,
          ),
        );
      }
      for (final job in jobs) {
        await saveSyncJob(
          job.state == 'uploading'
              ? job.progress(
                  state: 'failed',
                  error: 'Sync was interrupted before this backup. Review before retrying.',
                )
              : job,
        );
      }
      await recoverInterruptedRuns();
    });
  }
}
