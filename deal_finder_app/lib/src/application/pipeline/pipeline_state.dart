enum RunStage {
  idle,
  preparing,
  scraping,
  filtering,
  auditing,
  persisting,
  syncingSheets,
  completed,
  completedWithWarnings,
  cancelling,
  cancelled,
  failed,
}

final class PipelineStatus {
  const PipelineStatus({
    this.stage = RunStage.idle,
    this.message = 'Ready when you are.',
    this.completed = 0,
    this.total = 0,
    this.scraped = 0,
    this.deals = 0,
    this.runId,
    this.auditMode = false,
    this.currentTargetId,
    this.sourceLabel,
  });
  final RunStage stage;
  final String message;
  final int completed, total, scraped, deals;
  final String? runId, currentTargetId, sourceLabel;
  final bool auditMode;
  bool get running => !{
    RunStage.idle,
    RunStage.completed,
    RunStage.completedWithWarnings,
    RunStage.cancelled,
    RunStage.failed,
  }.contains(stage);
  double? get progress =>
      total > 0 ? (completed / total).clamp(0.0, 1.0) : null;
}
