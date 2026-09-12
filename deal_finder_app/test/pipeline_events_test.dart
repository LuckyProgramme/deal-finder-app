import 'dart:convert';
import 'dart:async';

import 'package:deal_finder_app/src/application/pipeline/pipeline_controller.dart';
import 'package:deal_finder_app/src/application/pipeline/pipeline_ports.dart';
import 'package:deal_finder_app/src/data/local/app_database.dart';
import 'package:deal_finder_app/src/domain/models/scrape.dart';
import 'package:deal_finder_app/src/domain/models/target.dart';
import 'package:deal_finder_app/src/domain/models/listing.dart';
import 'package:deal_finder_app/src/domain/models/run_configuration.dart';
import 'package:deal_finder_app/src/features/diagnostics/diagnostics_dialog.dart';
import 'package:deal_finder_app/src/domain/matching/report_redaction.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pipeline_test.dart' show TerminalGateLibrary;
import 'support/fakes.dart';

class IncompleteMarketplace extends FakeMarketplace {
  IncompleteMarketplace({this.empty = false});
  final bool empty;
  @override
  Future<ScrapeBatchResult> scrape(
    targets,
    cancellation,
    progress, {
    int? limit,
  }) async {
    final source = planSources(targets).single;
    await progress(ScrapeSourceStarted(0, 1, source));
    final summary = ScrapeSourceSummary(
      source: source,
      fetched: empty ? 0 : 1,
      retained: empty ? 0 : 1,
      duration: const Duration(milliseconds: 42),
      failure: SourceFailure.parsing,
    );
    await progress(ScrapeSourceCompleted(0, 1, summary));
    return ScrapeBatchResult(empty ? [] : [sampleListing], [summary]);
  }
}

class PausedAuditor extends FakeAuditor {
  final ready = Completer<void>();
  @override
  AuditConfiguration get configuration => AuditConfiguration(
    model: 'fixture',
    endpointClass: 'fixture',
    chunkSize: 1,
    promptSha256: '0' * 64,
    schemaSha256: '1' * 64,
  );
  @override
  Future<AuditBatch> audit(candidates, cancellation, progress) async {
    await progress(const AuditingChunkStarted(0, 2, 0, 2));
    await progress(
      AuditingChunkCompleted(0, 2, 1, 2, {
        'chunk': 0,
        'attempts': 1,
        'httpStatus': 200,
      }),
    );
    await progress(const AuditingChunkStarted(1, 2, 1, 2));
    ready.complete();
    await cancellation.delay(const Duration(hours: 1));
    return AuditBatch([], {}, []);
  }
}

