import 'dart:convert';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:deal_finder_app/src/application/pipeline/pipeline_controller.dart';
import 'package:deal_finder_app/src/domain/repositories/repositories.dart';

import 'support/fakes.dart';

class TerminalGateLibrary extends MemoryLibrary {
  TerminalGateLibrary() : super(targets: [sampleTarget]);
  final terminalStarted = Completer<void>(), finishTerminal = Completer<void>();
  @override
  Future<void> saveRun(RunRecord run) async {
    if (run.finishedAt != null && !terminalStarted.isCompleted) {
      terminalStarted.complete();
      await finishTerminal.future;
    }
    await super.saveRun(run);
  }
}

void main() {
  late MemoryLibrary library;
  setUp(() => library = MemoryLibrary(targets: [sampleTarget]));
  tearDown(() => library.dispose());
  test('run lock stays held until terminal persistence finishes', () async {
    final gated = TerminalGateLibrary();
    final pipeline = fakePipeline(gated);
    addTearDown(gated.dispose);
    addTearDown(pipeline.dispose);
    final first = pipeline.start();
    await gated.terminalStarted.future;
    expect(pipeline.status.stage, RunStage.completed);
    expect(await pipeline.start(), RunStartResult.alreadyRunning);
    gated.finishTerminal.complete();
    expect(await first, RunStartResult.accepted);
    expect(await pipeline.start(), RunStartResult.accepted);
    expect(gated.runs, hasLength(2));
  });
  test('a normal scan saves Gemini deals and a terminal report', () async {
    final pipeline = fakePipeline(library);
    addTearDown(pipeline.dispose);
    final stages = <RunStage>[];
    final subscription = pipeline.events.listen(
      (event) => stages.add(event.status.stage),
    );
    addTearDown(subscription.cancel);
    await pipeline.start();
    await Future<void>.delayed(Duration.zero);
    expect(pipeline.status.stage, RunStage.completed);
    expect(library.deals.single.id, sampleListing.id);
    expect(library.runs.values.single.finishedAt, isNotNull);
    expect(
      stages,
      containsAllInOrder([
        RunStage.preparing,
        RunStage.scraping,
        RunStage.filtering,
        RunStage.auditing,
        RunStage.persisting,
        RunStage.completed,
      ]),
    );
    expect(
      library.runs.values.single.auditReport,
      isNot(contains(sampleListing.description)),
    );
  });
  test(
    'failed audits do not publish lexical fallback in normal mode',
    () async {
      final pipeline = fakePipeline(library, auditor: FakeAuditor(fail: true));
      addTearDown(pipeline.dispose);
      await pipeline.start();
      expect(library.deals, isEmpty);
      expect(
        jsonDecode(library.runs.values.single.auditReport!)['localFallback'],
        0,
      );
    },
  );
  test('Audit Mode records fallback without publishing or syncing', () async {
    var synced = false;
    final pipeline = fakePipeline(
      library,
      auditor: FakeAuditor(fail: true),
      sync: (_, _) async {
        synced = true;
      },
    );
    addTearDown(pipeline.dispose);
    await pipeline.start(auditMode: true);
    expect(library.deals, isEmpty);
    expect(synced, isFalse);
    expect(
      jsonDecode(library.runs.values.single.auditReport!)['localFallback'],
      1,
    );
  });
  test('negative Gemini decisions never become fallback deals', () async {
    final pipeline = fakePipeline(library, auditor: FakeAuditor(reject: true));
    addTearDown(pipeline.dispose);
    await pipeline.start(auditMode: true);
    expect(
      jsonDecode(library.runs.values.single.auditReport!)['localFallback'],
      0,
    );
  });
  test(
    'only one run starts and cancellation reaches a terminal record',
    () async {
      final pipeline = fakePipeline(
        library,
        marketplace: FakeMarketplace(hold: true),
      );
      addTearDown(pipeline.dispose);
      final run = pipeline.start();
      expect(await pipeline.start(), RunStartResult.alreadyRunning);
      pipeline.cancel();
      await run;
      expect(pipeline.status.stage, RunStage.cancelled);
      expect(library.deals, isEmpty);
      expect(library.runs.values.single.finishedAt, isNotNull);
    },
  );
  test('a Sheets failure never rolls back successfully saved deals', () async {
    final pipeline = fakePipeline(
      library,
      sync: (_, _) async => throw StateError('offline'),
    );
    addTearDown(pipeline.dispose);
    await pipeline.start();
    expect(library.deals, hasLength(1));
    expect(pipeline.status.message, contains('Sheets sync needs attention'));
  });
}
