import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:deal_finder_app/src/domain/matching/candidate_filter.dart';
import 'package:deal_finder_app/src/domain/matching/deal_engine.dart';
import 'package:deal_finder_app/src/domain/matching/fuzzy_match.dart';
import 'package:deal_finder_app/src/domain/matching/text_cleaner.dart';
import 'package:deal_finder_app/src/domain/matching/variant_tokens.dart';
import 'package:deal_finder_app/src/domain/matching/unicode_text.dart';
import 'package:deal_finder_app/src/domain/models/audit.dart';
import 'package:deal_finder_app/src/domain/models/deal.dart';
import 'package:deal_finder_app/src/domain/models/listing.dart';
import 'package:deal_finder_app/src/domain/models/money.dart';
import 'package:deal_finder_app/src/domain/models/target.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> keywords(Object? raw) => raw == null
    ? []
    : (raw is List ? raw.map((s) => '$s') : '$raw'.split(','))
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();

Target targetFromRow(Map<String, dynamic> r) => Target(
  id: r['Item Name'] as String,
  name: r['Item Name'] as String,
  category: r['Category'] as String? ?? '',
  searchMode: SearchMode.itemName,
  dealPrice: Money.parse(r['Deal Price (PHP)']),
  retailPrice: Money.optional(r['Retail Price (PHP)']),
  allowBundle: r['Allow Bundle Check'] == true,
  type: r['Target Type'] == 'Game' ? TargetType.game : TargetType.hardware,
  downsizingKeywords: keywords(r['Keyword for Condition Downsizing']),
  freebieKeywords: keywords(r['Keyword for Finding Freebies']),
);