void main() {
  test(
    'source and audit checkpoints are durable before later work starts',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await db.saveTarget(sampleTarget);
      final auditor = PausedAuditor();
      final pipeline = PipelineController(
        targets: db,
        deals: db,
        runs: db,
        marketplace: FakeMarketplace(
          items: [
            sampleListing,
            Listing.fromJson({...sampleListing.toJson(), 'id': 'second'}),
          ],
        ),
        createAuditor: () async => auditor,
      );
      addTearDown(pipeline.dispose);
      final run = pipeline.start();
      await auditor.ready.future;
      final active = (await db.watchRuns().first).single;
      final report = jsonDecode(active.auditReport!);
      expect(active.stage, 'auditing');
      expect(active.finishedAt, isNull);
      expect(report['activeAuditChunk'], 1);
      expect(report['sources'].single['retained'], 2);
      expect(report['chunks'].single['httpStatus'], 200);
      pipeline.cancel();
      await run;
      final stopped = (await db.watchRuns().first).single;
      expect(stopped.stage, 'cancelled');
      expect(jsonDecode(stopped.auditReport!)['chunks'], hasLength(1));
    },
  );
  test('successful empty scan commits an empty feed rather than preserving stale current results', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db.saveTarget(sampleTarget);
    await db.persistDeals(
      [sampleDeal],
      'previous',
      listings: [sampleListing],
      targets: [sampleTarget],
    );
    final pipeline = PipelineController(
      targets: db,
      deals: db,
      runs: db,
      marketplace: FakeMarketplace(items: []),
      createAuditor: () async => FakeAuditor(),
    );
    addTearDown(pipeline.dispose);
    await pipeline.start();
    expect(pipeline.status.stage, RunStage.completed);
    expect((await db.loadLatestSnapshot())!.runId, isNot('previous'));
    expect(await db.watchCurrentDeals().first, isEmpty);
    expect(await db.watchDeals().first, hasLength(1));
  });

  test(
    'failure and cancellation emit distinct terminal events without completion',
    () async {
      final library = MemoryLibrary(targets: [sampleTarget]);
      addTearDown(library.dispose);
      final failure = PipelineController(
        targets: library,
        deals: library,
        runs: library,
        marketplace: FakeMarketplace(),
        createAuditor: () async => throw StateError('api_key=fixture-secret'),
      );
      final events = <PipelineEvent>[];
      final subscription = failure.events.listen(events.add);
      addTearDown(subscription.cancel);
      addTearDown(failure.dispose);
      await failure.start();
      await Future<void>.delayed(Duration.zero);
      expect(events.whereType<RunFailed>(), hasLength(1));
      expect(events.whereType<RunCompleted>(), isEmpty);
      expect(failure.status.message, isNot(contains('fixture-secret')));
      final cancel = fakePipeline(
        library,
        marketplace: FakeMarketplace(hold: true),
      );
      addTearDown(cancel.dispose);
      final stopped = <PipelineEvent>[];
      final cancellationEvents = cancel.events.listen(stopped.add);
      addTearDown(cancellationEvents.cancel);
      final run = cancel.start();
      cancel.cancel();
      await run;
      await Future<void>.delayed(Duration.zero);
      expect(stopped.whereType<RunCancelled>(), hasLength(1));
      expect(stopped.whereType<RunCompleted>(), isEmpty);
      expect(stopped.whereType<RunFailed>(), isEmpty);
    },
  );

  test('named events are ordered and completion follows durable terminal persistence', () async {
    final library = TerminalGateLibrary();
    final pipeline = fakePipeline(library, sync: (_, _) async {});
    final events = <PipelineEvent>[];
    final subscription = pipeline.events.listen(events.add);
    addTearDown(subscription.cancel);
    addTearDown(pipeline.dispose);
    addTearDown(library.dispose);
    final run = pipeline.start();
    await library.terminalStarted.future;
    await Future<void>.delayed(Duration.zero);
    expect(events.whereType<RunCompleted>(), isEmpty);
    expect(events.whereType<DealsPersisted>(), hasLength(1));
    library.finishTerminal.complete();
    await run;
    await Future<void>.delayed(Duration.zero);
    expect(
      events.where((e) => e is! PipelineProgress).map((e) => e.runtimeType),
      [
        RunStarted,
        TargetsLoaded,
        SourceStarted,
        SourceCompleted,
        CandidatesFiltered,
        AuditChunkStarted,
        AuditChunkCompleted,
        DealsPersisted,
        SheetsSyncCompleted,
        RunCompleted,
      ],
    );
    expect(events.map((e) => e.runId).toSet(), {library.runs.keys.single});
    expect(events.every((e) => e.timestamp.isUtc), isTrue);
    expect(events.whereType<RunCompleted>().single.published, isTrue);
    expect(
      events.whereType<SourceStarted>().single.status.currentTargetId,
      sampleTarget.id,
    );
    expect(
      events.whereType<AuditChunkStarted>().single.status.currentTargetId,
      isNull,
    );
  });

  for (final empty in [true, false]) {
    test(
      'incomplete source coverage (empty=$empty) preserves committed SQLite feed and skips Sheets',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        await db.saveTarget(sampleTarget);
        await db.persistDeals(
          [sampleDeal],
          'previous',
          listings: [sampleListing],
          targets: [sampleTarget],
        );
        await db.setDealFlags(sampleDeal.id, favorite: true);
        var synced = false;
        final pipeline = PipelineController(
          targets: db,
          deals: db,
          runs: db,
          marketplace: IncompleteMarketplace(empty: empty),
          createAuditor: () async => FakeAuditor(),
          syncResults: (_, _) async => synced = true,
        );
        addTearDown(pipeline.dispose);
        final events = <PipelineEvent>[];
        final subscription = pipeline.events.listen(events.add);
        addTearDown(subscription.cancel);
        await pipeline.start();
        await Future<void>.delayed(Duration.zero);
        expect((await db.loadLatestSnapshot())!.runId, 'previous');
        expect((await db.watchCurrentDeals().first).single.isFavorite, isTrue);
        expect(synced, isFalse);
        expect(pipeline.status.stage, RunStage.completedWithWarnings);
        expect(events.whereType<DealsPersisted>(), isEmpty);
        expect(events.whereType<RunCompleted>().single.published, isFalse);
        final report = jsonDecode(
          (await db.watchRuns().first).single.auditReport!,
        );
        expect(report['coverageComplete'], isFalse);
        expect(report['sources'].single['failure'], 'parsing');
        expect(report['published'], isFalse);
      },
    );
  }

  test(
    'configuration captures the initial selection and target policy',
    () async {
      final library = MemoryLibrary(targets: [sampleTarget]);
      final pipeline = fakePipeline(library);
      addTearDown(library.dispose);
      addTearDown(pipeline.dispose);
      final ids = {sampleTarget.id};
      final run = pipeline.start(targetIds: ids, limit: 7);
      ids.clear();
      await run;
      final config = jsonDecode(
        library.runs.values.single.auditReport!,
      )['configuration'];
      expect(config['limitPerSource'], 7);
      expect(
        config['targets'].single['dealPrice'],
        sampleTarget.dealPrice.centavos,
      );
      expect(config['auditor']['model'], 'fixture');
      expect(config['postRunSyncEnabled'], isFalse);
      expect(library.deals, hasLength(1));
    },
  );

  test('shared category source never invents a current target', () async {
    final other = Target.fromJson({
      ...sampleTarget.toJson(),
      'id': 'other',
      'name': 'Nintendo Switch Lite',
    });
    final library = MemoryLibrary(targets: [sampleTarget, other]);
    final pipeline = fakePipeline(library);
    final events = <PipelineEvent>[];
    final subscription = pipeline.events.listen(events.add);
    addTearDown(subscription.cancel);
    addTearDown(pipeline.dispose);
    addTearDown(library.dispose);
    await pipeline.start();
    await Future<void>.delayed(Duration.zero);
    final source = events.whereType<SourceStarted>().single;
    expect(source.status.sourceLabel, 'Video Gaming');
    expect(source.status.currentTargetId, isNull);
  });

  test('report redaction handles nested IDs without corrupting JSON or exposing file content', () {
    final data = {
      'api_key': 'structured-credential',
      'Authorization': 'structured-authorization',
      'unknown': ['buyer@example.com', '09171234567', 'api_key=private-value'],
      'nested': {
        'value':
            '-----BEGIN PRIVATE KEY-----\nfixture\n-----END PRIVATE KEY-----',
      },
      'price': 850000,
    };
    final output = safeReportExport(jsonEncode(data));
    expect(jsonDecode(output)['price'], 850000);
    for (final private in [
      'structured-credential',
      'structured-authorization',
      'buyer@example.com',
      '09171234567',
      'private-value',
      'fixture',
    ]) {
      expect(output, isNot(contains(private)));
    }
    expect(jsonDecode(safeReportExport('{bad private raw')), contains('error'));
    expect(
      safeReportExport('{bad private raw'),
      isNot(contains('private raw')),
    );
    final event = AuditChunkCompleted(
      const PipelineStatus(runId: 'run'),
      0,
      1,
      redactedReport(data) as Map<String, Object?>,
    );
    expect(
      () => (event.summary['unknown'] as List).clear(),
      throwsUnsupportedError,
    );
  });
  test(
    'report containers and escaping remain within persisted backup limits',
    () {
      final data = {
        'many': List.generate(3000, (_) => {'value': '\u0001' * 5000}),
      };
      final output = jsonEncode(redactedReport(data));
      expect(output.length, lessThan(1024 * 1024));
      expect(output, contains('truncated'));
      expect(jsonDecode(output), isA<Map>());
    },
  );
}
