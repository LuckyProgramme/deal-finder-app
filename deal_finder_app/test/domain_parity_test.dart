import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:deal_finder_app/src/domain/models/listing.dart';
import 'package:deal_finder_app/src/domain/models/money.dart';
import 'package:deal_finder_app/src/domain/models/target.dart';
import 'package:deal_finder_app/src/domain/matching/candidate_filter.dart';
import 'package:deal_finder_app/src/domain/matching/fuzzy_match.dart';
import 'package:deal_finder_app/src/domain/matching/text_cleaner.dart';

void main() {
  final fixture = jsonDecode(
    File('test/fixtures/python_parity.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  final targets = (fixture['targets'] as List).map((raw) {
    final r = raw as Map<String, dynamic>;
    return Target(
      id: r['Item Name'] as String,
      name: r['Item Name'] as String,
      category: r['Category'] as String,
      dealPrice: Money.parse(r['Deal Price (PHP)']),
      retailPrice: Money.optional(r['Retail Price (PHP)']),
      allowBundle: r['Allow Bundle Check'] == true,
      type: r['Target Type'] == 'Game' ? TargetType.game : TargetType.hardware,
    );
  }).toList();
  test(
    'money preserves centavos and rejects nonfinite or excessive precision',
    () {
      expect(Money.parse('PHP 12,345.67').centavos, 1234567);
      expect(Money.parse('0.10') - Money.parse('0.09'), const Money(1));
      for (final bad in ['NaN', 'Infinity', '1.234', '', 'twelve']) {
        expect(() => Money.parse(bad), throwsFormatException);
      }
    },
  );
  for (final raw in fixture['fuzzy_edges'] as List) {
    final r = raw as Map<String, dynamic>;
    test('Indel scorer edge ${r['a']} / ${r['b']}', () {
      expect(
        ratio(r['a'] as String, r['b'] as String),
        closeTo((r['ratio'] as num).toDouble(), 1e-8),
      );
      expect(
        partialRatio(r['a'] as String, r['b'] as String),
        closeTo((r['partial'] as num).toDouble(), 1e-8),
      );
      expect(
        tokenSetRatio(r['a'] as String, r['b'] as String),
        closeTo((r['token_set'] as num).toDouble(), 1e-8),
      );
    });
  }
  var trueCount = 0, missed = 0;
  for (final raw in fixture['cases'] as List) {
    final r = raw as Map<String, dynamic>,
        l = r['listing'] as Map<String, dynamic>;
    final listing = Listing(
      id: l['id'].toString(),
      title: l['title'] as String,
      price: Money.optional(l['price']),
      description: l['description'] as String? ?? '',
    );
    test('Python candidate, price, alias and score parity: ${listing.id}', () {
      expect(expandAliases(listing.title), r['aliases']);
      expect(cleanDescription(listing.description), r['clean_description']);
      for (final t in targets) {
        final scores = lexicalScore(listing.title, t.name),
            expected = (r['scores'] as Map)[t.name] as List;
        expect(
          scores.$1,
          closeTo((expected[0] as num).toDouble(), 1e-8),
          reason: '${t.name} best',
        );
        expect(
          scores.$2,
          closeTo((expected[1] as num).toDouble(), 1e-8),
          reason: '${t.name} token set',
        );
        expect(
          scores.$3,
          closeTo((expected[2] as num).toDouble(), 1e-8),
          reason: '${t.name} partial',
        );
      }
      final actual = findCandidates(listing, targets)
          .map(
            (c) => {
              'target': c.target.name,
              'price_centavos': c.effectivePrice.centavos,
              'flag': switch (c.flag) {
                PriceFlag.normal => 'normal',
                PriceFlag.textRecovered => 'text_recovered',
                PriceFlag.placeholderZero => 'placeholder_zero',
                PriceFlag.suspiciouslyLow => 'suspiciously_low',
                PriceFlag.bundleCandidate => 'bundle_candidate',
              },
            },
          )
          .toList();
      expect(actual, r['candidates']);
    });
    if (l['is_true_deal'] == true) {
      trueCount++;
      if (!findCandidates(
        listing,
        targets,
      ).any((c) => c.target.name == l['expected_target'])) {
        missed++;
      }
    }
  }
  test('benchmark recall >=99% ($trueCount true deals)', () {
    expect(trueCount, greaterThan(10));
    expect(missed / trueCount, lessThanOrEqualTo(.01));
  });
}
