import 'deal.dart';
import 'listing.dart';
import 'target.dart';

/// Immutable results of one committed normal scan. Never contains credentials.
final class RunSnapshot {
  RunSnapshot({
    required this.runId,
    required this.createdAt,
    required Iterable<Deal> deals,
    required Iterable<Listing> listings,
    required Iterable<Target> targets,
  }) : deals = List.unmodifiable(deals),
       listings = List.unmodifiable(listings),
       targets = List.unmodifiable(targets);
  final String runId;
  final DateTime createdAt;
  final List<Deal> deals;
  final List<Listing> listings;
  final List<Target> targets;
  Map<String, Object?> toJson() => {
    'runId': runId,
    'createdAt': createdAt.toIso8601String(),
    'deals': deals.map((d) => d.toJson()).toList(),
    'listings': listings.map((l) => l.toJson()).toList(),
    'targets': targets.map((t) => t.toJson()).toList(),
  };
  factory RunSnapshot.fromJson(Map<String, dynamic> j) => RunSnapshot(
    runId: j['runId'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    deals: (j['deals'] as List).map(
      (v) => Deal.fromJson(v as Map<String, dynamic>),
    ),
    listings: (j['listings'] as List).map(
      (v) => Listing.fromJson(v as Map<String, dynamic>),
    ),
    targets: (j['targets'] as List).map(
      (v) => Target.fromJson(v as Map<String, dynamic>),
    ),
  );
}
