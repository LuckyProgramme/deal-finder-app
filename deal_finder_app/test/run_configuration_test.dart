import 'dart:convert';

import 'package:deal_finder_app/src/application/pipeline/pipeline_controller.dart';
import 'package:deal_finder_app/src/data/local/app_database.dart';
import 'package:deal_finder_app/src/domain/matching/report_redaction.dart';
import 'package:deal_finder_app/src/domain/models/backup_archive.dart';
import 'package:deal_finder_app/src/domain/models/run_configuration.dart';
import 'package:deal_finder_app/src/domain/models/target.dart';
import 'package:deal_finder_app/src/domain/repositories/repositories.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

List<Target> largePolicy() => List.generate(
  120,
  (i) => Target.fromJson({
    ...sampleTarget.toJson(),
    'id': 'target-$i',
    'name': 'Nintendo Switch edition $i',
    'downsizingKeywords': ['rush $i ${'x' * 1000}'],
    'freebieKeywords': ['case $i ${'y' * 1000}'],
    'notes': 'NON_EXECUTION_NOTE_NEVER_IN_CONFIGURATION',
    'revision': i,
  }),
);

RunConfiguration captured({List<Target>? targets}) => RunConfiguration(
  auditMode: false,
  requestedTargetIds: (targets ?? [sampleTarget]).map((t) => t.id),
  targets: targets ?? [sampleTarget],
  limitPerSource: 7,
  auditor: FakeAuditor().configuration,
  postRunSyncEnabled: true,
);

