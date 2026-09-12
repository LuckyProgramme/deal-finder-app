import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/local/app_database.dart';
import '../data/carousell/carousell_service.dart';
import '../data/gemini/gemini_service.dart';
import '../domain/models/target.dart';
import '../domain/models/deal.dart';
import '../domain/repositories/repositories.dart';
import '../platform/credentials/credential_store.dart';
import '../application/pipeline/pipeline_controller.dart';
import '../application/pipeline/cancellation.dart';
import '../application/sync/sync_coordinator.dart';
import '../data/sheets/sheets_gateway.dart';
import '../data/sheets/sheet_models.dart';
import '../domain/models/sync_job.dart';
import '../domain/repositories/backup_repository.dart';
import '../application/backup/backup_coordinator.dart';
import '../platform/files/backup_files.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
final targetRepositoryProvider = Provider<TargetRepository>(
  (ref) => ref.watch(databaseProvider),
);
final dealRepositoryProvider = Provider<DealRepository>(
  (ref) => ref.watch(databaseProvider),
);
final runRepositoryProvider = Provider<RunRepository>(
  (ref) => ref.watch(databaseProvider),
);
final appPreferencesProvider = Provider<AppPreferencesRepository>(
  (ref) => ref.watch(databaseProvider),
);
final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => ref.watch(databaseProvider),
);
final backupFilesProvider = Provider<BackupFiles>(
  (ref) => const NativeBackupFiles(),
);
final backupCoordinatorProvider = Provider<BackupCoordinator>(
  (ref) => BackupCoordinator(
    ref.watch(backupRepositoryProvider),
    ref.watch(pipelineProvider),
    ref.watch(syncCoordinatorProvider),
  ),
);
final credentialProvider = Provider<CredentialStore>(
  (ref) => const SecureCredentials(),
);
final syncRepositoryProvider = Provider<SyncRepository>(
  (ref) => ref.watch(databaseProvider),
);
final syncCoordinatorProvider = Provider<SyncCoordinator>(
  (ref) => SyncCoordinator(ref.watch(syncRepositoryProvider)),
);
final syncJobsProvider = StreamProvider<List<SyncJob>>(
  (ref) => ref.watch(syncRepositoryProvider).watchSyncJobs(),
);
typedef GatewayFactory = Future<SheetsGateway> Function(
  Cancellation, {
  String? destination,
});
final sheetsGatewayFactoryProvider = Provider<GatewayFactory>(
  (ref) => (c, {destination}) async {
    final store = ref.read(credentialProvider),
        account = await ref.read(credentialProvider).read('serviceAccount');
    if (account == null || account.isEmpty) {
      throw StateError('Save a service account in Settings before connecting.');
    }
    return GoogleSheetsGateway.connect(
      account,
      destination ?? await store.read('spreadsheetId') ?? '',
      c,
    );
  },
);
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 15)));
  ref.onDispose(() => dio.close(force: true));
  return dio;
});
final targetsProvider = StreamProvider<List<Target>>(
  (ref) => ref.watch(targetRepositoryProvider).watchTargets(),
);
final dealsProvider = StreamProvider<List<Deal>>(
  (ref) => ref.watch(dealRepositoryProvider).watchDeals(),
);
final currentDealsProvider = StreamProvider<List<Deal>>(
  (ref) => ref.watch(dealRepositoryProvider).watchCurrentDeals(),
);
final runsProvider = StreamProvider<List<RunRecord>>(
  (ref) => ref.watch(runRepositoryProvider).watchRuns(),
);
final pipelineProvider = Provider<PipelineController>((ref) {
  final controller = PipelineController(
    targets: ref.watch(targetRepositoryProvider),
    deals: ref.watch(dealRepositoryProvider),
    runs: ref.watch(runRepositoryProvider),
    marketplace: CarousellService(ref.watch(dioProvider)),
    createSync: () async {
      final store = ref.read(credentialProvider);
      if (await store.read('postRunSync') != 'true') return null;
      final account = await store.read('serviceAccount') ?? '';
      final destination = await store.read('spreadsheetId') ?? '';
      final coordinator = ref.read(syncCoordinatorProvider);
      return (snapshot, cancellation) async {
        final job = await coordinator.enqueue(
          snapshot,
          spreadsheetId(destination),
        );
        final gateway = await GoogleSheetsGateway.connect(
          account,
          destination,
          cancellation,
        );
        try {
          await coordinator.execute(job, gateway, cancellation);
        } finally {
          gateway.close();
        }
      };
    },
    createAuditor: () async {
      final store = ref.read(credentialProvider),
          key = await ref.read(credentialProvider).read('geminiKey');
      if (key == null || key.trim().isEmpty) {
        throw StateError('Add your Gemini key in Settings before scanning.');
      }
      return GeminiService(
        ref.read(dioProvider),
        key: key,
        model: await store.read('geminiModel') ?? 'gemini-3.1-flash-lite',
        prompt: await rootBundle.loadString('assets/prompts/audit_v1.txt'),
      );
    },
  );
  ref.onDispose(controller.dispose);
  return controller;
});
final pipelineStatusProvider = StreamProvider<PipelineStatus>((ref) async* {
  final controller = ref.watch(pipelineProvider);
  yield controller.status;
  yield* controller.events.map((e) => e.status);
});
