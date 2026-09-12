import 'dart:convert';
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:html/parser.dart' as html;

import '../../application/pipeline/cancellation.dart';
import '../../application/pipeline/pipeline_ports.dart';
import '../../domain/models/scrape.dart';
export '../../domain/models/scrape.dart';
export '../../application/pipeline/pipeline_ports.dart' show Marketplace;
import '../network/bounded_dio.dart';
import '../network/platform_fetch.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/money.dart';
import '../../domain/models/target.dart';

bool validCarousellUrl(String value) {
  final u = Uri.tryParse(value);
  return u != null &&
      u.scheme == 'https' &&
      u.userInfo.isEmpty &&
      (!u.hasPort || u.port == 443) &&
      {'www.carousell.ph', 'carousell.ph'}.contains(u.host) &&
      u.path.startsWith('/p/');
}

Iterable<Object?> walkJson(Object? node, [int depth = 0]) sync* {
  if (depth > 80) return;
  yield node;
  if (node is Map) {
    for (final v in node.values) {
      yield* walkJson(v, depth + 1);
    }
  }
  if (node is List) {
    for (final v in node) {
      yield* walkJson(v, depth + 1);
    }
  }
}

Object? _decodePrefix(String raw) {
  // Assignments may have a semicolon suffix; JSON.parse contains a JSON string.
  final text = raw.trimLeft();
  if (text.isEmpty) return null;
  var depth = 0, inString = false, escaped = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (escaped) {
      escaped = false;
      continue;
    }
    if (ch == r'\' && inString) {
      escaped = true;
      continue;
    }
    if (ch == '"') {
      inString = !inString;
      if (!inString && depth == 0) return jsonDecode(text.substring(0, i + 1));
    }
    if (inString) continue;
    if (ch == '{' || ch == '[') depth++;
    if (ch == '}' || ch == ']') {
      depth--;
      if (depth == 0) return jsonDecode(text.substring(0, i + 1));
    }
  }
  return null;
}

Iterable<Object?> jsonDocuments(String page) sync* {
  for (final script in html.parse(page).querySelectorAll('script')) {
    final raw = script.text.trim();
    try {
      yield jsonDecode(raw);
      continue;
    } on FormatException {
      /* Assignment below. */
    }
    for (final m in RegExp(
      r'(?:=|:|JSON\.parse\()\s*(\{|\")',
    ).allMatches(raw)) {
      try {
        final start = m.end - 1;
        final value = _decodePrefix(raw.substring(start));
        yield value is String ? jsonDecode(value) : value;
      } on FormatException {
        continue;
      }
    }
  }
}