void main() {
  test(
    'exact large policy survives independently of truncated diagnostics',
    () {
      final targets = largePolicy();
      final config = captured(targets: targets);
      final before = config.encode();
      expect(before.length, greaterThan(65536));
      expect(before, isNot(contains('NON_EXECUTION_NOTE')));
      final restored = RunConfiguration.decode(before);
      expect(restored.encode(), before);
      expect(
        restored.targets!.last.freebieKeywords,
        targets.last.freebieKeywords,
      );
      expect(restored.targets!.last.revision, 119);
      final report = jsonEncode(redactedReport(config.toJson()));
      expect(report, contains('truncated'));
      expect(config.encode(), before);
      targets.clear();
      config.toJson()['targets'].clear();
      expect(config.targets, hasLength(120));
      expect(() => config.targets!.clear(), throwsUnsupportedError);
      expect(
        () => config.targets!.first.freebieKeywords.clear(),
        throwsUnsupportedError,
      );
      expect(() => config.requestedTargetIds!.clear(), throwsUnsupportedError);
    },
  );

  test('request-only, resolved-empty and legacy-missing are distinct', () {
    final pending = RunConfiguration(auditMode: false, requestedTargetIds: []);
    expect(pending.targets, isNull);
    expect(pending.auditor, isNull);
    expect(pending.postRunSyncEnabled, isNull);
    expect(pending.requestedTargetIds, isEmpty);
    final empty = pending.withResolved(targets: []);
    expect(empty.targets, isEmpty);
    expect(empty.encode(), isNot(pending.encode()));
    expect(RunConfiguration.decode(empty.encode()).targets, isEmpty);
    expect(
      RunRecord(
        id: 'old',
        startedAt: DateTime.utc(2026, 9, 11),
        stage: 'completed',
      ).configuration,
      isNull,
    );
  });

  test(
    'credential-free allowlist rejects malformed or injected configuration',
    () {
      final base = captured().toJson();
      final mutations = <void Function(Map<String, dynamic>)>[
        (j) => j['apiKey'] = 'sensitive-fixture',
        (j) => (j['auditor'] as Map)['key'] = 'sensitive-fixture',
        (j) => (j['auditor'] as Map)['promptSha256'] = 'invalid',
        (j) => (j['auditor'] as Map)['chunkSize'] = 0,
        (j) => j['version'] = 1.0,
        (j) => j['version'] = 99,
        (j) => j['auditMode'] = 'false',
        (j) => j['auditMode'] = true,
        (j) => j['requestedTargetIds'] = ['different'],
        (j) => j['requestedTargetIds'] = [sampleTarget.id, sampleTarget.id],
        (j) => j['targets'].add(j['targets'].first),
        (j) => j['targets'].first['enabled'] = false,
        (j) => j['targets'].first['notes'] = 'sensitive-fixture',
        (j) => j['targets'].first['revision'] = -1,
        (j) => j['targets'].first['dealPrice'] = 1.25,
        (j) => j['targets'].first['freebieKeywords'] = [false],
        (j) => j['limitPerSource'] = 0,
      ];
      for (final mutate in mutations) {
        final j = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
        mutate(j);
        expect(
          () => RunConfiguration.decode(jsonEncode(j)),
          throwsA(
            isA<FormatException>().having(
              (e) => e.message,
              'safe message',
              'Invalid scan configuration.',
            ),
          ),
        );
      }
      for (final prefix in ['"version":1,', '"vers\\u0069on":1,']) {
        expect(
          () => RunConfiguration.decode(
            '{$prefix${captured().encode().substring(1)}',
          ),
          throwsFormatException,
        );
      }
      expect(
        () => RunConfiguration.decode('${'[' * 25}0${']' * 25}'),
        throwsFormatException,
      );
      expect(
        () => RunConfiguration.decode('x' * (RunConfiguration.maxBytes + 1)),
        throwsFormatException,
      );
    },
  );

  test(
    'SQLite, backup and restore preserve the entire configuration',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final config = captured(targets: largePolicy());
      final time = DateTime.utc(2026, 9, 11);
      await db.saveRun(
        RunRecord(
          id: 'large',
          startedAt: time,
          finishedAt: time,
          stage: 'completed',
          configuration: config,
          auditReport: jsonEncode(redactedReport(config.toJson())),
        ),
      );
      final archive = await db.exportBackup();
      expect(archive.toJson()['version'], 2);
      expect(archive.toJson()['databaseSchema'], 4);
      expect(
        archive.toJson()['runs'].single['configuration']['targets'],
        hasLength(120),
      );
      await db.delete(db.runRows).go();
      await db.restoreBackup(
        archive,
        expectedFingerprint: await db.backupFingerprint(),
      );
      final restored = (await db.watchRuns().first).single;
      expect(restored.configuration!.encode(), config.encode());
      expect(restored.auditReport, contains('truncated'));
    },
  );

  test(
    'version-1 backups upgrade without guessing historical configuration',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.saveTarget(sampleTarget);
      await db.persistDeals([sampleDeal], 'legacy', targets: [sampleTarget]);
      await db.setDealFlags(sampleDeal.id, favorite: true);
      final time = DateTime.utc(2026, 9, 11);
      await db.saveRun(
        RunRecord(
          id: 'legacy',
          startedAt: time,
          finishedAt: time,
          stage: 'completed',
        ),
      );
      final old = (await db.exportBackup()).toJson()
        ..['version'] = 1
        ..['databaseSchema'] = 2;
      for (final run in old['runs']) {
        (run as Map).remove('configuration');
      }
      final upgraded = BackupArchive.decode(jsonEncode(old));
      expect(upgraded.toJson()['version'], 2);
      expect(upgraded.toJson()['runs'].single['configuration'], isNull);
      await db.restoreBackup(
        upgraded,
        expectedFingerprint: await db.backupFingerprint(),
      );
      expect((await db.watchRuns().first).single.configuration, isNull);
      expect((await db.watchCurrentDeals().first).single.isFavorite, isTrue);
    },
  );

  test(
    'invalid backup configuration is rejected before any replacement',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final time = DateTime.utc(2026, 9, 11);
      await db.saveRun(
        RunRecord(
          id: 'run',
          startedAt: time,
          finishedAt: time,
          stage: 'completed',
          configuration: captured(),
        ),
      );
      final before = await db.backupFingerprint();
      final bad = (await db.exportBackup()).toJson();
      bad['runs'].single['configuration']['auditor']['apiKey'] =
          'sensitive-fixture';
      expect(
        () => BackupArchive.decode(jsonEncode(bad)),
        throwsFormatException,
      );
      expect(await db.backupFingerprint(), before);
    },
  );

  test(
    'failed preparation keeps selected target policy without resolved auditor',
    () async {
      final library = MemoryLibrary(targets: [sampleTarget]);
      final pipeline = PipelineController(
        targets: library,
        deals: library,
        runs: library,
        marketplace: FakeMarketplace(),
        createAuditor: () async => throw StateError('Missing credentials.'),
      );
      addTearDown(library.dispose);
      addTearDown(pipeline.dispose);
      final ids = {sampleTarget.id};
      final run = pipeline.start(targetIds: ids, limit: 11);
      ids.clear();
      await run;
      final recorded = library.runs.values.single;
      expect(recorded.stage, 'failed');
      expect(
        recorded.configuration!.targets!.single.toJson(),
        sampleTarget.toJson(),
      );
      expect(recorded.configuration!.requestedTargetIds, {sampleTarget.id});
      expect(recorded.configuration!.limitPerSource, 11);
      expect(recorded.configuration!.auditor, isNull);
      expect(recorded.configuration!.postRunSyncEnabled, isNull);
    },
  );

  test(
    'cancellation and later target edits retain the initial SQLite policy',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.saveTarget(sampleTarget);
      final pipeline = PipelineController(
        targets: db,
        deals: db,
        runs: db,
        marketplace: FakeMarketplace(hold: true),
        createAuditor: () async => FakeAuditor(),
      );
      addTearDown(pipeline.dispose);
      final started = pipeline.events.firstWhere((e) => e is SourceStarted);
      final running = pipeline.start();
      await started;
      await db.saveTarget(
        Target.fromJson({...sampleTarget.toJson(), 'dealPrice': 2000000}),
      );
      pipeline.cancel();
      await running;
      final recorded = (await db.watchRuns().first).single;
      expect(recorded.stage, 'cancelled');
      expect(
        recorded.configuration!.targets!.single.dealPrice,
        sampleTarget.dealPrice,
      );
      expect(recorded.configuration!.targets!.single.revision, 0);
      expect(recorded.configuration!.auditor!.model, 'fixture');
      expect(recorded.configuration!.postRunSyncEnabled, isFalse);
      expect(pipeline.busy, isFalse);
    },
  );
}
