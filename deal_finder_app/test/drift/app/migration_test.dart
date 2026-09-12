// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:deal_finder_app/src/data/local/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:convert';

import '../../support/fakes.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  // The following template shows how to write tests ensuring your migrations
  // preserve existing data.
  // Testing this can be useful for migrations that change existing columns
  // (e.g. by alterating their type or constraints). Migrations that only add
  // tables or columns typically don't need these advanced tests. For more
  // information, see https://drift.simonbinder.eu/migrations/tests/#verifying-data-integrity
  test('migration from v1 to v2 does not corrupt data', () async {
    // Add data to insert into the old database, and the expected rows after the
    // migration.
    final target = {
      'id': sampleTarget.id,
      'normalizedName': sampleTarget.name.toLowerCase(),
      'payload': jsonEncode(sampleTarget.toJson()),
      'revision': 7,
      'createdAt': 1700000000,
      'updatedAt': 1700000100,
    };
    final oldTargetRowsData = [v1.TargetRowsData.fromJson(target)];
    final expectedNewTargetRowsData = [v2.TargetRowsData.fromJson(target)];

    final deal = {
      'id': sampleDeal.id,
      'payload': jsonEncode(sampleDeal.toJson()),
      'lastRunId': 'saved-run',
      'savings': sampleDeal.savings.centavos,
      'favorite': 1,
      'dismissed': 1,
      'firstSeen': 1700000000,
      'lastSeen': 1700000100,
    };
    final oldDealRowsData = [v1.DealRowsData.fromJson(deal)];
    final expectedNewDealRowsData = [v2.DealRowsData.fromJson(deal)];

    final run = {
      'id': 'saved-run',
      'stage': 'completed',
      'startedAt': 1700000000,
      'finishedAt': 1700000100,
      'scraped': 22,
      'deals': 1,
      'error': null,
      'auditReport': '{"confirmed":1}',
    };
    final oldRunRowsData = [v1.RunRowsData.fromJson(run)];
    final expectedNewRunRowsData = [v2.RunRowsData.fromJson(run)];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.targetRows, oldTargetRowsData);
        batch.insertAll(oldDb.dealRows, oldDealRowsData);
        batch.insertAll(oldDb.runRows, oldRunRowsData);
      },
      validateItems: (newDb) async {
        expect(
          expectedNewTargetRowsData,
          await newDb.select(newDb.targetRows).get(),
        );
        expect(
          expectedNewDealRowsData,
          await newDb.select(newDb.dealRows).get(),
        );
        expect(expectedNewRunRowsData, await newDb.select(newDb.runRows).get());
      },
    );
  });

  test(
    'v2 to v3 retains library, outbox and reports without inventing config',
    () async {
      final target = {
        'id': sampleTarget.id,
        'normalizedName': sampleTarget.name.toLowerCase(),
        'payload': jsonEncode(sampleTarget.toJson()),
        'revision': 7,
        'createdAt': 1700000000,
        'updatedAt': 1700000100,
      };
      final deal = {
        'id': sampleDeal.id,
        'payload': jsonEncode(sampleDeal.toJson()),
        'lastRunId': 'saved-run',
        'savings': sampleDeal.savings.centavos,
        'favorite': 1,
        'dismissed': 1,
        'firstSeen': 1700000000,
        'lastSeen': 1700000100,
      };
      final run = {
        'id': 'saved-run',
        'stage': 'completed',
        'startedAt': 1700000000,
        'finishedAt': 1700000100,
        'scraped': 22,
        'deals': 1,
        'error': null,
        'auditReport': '{"configuration":{"model":"old-diagnostic-only"}}',
      };
      final snapshot = {
        'runId': 'saved-run',
        'createdAt': 1700000100,
        'payload': jsonEncode({
          'runId': 'saved-run',
          'createdAt': DateTime.utc(2023, 11, 14).toIso8601String(),
          'deals': [sampleDeal.toJson()],
          'listings': [sampleListing.toJson()],
          'targets': [sampleTarget.toJson()],
        }),
      };
      final state = [
        {'key': 'currentRun', 'value': 'saved-run'},
        {
          'key': 'syncJob:saved-run',
          'value': '{"checkpoint":"preserve-verbatim"}',
        },
        {'key': 'localPreference', 'value': 'keep-me'},
      ];
      await verifier.testWithDataIntegrity(
        oldVersion: 2,
        newVersion: 3,
        createOld: v2.DatabaseAtV2.new,
        createNew: v3.DatabaseAtV3.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) {
          batch.insertAll(oldDb.targetRows, [
            v2.TargetRowsData.fromJson(target),
          ]);
          batch.insertAll(oldDb.dealRows, [v2.DealRowsData.fromJson(deal)]);
          batch.insertAll(oldDb.runRows, [v2.RunRowsData.fromJson(run)]);
          batch.insertAll(oldDb.scanSnapshots, [
            v2.ScanSnapshotsData.fromJson(snapshot),
          ]);
          batch.insertAll(
            oldDb.appStateRows,
            state.map(v2.AppStateRowsData.fromJson),
          );
        },
        validateItems: (newDb) async {
          expect(await newDb.select(newDb.targetRows).get(), [
            v3.TargetRowsData.fromJson(target),
          ]);
          expect(await newDb.select(newDb.dealRows).get(), [
            v3.DealRowsData.fromJson(deal),
          ]);
          expect(await newDb.select(newDb.runRows).get(), [
            v3.RunRowsData.fromJson({...run, 'configuration': null}),
          ]);
          expect(await newDb.select(newDb.scanSnapshots).get(), [
            v3.ScanSnapshotsData.fromJson(snapshot),
          ]);
          expect(
            await newDb.select(newDb.appStateRows).get(),
            unorderedEquals(state.map(v3.AppStateRowsData.fromJson)),
          );
        },
      );
    },
  );

  String syncPayload() => jsonEncode({
    'id': 'saved-run:${'a' * 30}',
    'destination': 'a' * 30,
    'snapshot': {
      'runId': 'saved-run',
      'createdAt': DateTime.utc(2026, 9, 11).toIso8601String(),
      'deals': [sampleDeal.toJson()],
      'listings': [sampleListing.toJson()],
      'targets': [sampleTarget.toJson()],
    },
    'payloadHash': 'b' * 64,
    'attempts': 2,
    'state': 'failed',
    'error': 'Retry explicitly',
    'completedTabs': ['History'],
  });

  test(
    'v3 to v4 moves outbox verbatim and preserves unrelated state',
    () async {
      final payload = syncPayload();
      final oldState = [
        const v3.AppStateRowsData(key: 'currentRun', value: 'saved-run'),
        v3.AppStateRowsData(
          key: 'syncJob:saved-run:${'a' * 30}',
          value: payload,
        ),
        const v3.AppStateRowsData(key: 'localPreference', value: 'keep-me'),
      ];
      await verifier.testWithDataIntegrity(
        oldVersion: 3,
        newVersion: 4,
        createOld: v3.DatabaseAtV3.new,
        createNew: v4.DatabaseAtV4.new,
        openTestedDatabase: AppDatabase.new,
        createItems: (batch, oldDb) =>
            batch.insertAll(oldDb.appStateRows, oldState),
        validateItems: (newDb) async {
          expect(
            await newDb.select(newDb.appStateRows).get(),
            unorderedEquals([
              const v4.AppStateRowsData(key: 'currentRun', value: 'saved-run'),
              const v4.AppStateRowsData(
                key: 'localPreference',
                value: 'keep-me',
              ),
            ]),
          );
          expect(await newDb.select(newDb.syncJobRows).get(), [
            v4.SyncJobRowsData(id: 'saved-run:${'a' * 30}', payload: payload),
          ]);
        },
      );
    },
  );

  test('v2 to v4 applies both configuration and outbox migrations', () async {
    final payload = syncPayload();
    final run = v2.RunRowsData.fromJson({
      'id': 'saved-run',
      'stage': 'completed',
      'startedAt': 1700000000,
      'finishedAt': 1700000100,
      'scraped': 22,
      'deals': 1,
      'error': null,
      'auditReport': '{"confirmed":1}',
    });
    await verifier.testWithDataIntegrity(
      oldVersion: 2,
      newVersion: 4,
      createOld: v2.DatabaseAtV2.new,
      createNew: v4.DatabaseAtV4.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insert(oldDb.runRows, run);
        batch.insertAll(oldDb.appStateRows, [
          v2.AppStateRowsData(
            key: 'syncJob:saved-run:${'a' * 30}',
            value: payload,
          ),
          const v2.AppStateRowsData(key: 'localPreference', value: 'keep-me'),
        ]);
      },
      validateItems: (newDb) async {
        expect((await newDb.select(newDb.runRows).get()).single.configuration, null);
        expect(await newDb.select(newDb.appStateRows).get(), [
          const v4.AppStateRowsData(key: 'localPreference', value: 'keep-me'),
        ]);
        expect(await newDb.select(newDb.syncJobRows).get(), [
          v4.SyncJobRowsData(id: 'saved-run:${'a' * 30}', payload: payload),
        ]);
      },
    );
  });
}