String _string(Map card, List<String> keys) {
  for (final key in keys) {
    final v = card[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return '';
}

Money? parsePrice(Object? raw) {
  if (raw is Map) {
    for (final k in [
      'amount',
      'value',
      'price',
      'formattedAmount',
      'formatted',
    ]) {
      final p = parsePrice(raw[k]);
      if (p != null) return p;
    }
    return null;
  }
  if (raw == null || raw is bool || (raw is num && !raw.isFinite)) return null;
  final m = RegExp(r'(?:PHP|₱)?\s*(\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d+(?:\.\d+)?)')
      .firstMatch(raw.toString());
  return m == null
      ? null
      : Money((double.parse(m[1]!.replaceAll(',', '')) * 100).round());
}

String _condition(Object? raw) {
  for (final node in walkJson(raw)) {
    if (node is String &&
        {
          'brand new',
          'like new',
          'lightly used',
          'well used',
          'heavily used',
        }.contains(node.toLowerCase().trim())) {
      return node
          .trim()
          .toLowerCase()
          .split(' ')
          .map((s) => s[0].toUpperCase() + s.substring(1))
          .join(' ');
    }
  }
  return '';
}

Listing? normalizeCard(
  Map card, {
  String baseUrl = 'https://www.carousell.ph',
}) {
  final title = _string(card, ['title', 'name', 'listingTitle']);
  if (title.isEmpty) return null;
  final id =
      (card['id'] ??
              card['listingId'] ??
              card['listingID'] ??
              card['listing_id'] ??
              '')
          .toString();
  final link = _string(card, [
    'url',
    'listingUrl',
    'listing_url',
    'urlPath',
    'path',
    'href',
  ]);
  final seller = card['seller'] is Map ? card['seller'] as Map : const {};
  final below = card['belowFold'] is Map ? card['belowFold'] as Map : const {};
  String? image = _string(card, ['thumbnailUrl', 'thumbnail_url']);
  if (image.isEmpty &&
      card['photos'] is List &&
      (card['photos'] as List).isNotEmpty) {
    final first = (card['photos'] as List).first;
    image = first is Map ? first['url']?.toString() : first?.toString();
  }
  if (image != null && image.startsWith('//')) image = 'https:$image';
  final imageUri = Uri.tryParse(image ?? '');
  if (imageUri == null ||
      imageUri.scheme != 'https' ||
      imageUri.host.isEmpty ||
      imageUri.userInfo.isNotEmpty) {
    image = null;
  }
  double? number(Object? v) {
    if (v is bool) return null;
    final n = double.tryParse('$v');
    return n != null && n.isFinite && n >= 0 ? n : null;
  }

  int? count(Object? v) {
    final n = number(v);
    return n != null && n == n.roundToDouble() ? n.toInt() : null;
  }

  final rating = number(seller['rating'] ?? card['rating']);
  final locations = below['meetupLocations'];
  String? location = card['location'] is String
      ? card['location'] as String
      : null;
  if (locations is List) {
    location = locations
        .whereType<Map>()
        .map((m) => m['name'])
        .whereType<String>()
        .join('; ');
  }
  final timestamp = card['timeCreated'] ?? card['listing_timestamp'];
  DateTime? date;
  if (timestamp is! bool) {
    final n = number(timestamp);
    try {
      date = n == null
          ? DateTime.tryParse('$timestamp')
          : DateTime.fromMillisecondsSinceEpoch(
              (n >= 100000000000 ? n : n * 1000).round(),
              isUtc: true,
            );
    } on ArgumentError {
      date = null;
    }
  }
  final description = _string(below, ['description']).isNotEmpty
      ? _string(below, ['description'])
      : _string(card, ['description', 'listingDescription']);
  return Listing(
    id: id,
    title: title,
    price: parsePrice(card['price'] ?? card['priceInfo']),
    condition: _condition(below).isNotEmpty
        ? _condition(below)
        : _condition(card['condition']),
    description: description,
    link: () {
      final raw = link.isEmpty
          ? 'https://www.carousell.ph/p/${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}-$id/'
          : Uri.parse(baseUrl).resolve(link).toString();
      return raw.contains('/p/') && !raw.endsWith('/') ? '$raw/' : raw;
    }(),
    seller: _string(seller, ['username', 'name', 'displayName']),
    thumbnailUrl: image,
    sellerRating: rating != null && rating <= 5 ? rating : null,
    sellerRatingCount: count(seller['ratingCount'] ?? card['ratingCount']),
    likeCount: count(card['likeCount']),
    location: location,
    listedAt: date?.toUtc().toIso8601String(),
  );
}

List<Listing> parseListings(
  String page, {
  String baseUrl = 'https://www.carousell.ph',
}) {
  var structure = false;
  var rawCardCount = 0;
  final found = <String, Listing>{};
  for (final document in jsonDocuments(page)) {
    for (final node in walkJson(document)) {
      if (node is! Map) continue;
      final cards = node['listingCards'] ?? node['listing_cards'];
      if (cards is! List) continue;
      structure = true;
      rawCardCount += cards.length;
      for (final card in cards.whereType<Map>()) {
        final l = normalizeCard(card, baseUrl: baseUrl);
        if (l != null && (l.id.isNotEmpty || l.link.isNotEmpty)) {
          found[l.id.isNotEmpty ? l.id : l.link] = l;
        }
      }
    }
  }
  if (found.isNotEmpty) return found.values.toList();
  for (final card
      in html.parse(page).querySelectorAll('[data-testid*="listing-card"]')) {
    String text(String selector) =>
        card.querySelector(selector)?.text.trim() ?? '';
    final title = text('[data-testid*="title"], h1, h2, h3, h4, a[title]');
    if (title.isEmpty) continue;
    final link = Uri.parse(baseUrl)
        .resolve(card.querySelector('a[href]')?.attributes['href'] ?? '')
        .toString();
    final id =
        card.attributes['data-listing-id'] ??
        card.attributes['data-id'] ??
        RegExp(r'-(\d+)/?$').firstMatch(link)?[1] ??
        link;
    found[id] = Listing(
      id: id,
      title: title,
      link: link,
      price: parsePrice(text('[data-testid*="price"], .price')),
      condition: _condition(text('[data-testid*="condition"], .condition')),
      description: text('[data-testid*="description"], .description'),
      seller: text('[data-testid*="seller"], .seller'),
    );
  }
  if (found.isEmpty && (!structure || rawCardCount > 0)) {
    throw const FormatException(
      'Carousell page structure changed or access was blocked.',
    );
  }
  return found.values.toList();
}

final class CarousellService implements Marketplace {
  CarousellService(
    this.client, {
    this.pacing = const Duration(seconds: 5),
    this.usePlatformFetch,
  });
  final Dio client;
  final Duration pacing;
  final bool? usePlatformFetch;
  static const _allowedHosts = {'www.carousell.ph', 'carousell.ph'};
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
  };
  Future<String> _fetch(String url, Cancellation c) async {
    for (var attempt = 0; ; attempt++) {
      c.check();
      try {
        // Prefer the platform's native TLS stack (curl/Schannel on Windows)
        // in production (when not using a mocked test adapter) to avoid
        // Cloudflare JA3/JA4 fingerprint challenges against Dart's BoringSSL.
        final shouldTryPlatform =
            usePlatformFetch ?? (client.httpClientAdapter is IOHttpClientAdapter);
        if (shouldTryPlatform) {
          final result = await platformFetch(
            url,
            c,
            allowedHosts: _allowedHosts,
            headers: _headers,
          );
          if (result != null) return result;
        }
        return await boundedDioText(
          client,
          url,
          c,
          allowedHosts: _allowedHosts,
          headers: _headers,
        );
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        if (attempt >= 2 || (status != null && status < 500 && status != 429)) {
          rethrow;
        }
        await c.delay(Duration(seconds: 1 << attempt));
      }
    }
  }

  @override
  Future<ScrapeBatchResult> scrape(
    List<Target> targets,
    Cancellation c,
    FutureOr<void> Function(ScrapeProgress) progress, {
    int? limit,
  }) async {
    if (limit != null && limit < 1) {
      throw ArgumentError('Limit must be positive.');
    }
    final summaries = <ScrapeSourceSummary>[];
    final sources = planSources(targets),
        merged = <String, Listing>{},
        detailCache = <String, String>{};
    for (var i = 0; i < sources.length; i++) {
      final source = sources[i];
      c.check();
      await progress(ScrapeSourceStarted(i, sources.length, source));
      final watch = Stopwatch()..start();
      final pending = <String, Listing>{};
      var fetched = 0, fetchingDetails = false;
      ScrapeSourceSummary summary;
      try {
        if (i > 0) await c.delay(pacing);
        final listings = parseListings(
          await _fetch(source.url, c),
          baseUrl: source.url,
        );
        final retained = listings.take(
          limit ?? (source.mode == SearchMode.itemName ? 20 : listings.length),
        );
        fetched = listings.length;
        for (final listing in retained) {
          c.check();
          var description = listing.description;
          if (description.isEmpty &&
              source.targets.any(
                (t) =>
                    t.allowBundle &&
                    (listing.price == null ||
                        listing.price!.centavos <= t.dealPrice.centavos * 3),
              )) {
            fetchingDetails = true;
            if (!validCarousellUrl(listing.link)) {
              throw const FormatException(
                'Invalid listing URL for description retrieval.',
              );
            }
            if (!detailCache.containsKey(listing.id)) {
              await c.delay(pacing);
              final page = await _fetch(listing.link, c);
              final nodes = jsonDocuments(page)
                  .expand(walkJson)
                  .whereType<Map>()
                  .where(
                    (n) =>
                        (n['id']?.toString() == listing.id ||
                            n['listingId']?.toString() == listing.id ||
                            n['@type'] == 'Product') &&
                        n['description'] is String,
                  )
                  .toList();
              if (nodes.isEmpty) {
                throw const FormatException(
                  'Listing description structure changed.',
                );
              }
              detailCache[listing.id] = nodes.first['description'] as String;
            }
            description = detailCache[listing.id]!;
            fetchingDetails = false;
          }
          final key = listing.id.isEmpty ? listing.link : listing.id,
              old = pending[key] ?? merged[key];
          pending[key] = Listing.fromJson({
            ...listing.toJson(),
            'description': description.isNotEmpty
                ? description
                : old?.description ?? '',
            'category': source.category.isNotEmpty
                ? source.category
                : old?.category ?? '',
            'eligibleTargetNames': {
              ...?old?.eligibleTargetNames,
              ...source.targets.map((t) => t.name),
            }.toList(),
          });
        }
        merged.addAll(pending);
        summary = ScrapeSourceSummary(
          source: source,
          fetched: fetched,
          retained: pending.length,
          duration: watch.elapsed,
        );
      } on RunCancelled {
        await progress(
          ScrapeSourceCompleted(
            i,
            sources.length,
            ScrapeSourceSummary(
              source: source,
              fetched: fetched,
              retained: 0,
              duration: watch.elapsed,
              failure: SourceFailure.cancelled,
            ),
          ),
        );
        rethrow;
      } catch (error) {
        final status = error is DioException
            ? error.response?.statusCode
            : null;
        summary = ScrapeSourceSummary(
          source: source,
          fetched: fetched,
          retained: 0,
          duration: watch.elapsed,
          httpStatus: status,
          failure: fetchingDetails
              ? SourceFailure.detail
              : error is FormatException
              ? SourceFailure.parsing
              : status != null
              ? SourceFailure.http
              : SourceFailure.network,
        );
      } finally {
        watch.stop();
      }
      summaries.add(summary);
      await progress(ScrapeSourceCompleted(i, sources.length, summary));
    }
    return ScrapeBatchResult(merged.values, summaries);
  }
}
