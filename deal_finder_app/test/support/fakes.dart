import 'dart:async';

import 'package:deal_finder_app/src/domain/models/run_configuration.dart';

import 'package:deal_finder_app/src/application/pipeline/cancellation.dart';
import 'package:deal_finder_app/src/application/pipeline/pipeline_controller.dart';
import 'package:deal_finder_app/src/application/pipeline/pipeline_ports.dart';
import 'package:deal_finder_app/src/data/carousell/carousell_service.dart';
import 'package:deal_finder_app/src/domain/matching/candidate_filter.dart';
import 'package:deal_finder_app/src/domain/models/audit.dart';
import 'package:deal_finder_app/src/domain/models/deal.dart';
import 'package:deal_finder_app/src/domain/models/listing.dart';
import 'package:deal_finder_app/src/domain/models/money.dart';
import 'package:deal_finder_app/src/domain/models/run_snapshot.dart';
import 'package:deal_finder_app/src/domain/models/target.dart';
import 'package:deal_finder_app/src/domain/repositories/repositories.dart';
import 'package:deal_finder_app/src/platform/credentials/credential_store.dart';

final sampleTarget = Target(
  id: 'target-1',
  name: 'Nintendo Switch OLED',
  category: 'Video Gaming',
  dealPrice: const Money(1200000),
);
final sampleListing = Listing(
  id: 'listing-1',
  title: 'Nintendo Switch OLED',
  price: const Money(850000),
  condition: 'Lightly Used',
  description: 'Complete console, tested and working.',
  seller: 'sample_seller',
  location: 'Quezon City',
  listedAt: '2026-09-08T09:00:00Z',
  sellerRating: 4.8,
  sellerRatingCount: 12,
  link: 'https://www.carousell.ph/p/nintendo-switch-oled-123456789/',
);
final sampleDeal = Deal(
  listing: sampleListing,
  target: sampleTarget,
  price: sampleListing.price!,
  provenance: GeminiProvenance(94, true),
  finalCondition: 'Lightly Used',
  firstSeen: DateTime.utc(2026, 9, 9),
  lastSeen: DateTime.utc(2026, 9, 9),
);

class MemoryLibrary
    implements
        TargetRepository,
        DealRepository,
        RunRepository,
        AppPreferencesRepository {
  MemoryLibrary({
    List<Target>? targets,
    List<Deal>? deals,
    this.onboardingCompleted = true,
  }) : targets = targets ?? [],
       deals = deals ?? [];
  List<Target> targets;
  List<Deal> deals;
  bool onboardingCompleted;
  RunSnapshot? latestSnapshot;
  final runs = <String, RunRecord>{};
  final changes = StreamController<void>.broadcast();
  @override
  Stream<List<Target>> watchTargets() async* {
    yield List.of(targets);
    yield* changes.stream.map((_) => List.of(targets));
  }

  @override
  Future<List<Target>> loadTargets() async => List.of(targets);
  @override
  Future<void> saveTarget(Target t) async {
    if (targets.any(
      (old) => old.id != t.id && old.name.toLowerCase() == t.name.toLowerCase(),
    )) {
      throw StateError('A target with this name already exists.');
    }
    targets = [...targets.where((old) => old.id != t.id), t];
    changes.add(null);
  }

  @override
  Future<void> deleteTarget(String id) async {
    targets.removeWhere((t) => t.id == id);
    changes.add(null);
  }

  @override
  Future<void> importTargets(
    List<Target> incoming,
    List<Target> expectedLocal,
  ) async {
    for (final target in incoming) {
      await saveTarget(target);
    }
  }

  @override
  Stream<List<Deal>> watchDeals() async* {
    yield List.of(deals);
    yield* changes.stream.map((_) => List.of(deals));
  }

  @override
  Future<void> persistDeals(
    List<Deal> value,
    String runId, {
    List<Listing> listings = const [],
    List<Target> targets = const [],
  }) async {
    latestSnapshot = RunSnapshot(
      runId: runId,
      createdAt: DateTime.now().toUtc(),
      deals: value,
      listings: listings,
      targets: targets,
    );
    deals = [...deals.where((d) => !value.any((v) => v.id == d.id)), ...value];
    changes.add(null);
  }

  @override
  Future<void> setDealFlags(
    String id, {
    bool? favorite,
    bool? dismissed,
  }) async {
    deals = deals
        .map(
          (d) => d.id == id
              ? d.withFlags(favorite: favorite, dismissed: dismissed)
              : d,
        )
        .toList();
    changes.add(null);
  }

  @override
  Stream<List<RunRecord>> watchRuns() async* {
    yield runs.values.toList();
    yield* changes.stream.map((_) => runs.values.toList());
  }

  @override
  Future<void> saveRun(RunRecord run) async {
    runs[run.id] = run;
    changes.add(null);
  }

  @override
  Future<void> recoverInterruptedRuns() async {}
  @override
  Future<bool> hasCompletedOnboarding() async => onboardingCompleted;
  @override
  Future<void> completeOnboarding() async => onboardingCompleted = true;
  @override
  Stream<List<Deal>> watchCurrentDeals() => watchDeals();
  @override
  Future<RunSnapshot?> loadLatestSnapshot() async => latestSnapshot;
  Future<void> dispose() => changes.close();
}

