import 'money.dart';

final class Listing {
  Listing({
    required this.id,
    required this.title,
    this.price,
    this.description = '',
    this.condition = '',
    this.link = '',
    this.seller = '',
    this.category = '',
    this.thumbnailUrl,
    this.sellerRating,
    this.sellerRatingCount,
    this.likeCount,
    this.location,
    this.listedAt,
    Iterable<String>? eligibleTargetNames,
  }) : eligibleTargetNames = eligibleTargetNames == null
           ? null
           : Set.unmodifiable(eligibleTargetNames);
  final String id, title, description, condition, link, seller, category;
  final Money? price;
  final String? thumbnailUrl, location, listedAt;
  final double? sellerRating;
  final int? sellerRatingCount, likeCount;
  final Set<String>? eligibleTargetNames;
  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'price': price?.centavos,
    'description': description,
    'condition': condition,
    'link': link,
    'seller': seller,
    'category': category,
    'thumbnailUrl': thumbnailUrl,
    'sellerRating': sellerRating,
    'sellerRatingCount': sellerRatingCount,
    'likeCount': likeCount,
    'location': location,
    'listedAt': listedAt,
    'eligibleTargetNames': eligibleTargetNames?.toList(),
  };
  factory Listing.fromJson(Map<String, dynamic> j) => Listing(
    id: j['id'] as String,
    title: j['title'] as String,
    price: j['price'] == null ? null : Money(j['price'] as int),
    description: j['description'] as String? ?? '',
    condition: j['condition'] as String? ?? '',
    link: j['link'] as String? ?? '',
    seller: j['seller'] as String? ?? '',
    category: j['category'] as String? ?? '',
    thumbnailUrl: j['thumbnailUrl'] as String?,
    sellerRating: (j['sellerRating'] as num?)?.toDouble(),
    sellerRatingCount: j['sellerRatingCount'] as int?,
    likeCount: j['likeCount'] as int?,
    location: j['location'] as String?,
    listedAt: j['listedAt'] as String?,
    eligibleTargetNames: (j['eligibleTargetNames'] as List?)?.cast<String>(),
  );
}