const flags = {
  PriceFlag.normal: 'normal',
  PriceFlag.placeholderZero: 'placeholder_zero',
  PriceFlag.suspiciouslyLow: 'suspiciously_low',
  PriceFlag.textRecovered: 'text_recovered',
  PriceFlag.bundleCandidate: 'bundle_candidate',
};
Map<String, Object?> projectedDeal(Deal d) => {
  'id': d.id, 'target': d.target.name, 'price_centavos': d.price.centavos,
  'savings_centavos': d.savings.centavos,
  // The legacy local fallback does not expose this field. Dart still retains
  // its source Listing; only this differential projection omits that extra data.
  'original_price_centavos': d.provenance is GeminiProvenance
      ? d.listing.price?.centavos
      : null,
  'condition': d.finalCondition, 'issues': d.issues, 'freebies': d.freebies,
  'is_bundle': d.isBundle, 'price_evidence': d.priceEvidence,
  'source': d.provenance.toJson()['source'],
  'gemini_confidence': d.provenance is GeminiProvenance
      ? (d.provenance as GeminiProvenance).confidence
      : null,
};

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/python_safety_parity.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  test('Pinned normalization matches every valid Unicode scalar', () {
    final folded = BytesBuilder(copy: false),
        processed = BytesBuilder(copy: false),
        words = BytesBuilder(copy: false);
    // Flush chunks to avoid a separate tiny byte-list object for each scalar.
    final foldChunk = <int>[], processChunk = <int>[], wordChunk = <int>[];
    for (var code = 0; code < 0x110000; code++) {
      if (code >= 0xd800 && code <= 0xdfff) continue;
      final char = String.fromCharCode(code);
      foldChunk.addAll([...utf8.encode(pythonCaseFold(char)), 0]);
      processChunk.addAll([...utf8.encode(defaultProcess(char)), 0]);
      wordChunk.add(pythonWords.hasMatch(char) ? 1 : 0);
      if (wordChunk.length >= 4096 || code == 0x10ffff) {
        folded.add(Uint8List.fromList(foldChunk));
        processed.add(Uint8List.fromList(processChunk));
        words.add(Uint8List.fromList(wordChunk));
        foldChunk.clear();
        processChunk.clear();
        wordChunk.clear();
      }
    }
    expect({
      'casefold': sha256.convert(folded.takeBytes()).toString(),
      'process': sha256.convert(processed.takeBytes()).toString(),
      'word': sha256.convert(words.takeBytes()).toString(),
    }, fixture['unicode_scalar_sha256']);
  });
  for (final r in fixture['cascade'] as List) {
    test('Python cascade: ${r['name']}', () {
      final targets = (r['targets'] as List)
          .map((t) => targetFromRow(t as Map<String, dynamic>))
          .toList();
      final l = r['listing'] as Map<String, dynamic>;
      final listing = Listing(
        id: l['id'] as String,
        title: l['title'] as String,
        price: Money.optional(l['price']),
        description: l['description'] as String? ?? '',
        condition: l['condition'] as String? ?? '',
        eligibleTargetNames: (l['eligible_target_names'] as List?)
            ?.cast<String>(),
      );
      final candidates = findCandidates(listing, targets);
      expect(
        candidates
            .map(
              (c) => {
                'target': c.target.name,
                'price_centavos': c.effectivePrice.centavos,
                'flag': flags[c.flag],
              },
            )
            .toList(),
        r['candidates'],
      );
      final allowed = <String, Set<String>>{};
      for (final c in candidates) {
        allowed.putIfAbsent(c.listing.id, () => {}).add(c.target.name);
      }
      final validated = candidates.isEmpty
          ? ValidatedAudits([], {}, {}, [])
          : validateAudits({'audits': r['audits']}, allowed);
      expect(validated.missingIds, (r['failed_ids'] as List).toSet());
      expect(validated.unknownIds, (r['unknown_ids'] as List).toSet());
      final confirmed = acceptGemini(candidates, validated.audits);
      final deals = [
        ...confirmed,
        if (r['include_local'] == true)
          ...localFallback(
            candidates,
            validated.missingIds,
          ).where((d) => !confirmed.any((c) => c.id == d.id)),
      ];
      final List expectedRows;
      if (r['approved_difference'] != null) {
        expect(r['name'], 'local fallback 15000 PS5 Slim Digital');
        expect(
          r['deals'],
          isEmpty,
          reason: 'Preserve evidence of Python candidate-loss bug',
        );
        expectedRows = r['approved_flutter_deals'] as List;
        expect(expectedRows, hasLength(1));
        expect(expectedRows.single['target'], 'PS5 Slim Digital');
      } else {
        expectedRows = r['deals'] as List;
      }
      final expected = expectedRows.cast<Map<String, dynamic>>();
      expect(deals, hasLength(expected.length));
      for (var i = 0; i < deals.length; i++) {
        final projection = Map<String, dynamic>.of(expected[i])
          ..remove('local_score');
        expect(projectedDeal(deals[i]), projection);
        if (deals[i].provenance is LocalProvenance) {
          expect(
            (deals[i].provenance as LocalProvenance).score,
            closeTo(expected[i]['local_score'] as num, 1e-8),
          );
        } else {
          expect(expected[i]['local_score'], isNull);
        }
      }
    });
  }
  for (final r in fixture['conditions'] as List) {
    test('Python condition: ${r['name']}', () {
      final target = Target(
        id: 'target',
        name: r['game'] == true ? 'Zelda BOTW' : 'PS5 Slim',
        category: '',
        searchMode: SearchMode.itemName,
        dealPrice: const Money(1800000),
        downsizingKeywords: (r['keywords'] as List).cast<String>(),
        type: r['game'] == true ? TargetType.game : TargetType.hardware,
      );
      final listing = Listing(
        id: 'condition',
        title: r['title'] as String,
        price: const Money(1700000),
        condition: r['original'] as String,
        description: r['description'] as String,
      );
      final candidate = CandidateMatch(
        listing,
        target,
        listing.price!,
        100,
        PriceFlag.normal,
      );
      final audit = Audit(
        id: listing.id,
        matchedItem: target.name,
        confidence: 95,
        specsMatched: true,
        issues: (r['issues'] as List).cast<String>(),
        freebies: [],
        downgrade: r['downgrade'] as bool,
      );
      expect(conditionAfterAudit(candidate, audit), r['expected']);
      if (r['game'] == false && r['downgrade'] == false) {
        expect(
          localFallback([candidate], {listing.id}).single.finalCondition,
          r['expected'],
        );
      }
    });
  }
  for (final (i, r) in (fixture['variants'] as List).indexed) {
    test('Python variant family $i', () {
      final index = VariantIndex((r['names'] as List).cast<String>());
      expect(index.families, r['families']);
      expect(
        index.tokens.map((k, v) => MapEntry(k, v.toList()..sort())),
        r['tokens'],
      );
      for (final decision in r['decisions']) {
        expect(
          index.accepts(
            decision['title'] as String,
            decision['target'] as String,
          ),
          decision['accepted'],
          reason: '${decision['title']} -> ${decision['target']}',
        );
      }
    });
  }
  for (final (i, r) in (fixture['clean_text'] as List).indexed) {
    test('Python description boundaries $i', () {
      expect(
        cleanDescription(r['text'] as String, maxChars: r['max_chars'] as int),
        r['expected'],
      );
    });
  }
  for (final (i, r) in (fixture['fuzzy'] as List).indexed) {
    test('Python Unicode fuzzy and preprocessing $i', () {
      final a = r['a'] as String, b = r['b'] as String;
      expect(ratio(a, b), closeTo(r['ratio'] as num, 1e-8));
      expect(partialRatio(a, b), closeTo(r['partial'] as num, 1e-8));
      expect(tokenSetRatio(a, b), closeTo(r['token_set'] as num, 1e-8));
      expect(tokenSortRatio(a, b), closeTo(r['token_sort'] as num, 1e-8));
      expect(defaultProcess(a), r['process_a']);
      expect(defaultProcess(b), r['process_b']);
    });
  }
  for (final (i, r) in (fixture['freebies'] as List).indexed) {
    test('Python freebie extraction $i', () {
      expect(
        extractFreebies(
          r['description'] as String,
          (r['keywords'] as List).cast<String>(),
        ),
        r['expected'],
      );
    });
  }
  for (final (i, r) in (fixture['accessories'] as List).indexed) {
    test('Python hardware/game accessory gate $i', () {
      expect(
        accessoryOnly(
          r['title'] as String,
          r['description'] as String,
          r['type'] == 'Game' ? TargetType.game : TargetType.hardware,
        ),
        r['expected'],
      );
    });
  }
}