class MemoryCredentials implements CredentialStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> removeAll() async => values.clear();
}

class FakeMarketplace implements Marketplace {
  FakeMarketplace({this.items, this.hold = false});
  final List<Listing>? items;
  final bool hold;
  @override
  Future<ScrapeBatchResult> scrape(
    List<Target> targets,
    Cancellation cancellation,
    FutureOr<void> Function(ScrapeProgress) progress, {
    int? limit,
  }) async {
    final source = planSources(targets).first;
    await progress(ScrapeSourceStarted(0, 1, source));
    if (hold) await cancellation.delay(const Duration(seconds: 30));
    cancellation.check();
    final listings = items ?? [sampleListing];
    final summary = ScrapeSourceSummary(
      source: source,
      fetched: listings.length,
      retained: listings.length,
      duration: Duration.zero,
    );
    await progress(ScrapeSourceCompleted(0, 1, summary));
    return ScrapeBatchResult(listings, [summary]);
  }
}

class FakeAuditor implements Auditor {
  FakeAuditor({this.fail = false, this.reject = false});
  final bool fail, reject;
  @override
  AuditConfiguration get configuration => AuditConfiguration(
    model: 'fixture',
    endpointClass: 'fixture',
    chunkSize: 20,
    promptSha256: '0' * 64,
    schemaSha256: '1' * 64,
  );
  @override
  Future<AuditBatch> audit(
    List<CandidateMatch> candidates,
    Cancellation cancellation,
    FutureOr<void> Function(AuditProgress) progress,
  ) async {
    final ids = candidates.map((c) => c.listing.id).toSet();
    if (ids.isNotEmpty) {
      await progress(AuditingChunkStarted(0, 1, 0, ids.length));
      await progress(
        AuditingChunkCompleted(0, 1, ids.length, ids.length, {'chunk': 0}),
      );
    }
    return AuditBatch(
      fail
          ? []
          : ids
                .map(
                  (id) => Audit(
                    id: id,
                    matchedItem: reject ? null : candidates.first.target.name,
                    confidence: reject ? 0 : 94,
                    specsMatched: !reject,
                    issues: [],
                    freebies: [],
                  ),
                )
                .toList(),
      fail ? ids : {},
      [],
    );
  }
}

PipelineController fakePipeline(
  MemoryLibrary library, {
  FakeMarketplace? marketplace,
  FakeAuditor? auditor,
  ResultSync? sync,
}) => PipelineController(
  targets: library,
  deals: library,
  runs: library,
  marketplace: marketplace ?? FakeMarketplace(),
  createAuditor: () async => auditor ?? FakeAuditor(),
  syncResults: sync,
);
