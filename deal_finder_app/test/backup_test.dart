import 'dart:convert';

import 'package:deal_finder_app/src/application/backup/backup_coordinator.dart';
import 'package:deal_finder_app/src/application/pipeline/pipeline_controller.dart';
import 'package:deal_finder_app/src/application/sync/sync_coordinator.dart';
import 'package:deal_finder_app/src/data/local/app_database.dart';
import 'package:deal_finder_app/src/domain/models/backup_archive.dart';
import 'package:deal_finder_app/src/domain/models/target.dart';
import 'package:deal_finder_app/src/domain/repositories/repositories.dart';
import 'package:deal_finder_app/src/platform/files/backup_files.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  late AppDatabase source, destination;
  setUp(() {
    // Independent executors deliberately model two devices, never one file.
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    source = AppDatabase(NativeDatabase.memory());
    destination = AppDatabase(NativeDatabase.memory());
  });
  tearDown(() async {
    await source.close();
    await destination.close();
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = false;
  });

  Future<void> seed() async {
    await source.saveTarget(
      Target.fromJson({
        ...sampleTarget.toJson(),
        'allowBundle': true,
        'searchMode': 'itemName',
        'downsizingKeywords': ['rush'],
        'freebieKeywords': ['case'],
        'notes': 'Personal target',
      }),
    );
    await source.persistDeals(
      [sampleDeal],
      'first',
      listings: [sampleListing],
      targets: [sampleTarget],
    );
    await source.setDealFlags(sampleDeal.id, favorite: true, dismissed: true);
    final date = DateTime.utc(2026, 9, 10);
    await source.saveRun(
      RunRecord(
        id: 'first',
        startedAt: date,
        finishedAt: date,
        stage: 'completed',
        scraped: 1,
        deals: 1,
        auditReport: '{"count":1}',
      ),
    );
    await SyncCoordinator(source)
        .enqueue((await source.loadLatestSnapshot())!, 'a' * 30);
  }

  test('portable round trip preserves flags, snapshots, policies, revisions and outbox', () async {
    await seed();
    await source.saveTarget((await source.loadTargets()).single);
    final archive = BackupArchive.decode(
      (await source.exportBackup()).encode(),
    );
    final before = await destination.backupFingerprint();
    await destination.restoreBackup(archive, expectedFingerprint: before);
    expect(
      await destination.backupFingerprint(),
      await source.backupFingerprint(),
    );
    final deal = (await destination.watchDeals().first).single;
    expect(deal.isFavorite, isTrue);
    expect(deal.isDismissed, isTrue);
    expect(deal.firstSeen, sampleDeal.firstSeen);
    expect(deal.provenance.toJson(), sampleDeal.provenance.toJson());
    expect((await destination.loadTargets()).single.revision, 1);
    expect(await destination.watchCurrentDeals().first, hasLength(1));
    expect(
      (await destination.watchSyncJobs().first).single.payloadHash,
      (await source.watchSyncJobs().first).single.payloadHash,
    );
    expect(
      (await destination.watchRuns().first).single.auditReport,
      '{"count":1}',
    );
  });

  test('successful empty current snapshot and deleted-target history survive restore', () async {
    await seed();
    await source.deleteTarget(sampleTarget.id);
    await source.persistDeals([], 'empty');
    await destination.restoreBackup(
      await source.exportBackup(),
      expectedFingerprint: await destination.backupFingerprint(),
    );
    expect(await destination.loadTargets(), isEmpty);
    expect(await destination.watchCurrentDeals().first, isEmpty);
    expect(
      (await destination.watchDeals().first).single.target.id,
      sampleTarget.id,
    );
    expect((await destination.loadLatestSnapshot())!.runId, 'empty');
  });

  test('allowlist excludes arbitrary app state, and restore preserves local preferences', () async {
    await seed();
    await source
        .into(source.appStateRows)
        .insert(
          AppStateRowsCompanion.insert(
            key: 'geminiKey',
            value: 'fixture-secret-never-export',
          ),
        );
    await destination
        .into(destination.appStateRows)
        .insert(
          AppStateRowsCompanion.insert(
            key: 'localPreference',
            value: 'keep-me',
          ),
        );
    final backup = await source.exportBackup();
    expect(backup.encode(), isNot(contains('fixture-secret-never-export')));
    expect(backup.encode(), isNot(contains('geminiKey')));
    await destination.restoreBackup(
      backup,
      expectedFingerprint: await destination.backupFingerprint(),
    );
    final rows = await destination.select(destination.appStateRows).get();
    expect(
      rows.any((r) => r.key == 'localPreference' && r.value == 'keep-me'),
      isTrue,
    );
    expect(rows.any((r) => r.key == 'geminiKey'), isFalse);
  });

  test(
    'stale preview refuses replacement after flag, target or run edits',
    () async {
      await seed();
      final archive = await source.exportBackup();
      await destination.restoreBackup(
        archive,
        expectedFingerprint: await destination.backupFingerprint(),
      );
      for (final edit in <Future<void> Function()>[
        () => destination.setDealFlags(sampleDeal.id, favorite: false),
        () async =>
            destination.saveTarget((await destination.loadTargets()).single),
        () => destination.saveRun(
          RunRecord(
            id: 'new',
            startedAt: DateTime.now().toUtc(),
            stage: 'scraping',
          ),
        ),
      ]) {
        final stale = await destination.backupFingerprint();
        await edit();
        final changed = await destination.backupFingerprint();
        await expectLater(
          destination.restoreBackup(archive, expectedFingerprint: stale),
          throwsStateError,
        );
        expect(await destination.backupFingerprint(), changed);
      }
    },
  );

  test('SQLite failure after deletion rolls the entire library back', () async {
    await seed();
    await destination.saveTarget(
      Target.fromJson({...sampleTarget.toJson(), 'id': 'keep'}),
    );
    final before = await destination.backupFingerprint();
    await destination.customStatement(
      "CREATE TRIGGER reject_restore BEFORE INSERT ON deal_rows BEGIN SELECT RAISE(ABORT, 'fixture failure'); END",
    );
    await expectLater(
      destination.restoreBackup(
        await source.exportBackup(),
        expectedFingerprint: before,
      ),
      throwsA(anything),
    );
    expect(await destination.backupFingerprint(), before);
  });

  test('unfinished runs and uploading jobs become interrupted without automatic work', () async {
    await seed();
    await source.saveRun(
      RunRecord(
        id: 'active',
        startedAt: DateTime.utc(2026, 9, 9),
        stage: 'auditing',
      ),
    );
    final job = (await source.watchSyncJobs().first).single;
    await source.saveSyncJob(
      job.progress(state: 'uploading', completedTabs: {'History'}),
    );
    await destination.restoreBackup(
      await source.exportBackup(),
      expectedFingerprint: await destination.backupFingerprint(),
    );
    final run = (await destination.watchRuns().first).singleWhere(
      (r) => r.id == 'active',
    );
    expect(run.stage, 'interrupted');
    expect(run.finishedAt, isNotNull);
    final restored = (await destination.watchSyncJobs().first).single;
    expect(restored.state, 'failed');
    expect(restored.completedTabs, {'History'});
  });

  test('strict validation rejects malformed types, unsupported versions and inconsistencies', () async {
    await seed();
    final archive = await source.exportBackup();
    final mutations = <void Function(Map<String, dynamic>)>[
      (j) => j['version'] = 99,
      (j) => j['version'] = 1.0,
      (j) => j['databaseSchema'] = 99,
      (j) => j['credentials'] = {'geminiKey': 'fixture-secret'},
      (j) => j['currentRunId'] = 'missing-snapshot',
      (j) => j['deals'].clear(),
      (j) => j['targets'].add(j['targets'].first),
      (j) => j['targets'].first['target']['dealPrice'] = 1.5,
      (j) => j['targets'].first['target']['revision'] = -1,
      (j) => j['targets'].first['updatedAt'] = '2026-02-31T00:00:00.000Z',
      (j) => j['deals'].first['deal']['provenance']['score'] = 97,
      (j) => j['deals'].first['deal']['provenance']['confidence'] = 50,
      (j) => j['deals'].first['deal']['provenance'] = {
        'source': 'local_fallback',
        'score': 97,
      },
      (j) => j['deals'].first['deal']['listing']['sellerRating'] = 6,
      (j) => j['deals'].first['deal']['price'] = -100,
      (j) => j['deals'].first['deal']['isFavorite'] = 'true',
      (j) => j['snapshots'].first['runId'] = '',
      (j) => j['syncJobs'].first['destination'] = 'https://evil.example',
      (j) => j['syncJobs'].first['completedTabs'] = ['Price List'],
    ];
    for (final mutate in mutations) {
      final data = archive.toJson();
      mutate(data);
      expect(
        () => BackupArchive.decode(jsonEncode(data)),
        throwsFormatException,
      );
    }
    final data = archive.toJson();
    data['targets'].clear();
    expect(
      archive.counts['targets'],
      1,
      reason: 'Validated preview is immutable',
    );
    expect(archive.toJson()['targets'], hasLength(1));
  });

  test(
    'tampered sync hash is rejected before transactional replacement',
    () async {
      await seed();
      final data = (await source.exportBackup()).toJson();
      data['syncJobs'].first['payloadHash'] = '0' * 64;
      final before = await destination.backupFingerprint();
      await expectLater(
        destination.restoreBackup(
          BackupArchive.decode(jsonEncode(data)),
          expectedFingerprint: before,
        ),
        throwsFormatException,
      );
      expect(await destination.backupFingerprint(), before);
    },
  );

  test(
    'parsing bounds depth, bytes, list counts and never echoes file contents',
    () {
      for (final text in [
        '["fixture-secret",',
        '${'[' * 25}0${']' * 25}',
        ' ' * (BackupArchive.maxBytes + 1),
      ]) {
        try {
          BackupArchive.decode(text);
          fail('Expected invalid backup');
        } on FormatException catch (error) {
          expect(error.toString(), isNot(contains('fixture-secret')));
        }
      }
    },
  );

  test(
    'duplicate JSON keys including escaped spellings are rejected',
    () async {
      final archive = await source.exportBackup();
      for (final duplicate in ['"version":1,', '"vers\\u0069on":1,']) {
        expect(
          () => BackupArchive.decode(
            '{$duplicate${archive.encode().substring(1)}',
          ),
          throwsFormatException,
        );
      }
    },
  );

  test('file read enforces actual byte bounds and strict UTF-8', () async {
    expect(
      await readBackupText(
        Stream.fromIterable([utf8.encode('backup '), utf8.encode('₱')]),
      ),
      'backup ₱',
    );
    await expectLater(
      readBackupText(Stream.value([0xff])),
      throwsFormatException,
    );
    await expectLater(
      readBackupText(Stream.value(List.filled(BackupArchive.maxBytes + 1, 0))),
      throwsFormatException,
    );
  });

  test('active scan refuses maintenance until cancellation finishes', () async {
    final memory = MemoryLibrary(targets: [sampleTarget]);
    final pipeline = fakePipeline(
      memory,
      marketplace: FakeMarketplace(hold: true),
    );
    addTearDown(memory.dispose);
    addTearDown(pipeline.dispose);
    final scraping = pipeline.events.firstWhere(
      (e) => e.status.stage == RunStage.scraping,
    );
    final run = pipeline.start();
    await scraping;
    expect(pipeline.acquireMaintenance, throwsStateError);
    pipeline.cancel();
    await run;
    final lease = pipeline.acquireMaintenance();
    pipeline.releaseMaintenance(lease);
  });

  test('maintenance excludes scan and Sheets operations and releases after failure', () async {
    final memory = MemoryLibrary();
    final pipeline = fakePipeline(memory);
    final sync = SyncCoordinator(source);
    final coordinator = BackupCoordinator(source, pipeline, sync);
    addTearDown(memory.dispose);
    addTearDown(pipeline.dispose);
    await expectLater(
      coordinator.exclusive<void>((_) async {
        expect(await pipeline.start(), RunStartResult.maintenanceInProgress);
        expect(sync.acquire, throwsStateError);
        throw StateError('fixture failure');
      }),
      throwsStateError,
    );
    expect(pipeline.busy, isFalse);
    expect(sync.busy, isFalse);
    final lease = sync.acquire();
    await expectLater(
      coordinator.exclusive<void>((_) async {}),
      throwsStateError,
    );
    expect(pipeline.busy, isFalse);
    sync.release(lease);
    final maintenance = pipeline.acquireMaintenance();
    await expectLater(
      coordinator.exclusive<void>((_) async {}),
      throwsStateError,
    );
    pipeline.releaseMaintenance(maintenance);
  });
}
