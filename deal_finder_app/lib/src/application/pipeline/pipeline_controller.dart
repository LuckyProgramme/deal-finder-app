import 'dart:async';
import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../domain/models/deal.dart';
import '../../domain/models/run_snapshot.dart';
import '../../domain/matching/text_cleaner.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/matching/candidate_filter.dart';
import '../../domain/matching/deal_engine.dart';
import '../../domain/models/scrape.dart';
import '../../domain/models/run_configuration.dart';
import '../../domain/matching/report_redaction.dart';
import 'pipeline_ports.dart';
import 'pipeline_events.dart';
import 'pipeline_state.dart';
import 'cancellation.dart' hide RunCancelled;
import 'cancellation.dart' as cancellation_error show RunCancelled;
export 'pipeline_state.dart';
export 'pipeline_events.dart';

/// Admission result; the terminal outcome is available in [PipelineStatus].
enum RunStartResult { accepted, alreadyRunning, maintenanceInProgress }

final class LibraryMaintenance {
  LibraryMaintenance._();
}

typedef ResultSync = Future<void> Function(RunSnapshot, Cancellation);

final class PipelineController {
  PipelineController({
    required this.targets,
    required this.deals,
    required this.runs,
    required this.marketplace,
    required this.createAuditor,
    this.syncResults,
    this.createSync,
  });
  final TargetRepository targets;
  final DealRepository deals;
  final RunRepository runs;
  final Marketplace marketplace;
  final Future<Auditor> Function() createAuditor;
  final ResultSync? syncResults;
  final Future<ResultSync?> Function()? createSync;
  final _events = StreamController<PipelineEvent>.broadcast();
  Stream<PipelineEvent> get events => _events.stream;
  PipelineStatus status = const PipelineStatus();
  Cancellation? _cancellation;
  bool _runActive = false;
  LibraryMaintenance? _maintenance;
  bool get busy => _runActive || _maintenance != null;
  LibraryMaintenance acquireMaintenance() {
    if (busy) {
      throw StateError(
        'Wait for the current scan or backup operation to finish.',
      );
    }
    return _maintenance = LibraryMaintenance._();
  }

  void releaseMaintenance(LibraryMaintenance lease) {
    if (!identical(_maintenance, lease)) {
      throw StateError('Invalid library operation ownership.');
    }
    _maintenance = null;
  }

  void _emit(
    RunStage stage,
    String message, {
    int completed = 0,
    int total = 0,
    int? scraped,
    int? found,
    ScrapeSource? source,
    PipelineEvent Function(PipelineStatus)? event,
  }) {
    status = PipelineStatus(
      stage: stage,
      message: message,
      completed: completed,
      total: total,
      scraped: scraped ?? status.scraped,
      deals: found ?? status.deals,
      runId: status.runId,
      auditMode: status.auditMode,
      currentTargetId: source?.currentTargetId,
      sourceLabel: source?.label,
    );
    _send(event?.call(status) ?? PipelineProgress(status));
  }

