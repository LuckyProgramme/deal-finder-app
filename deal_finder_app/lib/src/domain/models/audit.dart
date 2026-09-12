import 'money.dart';

sealed class Provenance {
  const Provenance();
  String get label;
  Map<String, Object?> toJson();
  factory Provenance.fromJson(Map<String, dynamic> j) => switch (j['source']) {
    'gemini' => GeminiProvenance(
      j['confidence'] as int,
      j['specsMatched'] as bool,
    ),
    'local_fallback' => LocalProvenance((j['score'] as num).toDouble()),
    _ => throw const FormatException('Unknown audit source'),
  };
}

final class GeminiProvenance extends Provenance {
  GeminiProvenance(this.confidence, this.specsMatched) {
    if (confidence < 0 || confidence > 100) {
      throw ArgumentError('Confidence out of range');
    }
  }
  final int confidence;
  final bool specsMatched;
  @override
  String get label => 'Verified by Gemini';
  @override
  Map<String, Object?> toJson() => {
    'source': 'gemini',
    'confidence': confidence,
    'specsMatched': specsMatched,
  };
}

final class LocalProvenance extends Provenance {
  LocalProvenance(this.score) {
    if (!score.isFinite || score < 0 || score > 100) {
      throw ArgumentError('Local score out of range');
    }
  }
  final double score;
  @override
  String get label => 'Local lexical fallback';
  @override
  Map<String, Object?> toJson() => {'source': 'local_fallback', 'score': score};
}

final class Audit {
  Audit({
    required this.id,
    required this.matchedItem,
    required this.confidence,
    required this.specsMatched,
    required Iterable<String> issues,
    required Iterable<String> freebies,
    this.downgrade = false,
    this.isAccessory = false,
    this.isBundle = false,
    this.individualPrice,
    this.separatelyAvailable = false,
    this.priceEvidence,
  }) : issues = List.unmodifiable(issues),
       freebies = List.unmodifiable(freebies) {
    if (id.trim().isEmpty || confidence < 0 || confidence > 100) {
      throw const FormatException('Invalid audit');
    }
  }
  final String id;
  final String? matchedItem, priceEvidence;
  final int confidence;
  final bool specsMatched,
      downgrade,
      isAccessory,
      isBundle,
      separatelyAvailable;
  final List<String> issues, freebies;
  final Money? individualPrice;
  factory Audit.fromJson(Map<String, dynamic> j) {
    List<String> strings(String key) {
      final value = j[key];
      if (value is! List || value.any((x) => x is! String)) {
        throw FormatException('Invalid $key');
      }
      return value
          .cast<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    }

    bool boolean(String key, {bool required = false}) {
      if (!j.containsKey(key) && !required) return false;
      if (j[key] is! bool) throw FormatException('Invalid $key');
      return j[key] as bool;
    }

    if (j['id'] is! String ||
        j['confidence'] is! int ||
        (j['matched_item'] != null && j['matched_item'] is! String)) {
      throw const FormatException('Invalid audit identity or confidence');
    }
    final price = j['individual_price'];
    for (final key in ['is_accessory', 'is_bundle', 'separately_available']) {
      boolean(key, required: true);
    }
    if (!j.containsKey('individual_price') ||
        !j.containsKey('price_evidence')) {
      throw const FormatException('Missing bundle decision fields');
    }
    if (price != null && (price is! num || !price.isFinite || price <= 0)) {
      throw const FormatException('Invalid individual price');
    }
    if (j['price_evidence'] != null &&
        (j['price_evidence'] is! String ||
            (j['price_evidence'] as String).trim().isEmpty ||
            (j['price_evidence'] as String).runes.length > 800)) {
      throw const FormatException('Invalid price evidence');
    }
    if (j['is_bundle'] == false &&
        (price != null || j['separately_available'] == true)) {
      throw const FormatException(
        'Non-bundle audit cannot contain split-price decisions',
      );
    }
    final matched = (j['matched_item'] as String?)?.trim();
    final freebies = strings('freebies');
    return Audit(
      id: (j['id'] as String).trim(),
      matchedItem: matched == null || matched.isEmpty ? null : matched,
      confidence: j['confidence'] as int,
      specsMatched: boolean('specs_matched', required: true),
      issues: strings('issues'),
      freebies: j['is_bundle'] == true ? [] : freebies,
      downgrade: boolean('downgrade_condition'),
      isAccessory: boolean('is_accessory'),
      isBundle: boolean('is_bundle'),
      individualPrice: Money.optional(price),
      separatelyAvailable: boolean('separately_available'),
      priceEvidence: j['price_evidence'] as String?,
    );
  }
}

final class ValidatedAudits {
  ValidatedAudits(this.audits, this.missingIds, this.unknownIds, this.errors);
  final List<Audit> audits;
  final Set<String> missingIds, unknownIds;
  final List<String> errors;
}

ValidatedAudits validateAudits(
  Object? payload,
  Map<String, Set<String>> allowedTargets,
) {
  final valid = <Audit>[],
      errors = <String>[],
      seen = <String>{},
      unknown = <String>{};
  if (payload is! Map || payload['audits'] is! List) {
    return ValidatedAudits([], allowedTargets.keys.toSet(), {}, [
      'Missing audits list',
    ]);
  }
  for (final raw in payload['audits'] as List) {
    if (raw is! Map<String, dynamic> || raw['id'] is! String) {
      errors.add('Invalid audit entry');
      continue;
    }
    final id = (raw['id'] as String).trim();
    if (!allowedTargets.containsKey(id)) {
      unknown.add(id);
      continue;
    }
    if (seen.contains(id)) {
      errors.add('Duplicate audit ID: $id');
      continue;
    }
    try {
      final audit = Audit.fromJson(raw);
      if (audit.matchedItem != null &&
          audit.matchedItem!.isNotEmpty &&
          !allowedTargets[id]!.contains(audit.matchedItem)) {
        errors.add('Unrequested target for $id');
        continue;
      }
      valid.add(audit);
      seen.add(id);
    } on FormatException {
      errors.add('Invalid fields for $id');
    }
  }
  return ValidatedAudits(
    valid,
    allowedTargets.keys.toSet().difference(seen),
    unknown,
    errors,
  );
}
