import 'dart:convert';

import 'package:deal_finder_app/src/application/pipeline/cancellation.dart';
import 'package:deal_finder_app/src/application/pipeline/pipeline_ports.dart';
import 'package:deal_finder_app/src/data/carousell/carousell_service.dart';
import 'package:deal_finder_app/src/data/gemini/gemini_service.dart';
import 'package:deal_finder_app/src/domain/matching/candidate_filter.dart';
import 'package:deal_finder_app/src/domain/models/target.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'adapters_test.dart' show FixtureAdapter;
import 'support/fakes.dart';

String page(List<Map<String, Object?>> cards) =>
    '<script type="application/json">${jsonEncode({'listingCards': cards})}</script>';
Map<String, Object?> card(
  String id, {
  String description = 'Working console',
}) => {
  'id': id,
  'title': 'Nintendo Switch OLED',
  'price': '8500',
  'url': 'https://www.carousell.ph/p/console-$id/',
  'description': description,
};

void main() {
  test('source failures are isolated, measured and never masquerade as empty success', () async {
    final phone = Target.fromJson({
      ...sampleTarget.toJson(),
      'id': 'phone',
      'name': 'Pixel 9',
      'category': 'Mobile Phones',
    });
    final requests = <String>[];
    final client = Dio()
      ..httpClientAdapter = FixtureAdapter((request, _) async {
        requests.add(request.path);
        return request.path.contains('mobile-phones')
            ? ResponseBody.fromString('PRIVATE FAILURE BODY', 403)
            : ResponseBody.fromString(page([card('1'), card('2')]), 200);
      });
    addTearDown(() => client.close(force: true));
    final events = <ScrapeProgress>[];
    final result = await CarousellService(
      client,
      pacing: Duration.zero,
    ).scrape([phone, sampleTarget], Cancellation(), events.add, limit: 1);
    expect(requests, hasLength(2));
    expect(result.complete, isFalse);
    expect(result.sources.first.failure, SourceFailure.http);
    expect(result.sources.first.httpStatus, 403);
    expect(result.sources.first.retained, 0);
    expect(result.sources.last.fetched, 2);
    expect(result.sources.last.retained, 1);
    expect(result.sources.last.duration.isNegative, isFalse);
    expect(result.listings.single.id, '1');
    expect(events.map((e) => e.runtimeType), [
      ScrapeSourceStarted,
      ScrapeSourceCompleted,
      ScrapeSourceStarted,
      ScrapeSourceCompleted,
    ]);
    expect(
      jsonEncode(result.sources.map((s) => s.toJson()).toList()),
      isNot(contains('PRIVATE FAILURE BODY')),
    );
  });

  test(
    'recognized empty listings differs from blocked or malformed markup',
    () async {
      final client = Dio()
        ..httpClientAdapter = FixtureAdapter(
          (request, _) async => ResponseBody.fromString(page([]), 200),
        );
      addTearDown(() => client.close(force: true));
      final empty = await CarousellService(client)
          .scrape([sampleTarget], Cancellation(), (_) {});
      expect(empty.complete, isTrue);
      expect(empty.listings, isEmpty);
      expect(
        () => parseListings('<h1>Sign in to continue</h1>'),
        throwsFormatException,
      );
      expect(
        () => parseListings(
          page([
            {'unexpected': 'shape'},
          ]),
        ),
        throwsFormatException,
      );
    },
  );

  test('failed detail lookup discards that source partial buffer, not other sources', () async {
    final bundle = Target.fromJson({
      ...sampleTarget.toJson(),
      'allowBundle': true,
    });
    final second = Target.fromJson({
      ...sampleTarget.toJson(),
      'id': 'second',
      'name': 'Other console',
      'searchMode': 'itemName',
    });
    final client = Dio()
      ..httpClientAdapter = FixtureAdapter((request, _) async {
        if (request.path.contains('/p/')) {
          return ResponseBody.fromString('not available', 404);
        }
        return ResponseBody.fromString(
          page(
            request.path.contains('/search/')
                ? [card('other')]
                : [card('first'), card('missing-detail', description: '')],
          ),
          200,
        );
      });
    addTearDown(() => client.close(force: true));
    final result = await CarousellService(
      client,
      pacing: Duration.zero,
    ).scrape([bundle, second], Cancellation(), (_) {});
    expect(result.sources.first.failure, SourceFailure.detail);
    expect(result.sources.first.retained, 0);
    expect(result.listings.map((l) => l.id), ['other']);
  });

  test(
    'shared source is immutable and has no invented single current target',
    () {
      final second = Target.fromJson({
        ...sampleTarget.toJson(),
        'id': 'second',
        'name': 'Nintendo Switch Lite',
      });
      final targets = [sampleTarget, second];
      final source = planSources(targets).single;
      targets.clear();
      expect(source.targets, hasLength(2));
      expect(source.currentTargetId, isNull);
      expect(source.label, 'Video Gaming');
      expect(() => source.targets.clear(), throwsUnsupportedError);
    },
  );

  test(
    'cancellation reports the interrupted source and starts no later source',
    () async {
      final token = Cancellation();
      final client = Dio()
        ..httpClientAdapter = FixtureAdapter((_, _) async {
          token.cancel();
          token.check();
          return ResponseBody.fromString('', 200);
        });
      addTearDown(() => client.close(force: true));
      final events = <ScrapeProgress>[];
      await expectLater(
        CarousellService(client).scrape([sampleTarget], token, events.add),
        throwsA(isA<RunCancelled>()),
      );
      expect(events.whereType<ScrapeSourceStarted>(), hasLength(1));
      expect(
        events.whereType<ScrapeSourceCompleted>().single.summary.failure,
        SourceFailure.cancelled,
      );
    },
  );

  test('audit chunks report actual response status, start and completion, and immutable diagnostics', () async {
    final client = Dio()
      ..httpClientAdapter = FixtureAdapter(
        (_, _) async => ResponseBody.fromString('malformed', 202),
      );
    addTearDown(() => client.close(force: true));
    final service = GeminiService(
      client,
      key: 'fixture-secret-key',
      model: 'fixture-model',
      prompt: 'fixture prompt',
    );
    final events = <AuditProgress>[];
    final result = await service.audit(
      findCandidates(sampleListing, [sampleTarget]),
      Cancellation(),
      events.add,
    );
    expect(events.map((e) => e.runtimeType), [
      AuditingChunkStarted,
      AuditingChunkCompleted,
    ]);
    final completed = events.last as AuditingChunkCompleted;
    expect(completed.summary['httpStatus'], 202);
    expect(completed.summary['attempts'], 1);
    expect(completed.completed, 1);
    expect(result.failedIds, {sampleListing.id});
    expect(
      () => (completed.summary['failedIds'] as List).clear(),
      throwsUnsupportedError,
    );
    expect(
      jsonEncode(service.configuration.toJson()),
      isNot(contains('fixture-secret-key')),
    );
    expect(
      service.configuration.promptSha256,
      matches(RegExp(r'^[a-f0-9]{64}$')),
    );
  });
}
