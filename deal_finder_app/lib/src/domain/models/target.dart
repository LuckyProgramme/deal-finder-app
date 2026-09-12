import 'money.dart';

enum SearchMode { category, itemName }

enum TargetType { hardware, game }

const categoryUrls = {
  'Video Gaming':
      'https://www.carousell.ph/categories/video-gaming-884/?sort_by=3',
  'Mobile Phones': 'https://www.carousell.ph/categories/mobile-phones-gadgets-840/?sort_by=3',
  'Computers & Tech':
      'https://www.carousell.ph/categories/computers-tech-838/?sort_by=3',
};

final class Target {
  Target({
    required this.id,
    required String name,
    required this.category,
    required this.dealPrice,
    this.retailPrice,
    this.searchMode = SearchMode.category,
    this.type = TargetType.hardware,
    this.allowBundle = false,
    this.enabled = true,
    Iterable<String> downsizingKeywords = const [],
    Iterable<String> freebieKeywords = const [],
    this.notes = '',
    this.revision = 0,
  }) : name = name.trim(),
       downsizingKeywords = List.unmodifiable(downsizingKeywords),
       freebieKeywords = List.unmodifiable(freebieKeywords) {
    if (id.isEmpty || this.name.isEmpty) {
      throw ArgumentError('Target name is required.');
    }
    if (dealPrice.centavos <= 0 ||
        (retailPrice != null && retailPrice!.centavos <= 0)) {
      throw ArgumentError('Prices must be positive.');
    }
    if (searchMode == SearchMode.category &&
        !categoryUrls.containsKey(category)) {
      throw ArgumentError(
        'Choose a supported Carousell category or search by item name.',
      );
    }
  }
  final String id, name, category, notes;
  final Money dealPrice;
  final Money? retailPrice;
  final SearchMode searchMode;
  final TargetType type;
  final bool allowBundle, enabled;
  final List<String> downsizingKeywords, freebieKeywords;
  final int revision;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'dealPrice': dealPrice.centavos,
    'retailPrice': retailPrice?.centavos,
    'searchMode': searchMode.name,
    'type': type.name,
    'allowBundle': allowBundle,
    'enabled': enabled,
    'downsizingKeywords': downsizingKeywords,
    'freebieKeywords': freebieKeywords,
    'notes': notes,
    'revision': revision,
  };

  factory Target.fromJson(Map<String, dynamic> j) => Target(
    id: j['id'] as String,
    name: j['name'] as String,
    category: j['category'] as String,
    dealPrice: Money(j['dealPrice'] as int),
    retailPrice: j['retailPrice'] == null
        ? null
        : Money(j['retailPrice'] as int),
    searchMode: SearchMode.values.byName(j['searchMode'] as String),
    type: TargetType.values.byName(j['type'] as String),
    allowBundle: j['allowBundle'] as bool,
    enabled: j['enabled'] as bool,
    downsizingKeywords: List<String>.from(j['downsizingKeywords'] as List),
    freebieKeywords: List<String>.from(j['freebieKeywords'] as List),
    notes: j['notes'] as String,
    revision: j['revision'] as int? ?? 0,
  );
}
