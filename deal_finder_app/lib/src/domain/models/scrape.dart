import 'listing.dart';
import 'target.dart';

final class ScrapeSource {
  ScrapeSource(this.url, Iterable<Target> targets, this.category, this.mode)
    : targets = List.unmodifiable(targets);
  final String url, category;
  final List<Target> targets;
  final SearchMode mode;
  String get label =>
      mode == SearchMode.category ? category : targets.first.name;
  String? get currentTargetId => targets.length == 1 ? targets.single.id : null;
}

enum SourceFailure { network, http, parsing, detail, cancelled }

final class ScrapeSourceSummary {
  const ScrapeSourceSummary({
    required this.source,
    required this.fetched,
    required this.retained,
    required this.duration,
    this.failure,
    this.httpStatus,
  });
  final ScrapeSource source;
  final int fetched, retained;
  final Duration duration;
  final SourceFailure? failure;
  final int? httpStatus;
  bool get succeeded => failure == null;
  Map<String, Object?> toJson() => {
    'label': source.label,
    'mode': source.mode.name,
    'targetIds': source.targets.map((t) => t.id).toList(),
    'fetched': fetched,
    'retained': retained,
    'durationMs': duration.inMilliseconds,
    'failure': failure?.name,
    'httpStatus': httpStatus,
  };
}

final class ScrapeBatchResult {
  ScrapeBatchResult(
    Iterable<Listing> listings,
    Iterable<ScrapeSourceSummary> sources,
  ) : listings = List.unmodifiable(listings),
      sources = List.unmodifiable(sources);
  final List<Listing> listings;
  final List<ScrapeSourceSummary> sources;
  bool get complete => sources.isNotEmpty && sources.every((s) => s.succeeded);
}

sealed class ScrapeProgress {
  const ScrapeProgress(this.index, this.total, this.source);
  final int index, total;
  final ScrapeSource source;
}

final class ScrapeSourceStarted extends ScrapeProgress {
  const ScrapeSourceStarted(super.index, super.total, super.source);
}

final class ScrapeSourceCompleted extends ScrapeProgress {
  ScrapeSourceCompleted(int index, int total, this.summary)
    : super(index, total, summary.source);
  final ScrapeSourceSummary summary;
}

List<ScrapeSource> planSources(List<Target> targets) {
  final groups = <String, List<Target>>{}, names = <String>{};
  for (final target in targets.where((t) => t.enabled)) {
    if (!names.add(target.name.toLowerCase())) {
      throw ArgumentError('Duplicate target name.');
    }
    final url = target.searchMode == SearchMode.category
        ? categoryUrls[target.category]!
        : 'https://www.carousell.ph/search/${Uri.encodeComponent(target.name)}/?addRecent=true&canChangeKeyword=true&includeSuggestions=true&searchId=&searchType=all&sort_by=3&query_source=ss_dropdown';
    groups.putIfAbsent(url, () => []).add(target);
  }
  return [
    for (final entry in groups.entries)
      ScrapeSource(
        entry.key,
        entry.value,
        entry.value.first.searchMode == SearchMode.category
            ? entry.value.first.category
            : '',
        entry.value.first.searchMode,
      ),
  ];
}
