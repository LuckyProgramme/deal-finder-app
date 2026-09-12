import '../../domain/models/scrape.dart';
import '../../domain/models/immutable_json.dart';
import 'pipeline_state.dart';

sealed class PipelineEvent {
  PipelineEvent(this.status) : timestamp = DateTime.now().toUtc();
  final PipelineStatus status;
  final DateTime timestamp;
  String get runId => status.runId!;
}

final class PipelineProgress extends PipelineEvent {
  PipelineProgress(super.status);
}

final class RunStarted extends PipelineEvent {
  RunStarted(super.status);
}

final class TargetsLoaded extends PipelineEvent {
  TargetsLoaded(super.status, Iterable<String> targetIds)
    : targetIds = List.unmodifiable(targetIds);
  final List<String> targetIds;
}

final class SourceStarted extends PipelineEvent {
  SourceStarted(super.status, this.source);
  final ScrapeSource source;
}

final class SourceCompleted extends PipelineEvent {
  SourceCompleted(super.status, this.summary);
  final ScrapeSourceSummary summary;
}

final class CandidatesFiltered extends PipelineEvent {
  CandidatesFiltered(super.status, this.candidateCount, this.listingCount);
  final int candidateCount, listingCount;
}

final class AuditChunkStarted extends PipelineEvent {
  AuditChunkStarted(super.status, this.chunk, this.chunkCount);
  final int chunk, chunkCount;
}

final class AuditChunkCompleted extends PipelineEvent {
  AuditChunkCompleted(
    super.status,
    this.chunk,
    this.chunkCount,
    Map<String, Object?> summary,
  ) : summary = immutableJsonMap(summary);
  final int chunk, chunkCount;
  final Map<String, Object?> summary;
}

final class DealsPersisted extends PipelineEvent {
  DealsPersisted(super.status);
}

final class SheetsSyncCompleted extends PipelineEvent {
  SheetsSyncCompleted(super.status, {required this.succeeded});
  final bool succeeded;
}

final class RunCancelled extends PipelineEvent {
  RunCancelled(super.status);
}

final class RunFailed extends PipelineEvent {
  RunFailed(super.status);
}

final class RunCompleted extends PipelineEvent {
  RunCompleted(super.status, {required this.published});
  final bool published;
}
