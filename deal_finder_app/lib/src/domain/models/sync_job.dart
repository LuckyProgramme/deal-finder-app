import 'run_snapshot.dart';

final class SyncJob {
  SyncJob({
    required this.id,
    required this.destination,
    required this.snapshot,
    required this.payloadHash,
    this.attempts = 0,
    this.state = 'queued',
    this.error,
    Iterable<String> completedTabs = const [],
  }) : completedTabs = Set.unmodifiable(completedTabs);
  final String id, destination, payloadHash, state;
  final String? error;
  final RunSnapshot snapshot;
  final int attempts;
  final Set<String> completedTabs;
  SyncJob progress({
    int? attempts,
    String? state,
    String? error,
    Iterable<String>? completedTabs,
  }) => SyncJob(
    id: id,
    destination: destination,
    snapshot: snapshot,
    payloadHash: payloadHash,
    attempts: attempts ?? this.attempts,
    state: state ?? this.state,
    error: error,
    completedTabs: completedTabs ?? this.completedTabs,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'destination': destination,
    'snapshot': snapshot.toJson(),
    'payloadHash': payloadHash,
    'attempts': attempts,
    'state': state,
    'error': error,
    'completedTabs': completedTabs.toList(),
  };
  factory SyncJob.fromJson(Map<String, dynamic> j) => SyncJob(
    id: j['id'] as String,
    destination: j['destination'] as String,
    snapshot: RunSnapshot.fromJson(j['snapshot'] as Map<String, dynamic>),
    payloadHash: j['payloadHash'] as String,
    attempts: j['attempts'] as int,
    state: j['state'] as String,
    error: j['error'] as String?,
    completedTabs: (j['completedTabs'] as List).cast<String>(),
  );
}
