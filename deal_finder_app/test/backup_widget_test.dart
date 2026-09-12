import 'dart:async';
import 'dart:convert';

import 'package:deal_finder_app/src/app/providers.dart';
import 'package:deal_finder_app/src/design_system/terra_theme.dart';
import 'package:deal_finder_app/src/domain/models/backup_archive.dart';
import 'package:deal_finder_app/src/domain/models/sync_job.dart';
import 'package:deal_finder_app/src/domain/repositories/backup_repository.dart';
import 'package:deal_finder_app/src/domain/repositories/repositories.dart';
import 'package:deal_finder_app/src/features/diagnostics/backup_dialog.dart';
import 'package:deal_finder_app/src/platform/files/backup_files.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

BackupArchive fixture({bool target = false}) => BackupArchive.decode(
  jsonEncode({
    'format': 'deal-finder-library',
    'version': 1,
    'databaseSchema': 2,
    'createdAt': DateTime.utc(2026, 9, 10).toIso8601String(),
    'targets': [
      if (target)
        {
          'target': sampleTarget.toJson(),
          'createdAt': DateTime.utc(2026).toIso8601String(),
          'updatedAt': DateTime.utc(2026).toIso8601String(),
        },
    ],
    'deals': [],
    'runs': [],
    'snapshots': [],
    'syncJobs': [],
    'currentRunId': null,
  }),
);

class MemoryBackups implements BackupRepository, SyncRepository {
  BackupArchive value = fixture();
  int revision = 0, restores = 0;
  @override
  Future<BackupArchive> exportBackup() async => value;
  @override
  Future<String> backupFingerprint() async => '$revision';
  @override
  Future<void> restoreBackup(
    BackupArchive archive, {
    required String expectedFingerprint,
  }) async {
    if (expectedFingerprint != '$revision') {
      throw StateError(
        'Local data changed after the preview. Review the backup again.',
      );
    }
    value = archive;
    restores++;
    revision++;
  }

  @override
  Future<void> saveSyncJob(SyncJob job) async => throw UnimplementedError();
  @override
  Stream<List<SyncJob>> watchSyncJobs() => Stream.value([]);
}

class FakeBackupFiles implements BackupFiles {
  String? contents = fixture(target: true).encode();
  bool saved = true;
  BackupArchive? exported;
  Completer<String?>? pending;
  @override
  Future<String?> pickBackup() async =>
      pending == null ? contents : await pending!.future;
  @override
  Future<bool> saveBackup(BackupArchive archive) async {
    exported = archive;
    return saved;
  }
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    for (final font in {
      'Literata': 'literata',
      'Nunito Sans': 'nunitosans',
    }.entries) {
      await (FontLoader(
        font.key,
      )..addFont(rootBundle.load('assets/fonts/${font.value}.ttf'))).load();
    }
  });
  late MemoryBackups repository;
  late FakeBackupFiles files;
  Future<void> open(WidgetTester tester, {double scale = 1}) async {
    repository = MemoryBackups();
    files = FakeBackupFiles();
    final library = MemoryLibrary();
    final pipeline = fakePipeline(library);
    addTearDown(library.dispose);
    addTearDown(pipeline.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          backupRepositoryProvider.overrideWithValue(repository),
          backupFilesProvider.overrideWithValue(files),
          syncRepositoryProvider.overrideWithValue(repository),
          pipelineProvider.overrideWithValue(pipeline),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: Terra.theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(body: BackupDialog()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'restore requires preview, acknowledgement and explicit replacement',
    (tester) async {
      await open(tester);
      await tester.tap(find.text('Choose backup to restore'));
      await tester.pumpAndSettle();
      expect(
        find.text('Targets: 0 on this device; 1 in backup'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Replace local library'),
            )
            .onPressed,
        isNull,
      );
      expect(repository.restores, 0);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.tap(find.text('Replace local library'));
      await tester.pumpAndSettle();
      expect(repository.restores, 1);
      expect(repository.value.counts['targets'], 1);
      expect(find.textContaining('Library restored.'), findsOneWidget);
    },
  );

  for (final width in [412, 1280]) {
    testWidgets('backup dialog golden $width', (tester) async {
      tester.view.physicalSize = Size(
        width.toDouble(),
        width == 412 ? 892 : 800,
      );
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester);
      if (width == 1280) {
        await tester.tap(find.text('Choose backup to restore'));
        await tester.pumpAndSettle();
      }
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/backup_$width.png'),
      );
      expect(tester.takeException(), isNull);
      if (width == 1280) {
        await tester.tap(find.text('Cancel restore'));
        await tester.pumpAndSettle();
      }
    });
  }

  testWidgets('cancel preview and cancel picker leave data unchanged', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Choose backup to restore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel restore'));
    await tester.pumpAndSettle();
    expect(repository.restores, 0);
    files.contents = null;
    await tester.tap(find.text('Choose backup to restore'));
    await tester.pumpAndSettle();
    expect(repository.restores, 0);
    expect(find.text('Restore cancelled.'), findsOneWidget);
  });

  testWidgets(
    'invalid file is rejected without preview or contents in the error',
    (tester) async {
      await open(tester);
      files.contents = '{fixture-secret-private';
      await tester.tap(find.text('Choose backup to restore'));
      await tester.pumpAndSettle();
      expect(find.text('Replace local library?'), findsNothing);
      expect(find.textContaining('Invalid or inconsistent'), findsOneWidget);
      expect(find.textContaining('fixture-secret-private'), findsNothing);
      expect(repository.restores, 0);
    },
  );

  testWidgets('intervening edit causes visible stale-preview error', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Choose backup to restore'));
    await tester.pumpAndSettle();
    repository.revision++;
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Replace local library'));
    await tester.pumpAndSettle();
    expect(repository.restores, 0);
    expect(find.textContaining('Local data changed'), findsOneWidget);
  });

  testWidgets(
    'export reports native picker cancellation and success accurately',
    (tester) async {
      await open(tester);
      files.saved = false;
      await tester.tap(find.text('Export backup'));
      await tester.pumpAndSettle();
      expect(find.text('Export cancelled.'), findsOneWidget);
      files.saved = true;
      await tester.tap(find.text('Export backup'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Backup saved.'), findsOneWidget);
      expect(files.exported, isNotNull);
      expect(repository.restores, 0);
    },
  );

  testWidgets(
    'mobile 200 percent text scrolls and operation disables duplicate actions',
    (tester) async {
      tester.view.physicalSize = const Size(412, 892);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await open(tester, scale: 2);
      expect(tester.takeException(), isNull);
      files.pending = Completer<String?>();
      await tester.ensureVisible(find.text('Choose backup to restore'));
      await tester.tap(find.text('Choose backup to restore'));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Export backup'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Close'))
            .onPressed,
        isNull,
      );
      files.pending!.complete(null);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
