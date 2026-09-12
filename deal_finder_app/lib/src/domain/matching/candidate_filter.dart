import 'dart:math';

import '../models/listing.dart';
import '../models/money.dart';
import '../models/target.dart';
import 'fuzzy_match.dart';
import 'text_cleaner.dart';

enum PriceFlag {
  normal,
  textRecovered,
  placeholderZero,
  suspiciouslyLow,
  bundleCandidate,
}

final class CandidateMatch {
  const CandidateMatch(
    this.listing,
    this.target,
    this.effectivePrice,
    this.lexicalScore,
    this.flag,
  );
  final Listing listing;
  final Target target;
  final Money effectivePrice;
  final double lexicalScore;
  final PriceFlag flag;
  bool get needsPriceReview =>
      flag == PriceFlag.placeholderZero || flag == PriceFlag.suspiciouslyLow;
}

bool accessoryOnly(String title, String description, TargetType type) {
  final text = '$title $description';
  if (type == TargetType.game) {
    return insensitive(
      r'\b(?:case\s+only|box\s+only|empty\s+(?:case|box)|manual\s+only|cover\s+art(?:\s+only)?|poster|no\s+(?:game|cartridge)(?!\s+case))\b',
    ).hasMatch(text);
  }
  final accessory = insensitive(
    r'\b(?:box\s+only|empty\s+box|manual\s+only|case|cover|skin|screen\s+protector|sleeve|pouch|bag|charger|charging\s+cable|usb(?:-c)?\s+cable|adapter|dock|stand|mount|replacement\s+battery|joy[\s-]?con|controller|game(?:s)?|cartridge|game\s+card|physical\s+copy|keyboard|mouse)\b',
  );
  final hardware = insensitive(
    r'\b(?:complete(?:\s+set)?|full\s+set|bundle|unit|console|laptop|notebook|phone|tablet|headphones?|camera|includes?|comes\s+with|with\s+(?:charger|box|case|controller|games?))\b',
  );
  return accessory.hasMatch(text) && !hardware.hasMatch(text);
}

bool hasBundleCues(String title, String description) =>
    insensitive(r'\b(?:bundle|lot|set|each|games|package|take\s+all)\b')
        .hasMatch('$title\n$description') ||
    RegExp(r'(?<!\d),(?!\d)|[+&/]').hasMatch(title) ||
    RegExp(
          r'^.*\d[\d,.]*\s*(?:k\b)?\s*[-:–].+$',
          multiLine: true,
          caseSensitive: false,
        ).allMatches(description).length >=
        2;

// Compatibility recall boosts from the Python catalog, not a supported-target
// allowlist. Every other user-created name uses the same fuzzy recall gates.
const _core = <String, List<Set<String>>>{
  'PS5 Slim': [
    {'ps5'},
    {'playstation', '5'},
  ],
  'PS5 Slim Digital': [
    {'ps5'},
    {'playstation', '5'},
  ],
  'Nintendo Switch OLED': [
    {'switch', 'oled'},
    {'nintendo', 'switch'},
    {'nsw', 'oled'},
    {'oled', 'console'},
    {'oled', 'unit'},
  ],
  'iPhone 15': [
    {'iphone', '15'},
    {'ip15'},
  ],
  'iPhone 15 Pro Max': [
    {'iphone', '15', 'max'},
    {'15pm'},
    {'ip15pm'},
    {'15', 'pro', 'max'},
  ],
  'iPad Air 5': [
    {'ipad', 'air'},
    {'ipad', '5'},
    {'air', '5'},
  ],
  'M1 MacBook Air': [
    {'macbook', 'm1'},
    {'mba', 'm1'},
    {'macbook', 'air'},
  ],
  'Sony WH-1000XM5': [
    {'xm5'},
    {'wh1000xm5'},
    {'1000xm5'},
    {'sony', 'xm5'},
  ],
};
Set<String> tokenize(String s) =>
    RegExp(r'[a-z0-9]+').allMatches(s.toLowerCase()).map((m) => m[0]!).toSet();
(double, double, double) lexicalScore(String title, String name) {
  final a = expandAliases(title).toLowerCase(),
      b = expandAliases(name).toLowerCase();
  final set = tokenSetRatio(a, b), partial = partialRatio(a, b);
  return (max(set, partial), set, partial);
}

bool passesRecall(String title, String target) {
  final tokens = tokenize(expandAliases(title));
  if ((_core[target] ?? []).any(tokens.containsAll)) return true;
  final (_, set, partial) = lexicalScore(title, target);
  return set >= 50 || partial >= 65;
}

(Money, PriceFlag) triagePrice(
  Money? price,
  String title,
  String description,
  Money threshold,
) {
  final zero = price == null || price.centavos <= 0;
  final low =
      price != null &&
      price.centavos > 0 &&
      price.centavos * 10 < threshold.centavos;
  if (zero || low) {
    final (recovered, _) = recoverPrice(title, description, threshold);
    if (recovered != null &&
        recovered.centavos * 10 >= threshold.centavos &&
        recovered.centavos <= threshold.centavos) {
      return (recovered, PriceFlag.textRecovered);
    }
  }
  if (zero) return (const Money(0), PriceFlag.placeholderZero);
  return (price, low ? PriceFlag.suspiciouslyLow : PriceFlag.normal);
}

List<CandidateMatch> findCandidates(Listing listing, Iterable<Target> targets) {
  final result = <CandidateMatch>[];
  for (final target in targets) {
    if (!target.enabled ||
        (listing.eligibleTargetNames != null &&
            !listing.eligibleTargetNames!.contains(target.name))) {
      continue;
    }
    if (accessoryOnly(listing.title, listing.description, target.type)) {
      continue;
    }
    if (listing.price != null &&
        listing.price!.centavos > target.dealPrice.centavos * 3) {
      continue;
    }
    final bundle = hasBundleCues(listing.title, listing.description);
    final matchText = bundle && target.allowBundle
        ? '${listing.title}\n${listing.description}'
        : listing.title;
    if (!passesRecall(matchText, target.name)) continue;
    if (bundle && target.allowBundle) {
      result.add(
        CandidateMatch(
          listing,
          target,
          listing.price ?? const Money(0),
          lexicalScore(matchText, target.name).$1,
          PriceFlag.bundleCandidate,
        ),
      );
      continue;
    }
    final (price, flag) = triagePrice(
      listing.price,
      listing.title,
      bundle ? '' : listing.description,
      target.dealPrice,
    );
    if ((price.centavos * 10 >= target.dealPrice.centavos &&
            price.centavos <= target.dealPrice.centavos) ||
        flag == PriceFlag.placeholderZero ||
        flag == PriceFlag.suspiciouslyLow) {
      result.add(
        CandidateMatch(
          listing,
          target,
          price,
          lexicalScore(listing.title, target.name).$1,
          flag,
        ),
      );
    }
  }
  return result;
}
