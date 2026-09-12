import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deal_finder_app/src/application/pipeline/cancellation.dart';
import 'package:deal_finder_app/src/data/carousell/carousell_service.dart';
import 'package:deal_finder_app/src/data/gemini/gemini_service.dart';
import 'package:deal_finder_app/src/data/network/bounded_dio.dart';
import 'package:deal_finder_app/src/domain/matching/candidate_filter.dart';
import 'package:deal_finder_app/src/domain/matching/deal_engine.dart';
import 'package:deal_finder_app/src/domain/models/audit.dart';
import 'package:deal_finder_app/src/domain/models/listing.dart';

import 'support/fakes.dart';

class FixtureAdapter implements HttpClientAdapter {
  FixtureAdapter(this.handle);
  final Future<ResponseBody> Function(RequestOptions, Future<void>?) handle;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handle(options, cancelFuture);
  @override
  void close({bool force = false}) {}
}

Map<String, Object?> auditJson({String id = 'listing-1'}) => {
  'id': id,
  'matched_item': sampleTarget.name,
  'confidence': 94,
  'specs_matched': true,
  'issues': <String>[],
  'freebies': <String>[],
  'downgrade_condition': false,
  'is_accessory': false,
  'is_bundle': false,
  'separately_available': false,
  'individual_price': null,
  'price_evidence': null,
};