  void _send(PipelineEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void cancel() {
    if (!status.running) return;
    _cancellation?.cancel();
    _emit(RunStage.cancelling, 'Finishing the current step before stopping…');
  }

  Future<RunStartResult> start({
    bool auditMode = false,
    Set<String>? targetIds,
    int? limit,
  }) async {
    if (_runActive) return RunStartResult.alreadyRunning;
    if (_maintenance != null) return RunStartResult.maintenanceInProgress;
    if (limit != null && limit < 1) {
      throw ArgumentError('Limit must be positive.');
    }
    _runActive = true;
    final requestedIds = targetIds == null ? null : Set<String>.of(targetIds);
    final id = const Uuid().v4(),
        started = DateTime.now().toUtc(),
        cancellation = Cancellation();
    _cancellation = cancellation;
    status = PipelineStatus(runId: id, auditMode: auditMode);
    _emit(
      RunStage.preparing,
      auditMode
          ? 'Preparing a read-only audit…'
          : 'Getting your targets ready…',
      event: RunStarted.new,
    );
    final sourceSummaries = <Map<String, Object?>>[],
        chunkSummaries = <Map<String, Object?>>[];
    RunConfiguration? configuration;
    final report = <String, Object?>{
      'runId': id,
      'auditMode': auditMode,
      'configuration': {'limitPerSource': limit, 'auditMode': auditMode},
      'sources': sourceSummaries,
      'chunks': chunkSummaries,
      'published': false,
    };
    Future<void> record({bool terminal = false}) => runs.saveRun(
      RunRecord(
        id: id,
        startedAt: started,
        stage: status.stage.name,
        finishedAt: terminal ? DateTime.now().toUtc() : null,
        scraped: status.scraped,
        deals: status.deals,
        error:
            {
              RunStage.failed,
              RunStage.completedWithWarnings,
            }.contains(status.stage)
            ? status.message
            : null,
        auditReport: jsonEncode(redactedReport(report)),
        configuration: configuration,
      ),
    );
    try {
      configuration = RunConfiguration(
        auditMode: auditMode,
        requestedTargetIds: requestedIds,
        limitPerSource: limit,
      );
      await record();
      final snapshot = (await targets.loadTargets())
          .where(
            (t) =>
                t.enabled &&
                (requestedIds == null || requestedIds.contains(t.id)),
          )
          .toList();
      cancellation.check();
      configuration = configuration.withResolved(targets: snapshot);
      // Persist exact target policy before credential resolution can fail.
      await record();
      (report['configuration'] as Map<String, Object?>)['targets'] = snapshot
          .map(
            (t) => {
              'id': t.id,
              'name': t.name,
              'revision': t.revision,
              'dealPrice': t.dealPrice.centavos,
              'retailPrice': t.retailPrice?.centavos,
              'searchMode': t.searchMode.name,
              'category': t.category,
              'type': t.type.name,
              'allowBundle': t.allowBundle,
              'downsizingKeywords': t.downsizingKeywords,
              'freebieKeywords': t.freebieKeywords,
            },
          )
          .toList();
      _send(TargetsLoaded(status, snapshot.map((t) => t.id)));
      if (snapshot.isEmpty) {
        _emit(RunStage.completed, 'Add a target to begin your search.');
        await record(terminal: true);
        _send(RunCompleted(status, published: false));
        return RunStartResult.accepted;
      }
      // Resolve credentials before spending time scraping. Tests inject an auditor.
      final auditor = await createAuditor();
      final auditConfiguration = auditor.configuration;
      configuration = configuration.withResolved(auditor: auditConfiguration);
      await record();
      (report['configuration'] as Map<String, Object?>)['auditor'] =
          auditConfiguration.toJson();
      final sync = auditMode
          ? null
          : (createSync == null ? syncResults : await createSync!());
      (report['configuration'] as Map<String, Object?>)['postRunSyncEnabled'] =
          sync != null;
      configuration = configuration.withResolved(
        postRunSyncEnabled: sync != null,
      );
      cancellation.check();
      await record();
      final batch = await marketplace.scrape(snapshot, cancellation, (
        progress,
      ) async {
        final summary = progress is ScrapeSourceCompleted
            ? progress.summary
            : null;
        if (summary != null) sourceSummaries.add(summary.toJson());
        report['activeSource'] = summary == null
            ? {
                'label': progress.source.label,
                'targetIds': progress.source.targets.map((t) => t.id).toList(),
              }
            : null;
        _emit(
          cancellation.cancelled ? RunStage.cancelling : RunStage.scraping,
          summary == null
              ? 'Searching ${progress.source.label}…'
              : summary.succeeded
              ? 'Finished ${progress.source.label}: ${summary.retained} listings'
              : '${progress.source.label} could not finish',
          completed: progress.index + (summary == null ? 0 : 1),
          total: progress.total,
          source: summary == null ? progress.source : null,
          event: (s) => summary == null
              ? SourceStarted(s, progress.source)
              : SourceCompleted(s, summary),
        );
        await record();
      }, limit: limit);
      final listings = batch.listings;
      report['coverageComplete'] = batch.complete;
      report['scraped'] = listings.length;
      _emit(
        RunStage.filtering,
        'Checking prices and matching your devices…',
        scraped: listings.length,
      );
      await record();
      final candidates = <CandidateMatch>[];
      for (var i = 0; i < listings.length; i++) {
        cancellation.check();
        candidates.addAll(findCandidates(listings[i], snapshot));
        if (i % 10 == 0) await Future<void>.delayed(Duration.zero);
      }
      _emit(
        RunStage.auditing,
        'Reviewing ${candidates.map((c) => c.listing.id).toSet().length} promising listings…',
        event: (s) => CandidatesFiltered(
          s,
          candidates.length,
          candidates.map((c) => c.listing.id).toSet().length,
        ),
      );
      await record();
      final audits = await auditor.audit(candidates, cancellation, (
        progress,
      ) async {
        final finished = progress is AuditingChunkCompleted;
        final summary = finished ? progress.summary : null;
        if (summary != null) chunkSummaries.add(summary);
        report['activeAuditChunk'] = finished ? null : progress.chunk;
        _emit(
          RunStage.auditing,
          finished
              ? 'Reviewed ${progress.completed} of ${progress.total} listings'
              : 'Reviewing batch ${progress.chunk + 1} of ${progress.chunkCount}…',
          completed: progress.completed,
          total: progress.total,
          event: (s) => summary == null
              ? AuditChunkStarted(s, progress.chunk, progress.chunkCount)
              : AuditChunkCompleted(
                  s,
                  progress.chunk,
                  progress.chunkCount,
                  redactedReport(summary) as Map<String, Object?>,
                ),
        );
        await record();
      });
      cancellation.check();
      final confirmed = acceptGemini(candidates, audits.audits);
      final local = auditMode
          ? localFallback(candidates, audits.failedIds)
          : <Deal>[];
      report.addAll({
        'runId': id,
        'auditMode': auditMode,
        'scraped': listings.length,
        'candidates': candidates.length,
        'confirmed': confirmed.length,
        'localFallback': local.length,
        'failedIds': audits.failedIds.toList(),
        'chunks': audits.diagnostics,
        'decisions': [...confirmed, ...local]
            .map(
              (d) => {
                'id': d.id,
                'price': d.price.centavos,
                'savings': d.savings.centavos,
                'provenance': d.provenance.toJson(),
              },
            )
            .toList(),
      });
      final canPublish = !auditMode && batch.complete;
      if (canPublish) {
        _emit(
          RunStage.persisting,
          'Saving your deals…',
          found: confirmed.length,
        );
        cancellation.check();
        await deals.persistDeals(
          confirmed,
          id,
          listings: listings,
          targets: snapshot,
        );
        report['published'] = true;
        _send(DealsPersisted(status));
        cancellation.check();
      }
      String? syncWarning;
      if (canPublish && sync != null) {
        _emit(RunStage.syncingSheets, 'Syncing results to Google Sheets…');
        await record();
        try {
          final committed = await deals.loadLatestSnapshot();
          if (committed == null || committed.runId != id) {
            throw StateError('Committed scan snapshot unavailable.');
          }
          await sync(committed, cancellation);
          _send(SheetsSyncCompleted(status, succeeded: true));
        } on cancellation_error.RunCancelled {
          rethrow;
        } catch (_) {
          syncWarning = 'Deals saved. Sheets sync needs attention.';
          _send(SheetsSyncCompleted(status, succeeded: false));
        }
      }
      cancellation.check();
      _emit(
        !batch.complete || syncWarning != null || audits.failedIds.isNotEmpty
            ? RunStage.completedWithWarnings
            : RunStage.completed,
        (!batch.complete
                ? '${batch.sources.any((source) => source.httpStatus == 403) ? 'Carousell refused access (HTTP 403). ' : ''}Scan coverage is incomplete. Previous results kept; no results published or synced. See Run history for details.'
                : null) ??
            syncWarning ??
            (auditMode
                ? 'Audit complete: ${confirmed.length} verified, ${local.length} local comparisons. No results published.'
                : '${confirmed.length} deals found.${audits.failedIds.isNotEmpty ? ' ${audits.failedIds.length} listings could not be verified.' : ''}'),
        found: confirmed.length,
      );
      await record(terminal: true);
      _send(RunCompleted(status, published: canPublish));
    } on cancellation_error.RunCancelled {
      _emit(RunStage.cancelled, 'Scan stopped. You can start again anytime.');
      _send(RunCancelled(status));
      try {
        await record(terminal: true);
      } catch (_) {
        _emit(
          RunStage.cancelled,
          'Scan stopped, but its status could not be saved. Check device storage.',
        );
      }
    } catch (e) {
      _emit(
        RunStage.failed,
        e is StateError ? redactSecrets(redactPii(e.message.toString())) : 'Scan could not finish. Check your connection and setup, then retry.',
        event: RunFailed.new,
      );
      try {
        await record(terminal: true);
      } catch (_) {
        /* UI still exposes failure if disk is unavailable. */
      }
    } finally {
      _cancellation = null;
      _runActive = false;
    }
    return RunStartResult.accepted;
  }

  Future<void> dispose() async {
    cancel();
    await _events.close();
  }
}
