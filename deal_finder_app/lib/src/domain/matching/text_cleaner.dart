import '../models/money.dart';
import 'unicode_text.dart';

RegExp insensitive(String pattern) => RegExp(pattern, caseSensitive: false);
String compact(String text) =>
    text.split(pythonSpaces).where((x) => x.isNotEmpty).join(' ');

final _aliases = <(String, String)>[
  (r'\bbotw\b', 'the legend of zelda breath of the wild'),
  (r'\btotk\b', 'the legend of zelda tears of the kingdom'),
  (r'\bsmo\b', 'super mario odyssey'),
  (r'\bns2\b', 'nintendo switch 2'),
  (r'\bplay\s*station\s*5\b', 'ps5 playstation 5'),
  (r'\bps5\s*disc\b', 'ps5 slim disc'),
  (r'\bps5\s*digi(?:tal)?\b', 'ps5 slim digital'),
  (r'\bps5\b', 'ps5 playstation 5'),
  (r'\b(?:switch\s*oled|oled\s*(?:v\d\s*)?console)\b', 'nintendo switch oled'),
  (r'\b(?:nsw|switch)\b', 'nintendo switch'),
  (r'\b(?:ip15pm|15pm|iphone\s*15\s*pm|15\s*pro\s*max)\b', 'iphone 15 pro max'),
  (r'\b(?:ip15p|15p|iphone\s*15\s*pro)\b', 'iphone 15 pro'),
  (r'\b(?:ip15|iphone15)\b', 'iphone 15'),
  (r'\b(?:wh-?1000xm5|xm5)\b', 'sony wh-1000xm5'),
  (r'\b(?:mba\s*m1|m1\s*mba|macbook\s*m1)\b', 'm1 macbook air'),
  (r'\b(?:ipad\s*air\s*5|air\s*5)\b', 'ipad air 5'),
];
String expandAliases(String text) {
  for (final (pattern, value) in _aliases) {
    text = text.replaceAll(insensitive(pattern), value);
  }
  return text;
}

String stripNoise(String text) {
  text = text.replaceAll(RegExp('#[$pythonWordBody]+', unicode: true), '');
  for (final pattern in [
    r'\b(?:gcash|maya|bpi|bdo|bank\s*transfer|cod|meet\s*up|lalamove|grab|j&t|shipping)\b.*?(?=[,.\n]|$)',
    r'\b(?:rfs|reason\s*for\s*selling)\b.*?(?=[,.\n]|$)',
  ]) {
    text = text.replaceAll(insensitive(pattern), '');
  }
  return compact(text);
}

String redactPii(String text) {
  text = text.replaceAll(
    RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b'),
    '[EMAIL REDACTED]',
  );
  for (final pattern in [
    r'\b(?:gcash|maya|bpi|bdo|acct|acc#|account)[\s:#-]*(\d{10,16})\b',
    r'\b\d{4}[-\s]\d{4}[-\s]\d{4}(?:[-\s]\d{4})?\b',
  ]) {
    text = text.replaceAll(insensitive(pattern), '[PAYMENT REDACTED]');
  }
  for (final pattern in [
    r'(?:\+?63\s*|0)9\d{2}[-\s.]?\d{3}[-\s.]?\d{4}\b',
    r'\b09\d{9}\b',
    r'\b\d{3}[-.\s]\d{3}[-.\s]\d{4}\b',
  ]) {
    text = text.replaceAll(RegExp(pattern), '[PHONE REDACTED]');
  }
  return text;
}

String sanitizeText(String text) => text
    .replaceAll(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]'), '')
    .replaceAll(
      insensitive(
        r'<\/?(?:listing_untrusted_data|system|instruction|prompt|context|admin|script|style|iframe|embed)\b[^>]*>',
      ),
      '[TAG DISARMED]',
    )
    .replaceAll('```', "'''");

String cleanDescription(String text, {int maxChars = 800}) {
  if (maxChars < 0) throw ArgumentError.value(maxChars, 'maxChars');
  final clean = sanitizeText(redactPii(text))
      .split(RegExp(r'\r\n|[\n\r\x85\u2028\u2029]'))
      .map(stripNoise)
      .where((l) => l.isNotEmpty)
      .join('\n');
  final runes = clean.runes.toList();
  if (runes.length <= maxChars) return clean;
  var prefix = String.fromCharCodes(runes, 0, maxChars);
  if (!pythonSpace.hasMatch(String.fromCharCode(runes[maxChars]))) {
    prefix = prefix.replaceFirst(
      RegExp('[^$pythonSpaceBody]+\$', unicode: true),
      '',
    );
  }
  return pythonTrimRight(prefix);
}

String redactSecrets(String text) {
  text = redactPii(text);
  text = text.replaceAll(
    insensitive(
      r'-----BEGIN (?:RSA )?PRIVATE KEY-----[\s\S]*?-----END (?:RSA )?PRIVATE KEY-----',
    ),
    '[PRIVATE KEY REDACTED]',
  );
  text = text.replaceAll(
    RegExp(r'\bAIza[A-Za-z0-9_-]{20,}\b|\bAQ\.[A-Za-z0-9_-]{20,}'),
    '[KEY REDACTED]',
  );
  text = text.replaceAll(
    insensitive(r'bearer\s+[A-Za-z0-9._~+/-]+'),
    'Bearer [REDACTED]',
  );
  return text.replaceAllMapped(
    insensitive(r'(key|api_key|token|secret|password)\s*[=:]\s*[^&\s]+'),
    (m) => '${m[1]}=[REDACTED]',
  );
}

(Money?, String) recoverPrice(
  String title,
  String description,
  Money threshold,
) {
  final patterns = [
    (
      r'(?:price|selling\s*for|asking|only|for)?\s*[:=-]?\s*(?:php|₱)?\s*(\d{1,3}(?:\.\d+)?)\s*k\b',
      1000,
      'k_notation',
    ),
    (
      r'(?:price|selling\s*for|take\s*all\s*for|fixed\s*at|only)?\s*[:=-]?\s*(?:php|₱)\s*(\d{1,3}(?:,\d{3})+(?:\.\d+)?|\d{4,6}(?:\.\d+)?)',
      1,
      'currency_notation',
    ),
  ];
  for (final (pattern, multiplier, source) in patterns) {
    for (final match in insensitive(
      pattern,
    ).allMatches('$title \n $description')) {
      final parsed = double.tryParse(match[1]!.replaceAll(',', ''));
      if (parsed == null || !parsed.isFinite) continue;
      final price = Money((parsed * multiplier * 100).round());
      if (price.centavos * 10 >= threshold.centavos &&
          price.centavos * 2 <= threshold.centavos * 3) {
        return (price, source);
      }
    }
  }
  return (null, 'none');
}
