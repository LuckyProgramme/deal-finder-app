import 'dart:async';

import '../../domain/models/audit.dart';
import '../../domain/models/immutable_json.dart';
import '../../domain/models/run_configuration.dart';
import '../../domain/models/scrape.dart';
import '../../domain/models/target.dart';
import '../../domain/matching/candidate_filter.dart';
import 'cancellation.dart';

abstract interface class Marketplace {
  Future<ScrapeBatchResult> scrape(
    List<Target> targets,
    Cancellation cancellation,
    FutureOr<void> Function(ScrapeProgress) progress, {
    int? limit,
  });
}

final class AuditBatch {
  AuditBatch(
    Iterable<Audit> audits,
    Iterable<String> failedIds,
    Iterable<Map<String, Object?>> diagnostics,
  ) : audits = List.unmodifiable(audits),
      failedIds = Set.unmodifiable(failedIds),
      diagnostics = List.unmodifiable(diagnostics.map(immutableJsonMap));
  final List<Audit> audits;
  final Set<String> failedIds;
  final List<Map<String, Object?>> diagnostics;
}

sealed class AuditProgress {
  const AuditProgress(this.chunk, this.chunkCount, this.completed, this.total);
  final int chunk, chunkCount, completed, total;
}

final class AuditingChunkStarted extends AuditProgress {
  const AuditingChunkStarted(
    super.chunk,
    super.chunkCount,
    super.completed,
    super.total,
  );
}

final class AuditingChunkCompleted extends AuditProgress {
  AuditingChunkCompleted(
    super.chunk,
    super.chunkCount,
    super.completed,
    super.total,
    Map<String, Object?> summary,
  ) : summary = immutableJsonMap(summary);
  final Map<String, Object?> summary;
}

abstract interface class Auditor {
  /// Public configuration only, never API keys or request headers.
  AuditConfiguration get configuration;
  Future<AuditBatch> audit(
    List<CandidateMatch> candidates,
    Cancellation cancellation,
    FutureOr<void> Function(AuditProgress) progress,
  );
}
