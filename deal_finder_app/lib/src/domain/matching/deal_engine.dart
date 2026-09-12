import '../models/audit.dart';
import '../models/deal.dart';
import '../models/money.dart';
import '../models/target.dart';
import 'candidate_filter.dart';
import 'fuzzy_match.dart';
import 'text_cleaner.dart';
import 'unicode_text.dart';
import 'variant_tokens.dart';

const _downgrades = {
  'brand new': 'Lightly Used',
  'like new': 'Well Used',
  'lightly used': 'Well Used',
};
final _packaging = insensitive(
  r'\b(?:cartridge\s+only|(?:no|without|missing)\s+(?:the\s+)?(?:case|box)|(?:case|box)\s+(?:missing|not\s+included))\b',
);
String canonicalCondition(String text) => compact(text)
    .split(' ')
    .map(
      (s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase(),
    )
    .join(' ');
bool _nonNegated(String text, String keyword) {
  keyword = pythonTrim(keyword).toLowerCase();
  if (keyword.isEmpty) return false;
  for (final match in RegExp(
    '(?<![$pythonWordBody])${RegExp.escape(keyword)}(?![$pythonWordBody])',
    unicode: true,
    caseSensitive: false,
  ).allMatches(text)) {
    final tokens = RegExp("[$pythonWordBody']+", unicode: true)
        .allMatches(text.substring(0, match.start).toLowerCase())
        .map((m) => m[0]!)
        .toList();
    final prefix = tokens.skip(tokens.length > 4 ? tokens.length - 4 : 0);
    if (!prefix.any(
      {
        'no',
        'not',
        'without',
        'never',
        "isn't",
        "wasn't",
        "hasn't",
        'none',
      }.contains,
    )) {
      return true;
    }
  }
  return false;
}

String conditionAfterAudit(CandidateMatch c, Audit a) {
  var description = c.listing.description;
  var packagingOnly = false;
  if (c.target.type == TargetType.game) {
    description = description.replaceAll(_packaging, '');
    packagingOnly =
        _packaging.hasMatch('${c.listing.title}\n${c.listing.description}') &&
        !a.issues.any((issue) => !_packaging.hasMatch(issue));
  }
  final local = c.target.downsizingKeywords.any(
    (k) => _nonNegated(description, k),
  );
  final original = canonicalCondition(c.listing.condition);
  return local || (a.downgrade && !packagingOnly)
      ? _downgrades[original.toLowerCase()] ?? original
      : original;
}

Money? verifiedPrice(CandidateMatch c, Audit a) {
  if (!a.isBundle) return c.effectivePrice;
  final price = a.individualPrice, listing = c.listing, target = c.target;
  if (!target.allowBundle ||
      !a.separatelyAvailable ||
      price == null ||
      price.centavos <= 0 ||
      price.centavos > target.dealPrice.centavos ||
      (a.priceEvidence ?? '').isEmpty ||
      (listing.price != null &&
          listing.price!.centavos > target.dealPrice.centavos * 3)) {
    return null;
  }
  if (insensitive(
    r'\b(?:(?:bundle|take\s*all|set)\s+only|no\s+(?:split(?:ting)?|individual\s+sales)|not\s+sold\s+separately)\b',
  ).hasMatch('${listing.title}\n${listing.description}')) {
    return null;
  }
  final evidence = compact(a.priceEvidence!);
  final pattern = RegExp(
    '(?<![$pythonWordBody])${RegExp.escape(evidence)}(?![$pythonWordBody.,])',
    unicode: true,
  );
  final lines = cleanDescription(listing.description)
      .split('\n')
      .map(compact)
      .where(pattern.hasMatch)
      .toList();
  if (lines.isEmpty ||
      insensitive(
        r'\b(?:sold|reserved|deposit|down\s*payment|original(?:ly)?|retail|was|used\s+to|if\s+(?:you\s+)?buy|when\s+(?:you\s+)?buy)\b',
      ).hasMatch(lines.join('\n'))) {
    return null;
  }
  const ignored = {
    'the',
    'of',
    'a',
    'an',
    'for',
    'nintendo',
    'switch',
    'game',
    'games',
  };
  final targetTokens = evidenceTokens(expandAliases(target.name))
      .difference(ignored);
  if (targetTokens.isEmpty ||
      !evidenceTokens(expandAliases(evidence)).containsAll(targetTokens)) {
    return null;
  }
  final modelNumbers = targetTokens
      .where((s) => RegExp(r'^\d+$').hasMatch(s))
      .map(int.parse)
      .map((n) => n * 100)
      .toSet();
  final amounts = <int>[];
  for (final m in RegExp(
    '(?<![$pythonWordBody.])([0-9]+(?:,[0-9]{3})*(?:\\.[0-9]+)?)[$pythonSpaceBody]*(k(?![$pythonWordBody]))?(?![$pythonWordBody.])',
    unicode: true,
    caseSensitive: false,
  ).allMatches(evidence)) {
    final amount =
        (double.parse(m[1]!.replaceAll(',', '')) *
                (m[2] != null ? 100000 : 100))
            .round();
    if (!modelNumbers.contains(amount)) amounts.add(amount);
  }
  return amounts.length == 1 && amounts.single == price.centavos ? price : null;
}

List<Deal> acceptGemini(List<CandidateMatch> candidates, List<Audit> audits) {
  final deals = <Deal>[], seen = <String>{};
  for (final audit in audits) {
    if (seen.contains(audit.id) ||
        audit.matchedItem == null ||
        audit.confidence < 80 ||
        !audit.specsMatched ||
        audit.isAccessory) {
      continue;
    }
    final matching = candidates.where(
      (c) => c.listing.id == audit.id && c.target.name == audit.matchedItem,
    );
    if (matching.isEmpty) continue;
    final c = matching.first;
    if (c.needsPriceReview) continue;
    final price = verifiedPrice(c, audit);
    if (price == null ||
        price.centavos <= 0 ||
        price.centavos > c.target.dealPrice.centavos) {
      continue;
    }
    deals.add(
      Deal(
        listing: c.listing,
        target: c.target,
        price: price,
        provenance: GeminiProvenance(audit.confidence, audit.specsMatched),
        finalCondition: conditionAfterAudit(c, audit),
        issues: {
          ...audit.issues,
          if (c.target.type == TargetType.game &&
              _packaging.hasMatch(
                '${c.listing.title}\n${c.listing.description}',
              ))
            'Cartridge only / missing case',
        },
        freebies: audit.isBundle ? [] : audit.freebies,
        isBundle: audit.isBundle,
        priceEvidence: audit.isBundle ? audit.priceEvidence : null,
      ),
    );
    seen.add(audit.id);
  }
  return deals;
}

List<String> extractFreebies(String description, Iterable<String> keywords) {
  final phrases = keywords
      .map((s) => s.trim().toLowerCase())
      .where((s) => s.isNotEmpty)
      .toList();
  final found = <String>[];
  final patterns = {
    'comes with': r'comes\s+with\s+([^,.\n]+)',
    'includes': r'includes?\s+([^,.\n]+)',
    'free': r'free\s+([^,.\n]+)',
    'bundled with': r'bundled\s+with\s+([^,.\n]+)',
  };
  for (final entry in patterns.entries) {
    if (!phrases.any((p) => p.contains(entry.key) || entry.key.contains(p))) {
      continue;
    }
    for (final match in insensitive(entry.value).allMatches(description)) {
      final item = match[1]!.replaceAll(RegExp(r'^[ \-:\t]+|[ \-:\t]+$'), '');
      if (item.isNotEmpty &&
          item.split(RegExp(r'\s+')).length <= 6 &&
          !found.contains(item)) {
        found.add(item);
      }
    }
  }
  return found;
}

List<Deal> localFallback(
  List<CandidateMatch> candidates,
  Set<String> failedIds,
) {
  final index = VariantIndex(candidates.map((c) => c.target.name).toSet());
  final accepted = <String, Deal>{};
  for (final c in candidates) {
    if (!failedIds.contains(c.listing.id) ||
        c.needsPriceReview ||
        c.flag == PriceFlag.bundleCandidate ||
        !index.accepts(c.listing.title, c.target.name) ||
        c.effectivePrice.centavos <= 0 ||
        c.effectivePrice.centavos > c.target.dealPrice.centavos) {
      continue;
    }
    final score = tokenSetRatio(
      defaultProcess(c.listing.title),
      defaultProcess(c.target.name),
    );
    if (score <= 60) continue;
    final prior = accepted[c.listing.id];
    if (prior != null && (prior.provenance as LocalProvenance).score >= score) {
      continue;
    }
    final original = canonicalCondition(c.listing.condition);
    final downgrade = c.target.downsizingKeywords.any(
      (k) => _nonNegated(c.listing.description, k),
    );
    accepted[c.listing.id] = Deal(
      listing: c.listing,
      target: c.target,
      price: c.effectivePrice,
      provenance: LocalProvenance(score),
      freebies: extractFreebies(
        c.listing.description,
        c.target.freebieKeywords,
      ),
      finalCondition: downgrade
          ? _downgrades[original.toLowerCase()] ?? original
          : original,
    );
  }
  return accepted.values.toList();
}
