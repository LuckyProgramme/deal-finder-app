import 'audit.dart';
import 'listing.dart';
import 'money.dart';
import 'target.dart';

final class Deal {
  Deal({
    required this.listing,
    required this.target,
    required this.price,
    required this.provenance,
    required this.finalCondition,
    Iterable<String> issues = const [],
    Iterable<String> freebies = const [],
    this.isBundle = false,
    this.priceEvidence,
    this.isFavorite = false,
    this.isDismissed = false,
    DateTime? firstSeen,
    DateTime? lastSeen,
  }) : issues = List.unmodifiable(issues),
       freebies = List.unmodifiable(freebies),
       firstSeen = firstSeen ?? DateTime.now().toUtc(),
       lastSeen = lastSeen ?? DateTime.now().toUtc() {
    if (price.centavos <= 0 || price.centavos > target.dealPrice.centavos) {
      throw ArgumentError('Unqualified deal price');
    }
  }
  final Listing listing;
  final Target target;
  final Money price;
  final Provenance provenance;
  final String finalCondition;
  final List<String> issues, freebies;
  final bool isBundle, isFavorite, isDismissed;
  final String? priceEvidence;
  final DateTime firstSeen, lastSeen;
  String get id => listing.id;
  Money get savings => target.dealPrice - price;
  Deal withFlags({bool? favorite, bool? dismissed}) => Deal(
    listing: listing,
    target: target,
    price: price,
    provenance: provenance,
    finalCondition: finalCondition,
    issues: issues,
    freebies: freebies,
    isBundle: isBundle,
    priceEvidence: priceEvidence,
    isFavorite: favorite ?? isFavorite,
    isDismissed: dismissed ?? isDismissed,
    firstSeen: firstSeen,
    lastSeen: lastSeen,
  );
  Map<String, Object?> toJson() => {
    'listing': listing.toJson(),
    'target': target.toJson(),
    'price': price.centavos,
    'provenance': provenance.toJson(),
    'finalCondition': finalCondition,
    'issues': issues,
    'freebies': freebies,
    'isBundle': isBundle,
    'priceEvidence': priceEvidence,
    'isFavorite': isFavorite,
    'isDismissed': isDismissed,
    'firstSeen': firstSeen.toIso8601String(),
    'lastSeen': lastSeen.toIso8601String(),
  };
  factory Deal.fromJson(Map<String, dynamic> j) => Deal(
    listing: Listing.fromJson(j['listing'] as Map<String, dynamic>),
    target: Target.fromJson(j['target'] as Map<String, dynamic>),
    price: Money(j['price'] as int),
    provenance: Provenance.fromJson(j['provenance'] as Map<String, dynamic>),
    finalCondition: j['finalCondition'] as String,
    issues: List<String>.from(j['issues'] as List),
    freebies: List<String>.from(j['freebies'] as List),
    isBundle: j['isBundle'] as bool,
    priceEvidence: j['priceEvidence'] as String?,
    isFavorite: j['isFavorite'] as bool,
    isDismissed: j['isDismissed'] as bool,
    firstSeen: DateTime.parse(j['firstSeen'] as String),
    lastSeen: DateTime.parse(j['lastSeen'] as String),
  );
}