void main() {
  Dio clientFor(FixtureAdapter adapter) {
    final client = Dio()..httpClientAdapter = adapter;
    addTearDown(() => client.close(force: true));
    return client;
  }

  test(
    'Dio bounds success and failure bodies and suppresses secret headers',
    () async {
      final client = clientFor(
        FixtureAdapter((options, _) async {
          expect(options.followRedirects, isFalse);
          return ResponseBody.fromString('secret', 500);
        }),
      );
      Future<String> request(int size) => boundedDioText(
        client,
        'https://example.com',
        Cancellation(),
        allowedHosts: {'example.com'},
        maxBytes: size,
        headers: {'x-goog-api-key': 'private-key'},
      );
      await expectLater(request(4), throwsFormatException);
      try {
        await request(20);
        fail('Expected HTTP failure');
      } on DioException catch (error) {
        expect(error.response!.statusCode, 500);
        expect(error.response!.data, isNull);
        expect(error.requestOptions.headers, isNot(contains('x-goog-api-key')));
        expect(error.toString(), isNot(contains('private-key')));
      }
    },
  );

  test('Dio cancellation reaches the native adapter', () async {
    final started = Completer<void>(), stopped = Completer<void>();
    final client = clientFor(
      FixtureAdapter((_, cancel) async {
        started.complete();
        await cancel;
        stopped.complete();
        return ResponseBody.fromString('', 200);
      }),
    );
    final c = Cancellation();
    final pending = expectLater(
      boundedDioText(
        client,
        'https://example.com',
        c,
        allowedHosts: {'example.com'},
      ),
      throwsA(isA<RunCancelled>()),
    );
    await started.future;
    c.cancel();
    await pending;
    await stopped.future;
  });

  test('Gemini request deduplicates IDs and redacts listing PII', () async {
    var calls = 0;
    final client = clientFor(
      FixtureAdapter((options, _) async {
        calls++;
        expect(options.uri.queryParameters, isEmpty);
        expect(options.headers['x-goog-api-key'], 'test-key');
        final data = jsonEncode(options.data);
        expect(data, isNot(contains('someone@example.com')));
        expect(data, isNot(contains('09171234567')));
        return ResponseBody.fromString(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({
                        'audits': [auditJson()],
                      }),
                    },
                  ],
                },
              },
            ],
          }),
          200,
        );
      }),
    );
    final listing = Listing.fromJson({
      ...sampleListing.toJson(),
      'description': 'Working. Contact someone@example.com or 09171234567.',
    });
    final candidates = findCandidates(listing, [sampleTarget]);
    final batch = await GeminiService(
      client,
      key: 'test-key',
      model: 'gemini-test',
      prompt: 'Test prompt',
    ).audit([...candidates, ...candidates], Cancellation(), (_) {});
    expect(calls, 1);
    expect(batch.audits.single.id, sampleListing.id);
    expect(batch.failedIds, isEmpty);
  });

  test('one malformed chunk only marks its own IDs failed', () async {
    var calls = 0;
    final client = clientFor(
      FixtureAdapter((_, _) async {
        calls++;
        return ResponseBody.fromString(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': calls == 1
                          ? jsonEncode({
                              'audits': [auditJson()],
                            })
                          : '```json\n{}\n```',
                    },
                  ],
                },
              },
            ],
          }),
          200,
        );
      }),
    );
    final second = Listing.fromJson({
      ...sampleListing.toJson(),
      'id': 'listing-2',
    });
    final batch =
        await GeminiService(
          client,
          key: 'test-key',
          model: 'gemini-test',
          prompt: '',
          chunkSize: 1,
        ).audit(
          [
            ...findCandidates(sampleListing, [sampleTarget]),
            ...findCandidates(second, [sampleTarget]),
          ],
          Cancellation(),
          (_) {},
        );
    expect(batch.audits.single.id, sampleListing.id);
    expect(batch.failedIds, {'listing-2'});
    expect(calls, 2);
  });

  test(
    'audit validator rejects inconsistent split-price and malformed fields',
    () {
      for (final patch in <Map<String, Object?>>[
        {'confidence': true},
        {'confidence': 101},
        {'is_bundle': 'false'},
        {
          'freebies': [1],
        },
        {'individual_price': 100},
        {'separately_available': true},
        {'price_evidence': ' '},
        {'price_evidence': 'x' * 801},
        {'is_accessory': null},
      ]) {
        expect(
          () => Audit.fromJson({...auditJson(), ...patch}),
          throwsFormatException,
        );
      }
      final bundle = Audit.fromJson({
        ...auditJson(),
        'is_bundle': true,
        'freebies': ['paid item'],
      });
      expect(bundle.freebies, isEmpty);
      final validated = validateAudits(
        {
          'audits': [auditJson(), auditJson(), auditJson(id: 'unknown')],
        },
        {
          'listing-1': {sampleTarget.name},
          'missing': {sampleTarget.name},
        },
      );
      expect(validated.audits, hasLength(1));
      expect(validated.missingIds, {'missing'});
      expect(validated.unknownIds, {'unknown'});
      expect(validated.errors.single, contains('Duplicate'));
    },
  );

  test('Carousell embedded JSON preserves numeric IDs and optional metadata', () {
    final page =
        '<script>window.state = ${jsonEncode({
          'data': {
            'listingCards': [
              {
                'id': 123,
                'title': 'Nintendo Switch OLED',
                'price': {'amount': '8,500.50'},
                'url': '/p/nintendo-switch-oled-123/',
                'photos': [
                  {'url': '//images.example.com/a.jpg'},
                ],
                'seller': {'username': 'seller', 'rating': 4.8, 'ratingCount': 3},
                'likeCount': 5,
                'timeCreated': 1700000000,
                'belowFold': {
                  'description': 'Working console.',
                  'condition': 'Lightly used',
                  'meetupLocations': [
                    {'name': 'Quezon City'},
                  ],
                },
              },
            ],
          },
        })};</script>';
    final listing = parseListings(page).single;
    expect(listing.id, '123');
    expect(listing.price!.centavos, 850050);
    expect(
      listing.link,
      'https://www.carousell.ph/p/nintendo-switch-oled-123/',
    );
    expect(listing.sellerRating, 4.8);
    expect(listing.likeCount, 5);
    expect(listing.location, 'Quezon City');
    expect(listing.condition, 'Lightly Used');
    expect(listing.thumbnailUrl, 'https://images.example.com/a.jpg');
    expect(listing.listedAt, '2023-11-14T22:13:20.000Z');
    expect(
      () => parseListings('<html>Access denied</html>'),
      throwsFormatException,
    );
    expect(parseListings('<script>{"listingCards":[]}</script>'), isEmpty);
  });

  test('local freebie rules stay opt-in, bounded, and deduplicated', () {
    const description =
        'Comes with case. Includes charger, free grip. Includes charger. Free one two three four five six seven.';
    expect(extractFreebies(description, []), isEmpty);
    expect(extractFreebies(description, ['comes with', 'includes', 'free']), [
      'case',
      'charger',
      'grip',
    ]);
  });
}
