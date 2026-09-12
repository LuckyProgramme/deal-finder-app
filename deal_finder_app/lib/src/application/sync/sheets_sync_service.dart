import '../../data/sheets/sheet_models.dart';
import '../../data/sheets/sheets_gateway.dart';
import '../../domain/models/run_snapshot.dart';
import '../../domain/matching/candidate_filter.dart';
import '../pipeline/cancellation.dart';

final class SheetsSyncService {
  SheetsSyncService(this.gateway);
  final SheetsGateway gateway;

  Future<void> sync(
    RunSnapshot snapshot,
    Cancellation c, {
    Set<String> completedTabs = const {},
    required Future<void> Function(String tab) checkpoint,
  }) async {
    final seenDate = snapshot.createdAt.toLocal().toIso8601String().substring(
      0,
      10,
    );
    // History first: a retry re-reads IDs, including any uncertain prior append.
    for (final tab in ['History', 'All Listings', 'Current Deals']) {
      c.check();
      if (completedTabs.contains(tab)) continue;
      final remote = await gateway.read(tab, c);
      final edits = switch (tab) {
        'History' => historyUpdates(remote, snapshot.deals, seenDate),
        'Current Deals' => replaceManagedColumns(
          remote,
          currentHeaders,
          snapshot.deals.map((d) => dealCells(d, seenDate)).toList(),
        ),
        _ => replaceManagedColumns(
          remote,
          listingHeaders,
          snapshot.listings.map((l) {
            final candidates = findCandidates(l, snapshot.targets);
            final flags = candidates.map((c) => c.flag).toSet();
            final status = flags.contains(PriceFlag.textRecovered)
                ? 'Recovered (Text)'
                : flags.contains(PriceFlag.placeholderZero)
                ? 'Placeholder Zero'
                : flags.contains(PriceFlag.suspiciouslyLow)
                ? 'Suspicious Low'
                : flags.contains(PriceFlag.bundleCandidate)
                ? 'Bundle Candidate'
                : 'Normal';
            return listingCells(l, priceStatus: status);
          }).toList(),
        ),
      };
      await gateway.apply(remote, edits, c);
      await checkpoint(tab);
    }
  }
}
