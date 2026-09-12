import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import 'package:deal_finder_app/src/app/deal_finder_app.dart';
import 'package:deal_finder_app/src/app/providers.dart';
import 'package:deal_finder_app/src/application/pipeline/pipeline_controller.dart';
import 'package:deal_finder_app/src/data/local/app_database.dart';
import 'package:deal_finder_app/src/platform/credentials/credential_store.dart';

// These deterministic adapters are compiled only into the test application.
import '../test/support/fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'native credential storage, target editor, scan, flags and database reopen',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Running Deal Finder device checks…')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      debugPrint('[native smoke] Checking protected credential storage');
      const credentials = SecureCredentials();
      final probe = 'integrationProbe-${const Uuid().v4()}';
      try {
        await credentials
            .write(probe, 'non-secret-native-smoke-value')
            .timeout(const Duration(seconds: 20));
        expect(
          await credentials.read(probe).timeout(const Duration(seconds: 20)),
          'non-secret-native-smoke-value',
        );
      } finally {
        // Delete only this test's unique key, never the user's credentials.
        await credentials.write(probe, '').timeout(const Duration(seconds: 20));
      }
      debugPrint(
        '[native smoke] Credential storage passed; opening isolated database',
      );

      final temporary = await getTemporaryDirectory();
      final file = File(
        '${temporary.path}/deal-finder-smoke-${const Uuid().v4()}.sqlite',
      );
      var db = AppDatabase(NativeDatabase.createInBackground(file));
      PipelineController? pipeline;

      Future<void> launch() async {
        pipeline = PipelineController(
          targets: db,
          deals: db,
          runs: db,
          marketplace: FakeMarketplace(),
          createAuditor: () async => FakeAuditor(),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              pipelineProvider.overrideWithValue(pipeline!),
              credentialProvider.overrideWithValue(MemoryCredentials()),
            ],
            child: const DealFinderApp(),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> visible(Finder finder) async {
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
      }

      Future<void> tap(Finder finder) async {
        await visible(finder);
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      try {
        await launch();
        expect(find.text('Welcome to Deal Finder'), findsOneWidget);
        await tap(find.text('Set up later'));
        expect(await db.hasCompletedOnboarding(), isTrue);
        await tap(find.text('Add target'));
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Device or game name'),
          'Nintendo Switch OLED',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Target price (PHP)'),
          '12000',
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tap(find.text('Save target'));
        expect((await db.loadTargets()).single.name, 'Nintendo Switch OLED');
        debugPrint(
          '[native smoke] Target editor passed; starting fixture scan',
        );

        await tap(find.text('Scan now'));
        for (
          var attempt = 0;
          attempt < 200 && pipeline!.status.running;
          attempt++
        ) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(pipeline!.status.stage, RunStage.completed);
        expect((await db.loadLatestSnapshot())!.deals, hasLength(1));
        final configuration =
            (await db.watchRuns().first).single.configuration!;
        expect(configuration.targets!.single.name, 'Nintendo Switch OLED');
        expect(configuration.auditor!.model, 'fixture');
        debugPrint(
          '[native smoke] Scan passed; checking favorites and dismiss/undo',
        );

        await tap(find.text('Deals').last);
        await tap(find.byTooltip('Favorite Nintendo Switch OLED'));
        await tap(find.text('Dismiss').first);
        expect((await db.watchDeals().first).single.isDismissed, isTrue);
        await tap(find.text('Undo'));
        expect((await db.watchDeals().first).single.isDismissed, isFalse);
        expect((await db.watchDeals().first).single.isFavorite, isTrue);
        debugPrint('[native smoke] User flags passed; checking backup restore');
        final archive = await db.exportBackup();
        await db.deleteTarget((await db.loadTargets()).single.id);
        await db.setDealFlags(
          (await db.watchDeals().first).single.id,
          favorite: false,
        );
        await db.restoreBackup(
          archive,
          expectedFingerprint: await db.backupFingerprint(),
        );
        expect((await db.loadTargets()).single.name, 'Nintendo Switch OLED');
        expect((await db.watchDeals().first).single.isFavorite, isTrue);
        debugPrint('[native smoke] Backup restore passed; reopening database');

        // Reopen the actual file-backed native DB, not an in-memory fake.
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await pipeline!.dispose();
        pipeline = null;
        await db.close();
        db = AppDatabase(NativeDatabase.createInBackground(file));
        expect(await db.hasCompletedOnboarding(), isTrue);
        expect((await db.loadTargets()).single.dealPrice.centavos, 1200000);
        expect((await db.watchCurrentDeals().first).single.isFavorite, isTrue);
        expect((await db.loadLatestSnapshot())!.deals, hasLength(1));
        expect(
          (await db.watchRuns().first).single.configuration!.encode(),
          configuration.encode(),
        );
        await launch();
        expect(find.text('Welcome to Deal Finder'), findsNothing);
        await tap(find.text('Deals').last);
        await visible(find.byTooltip('Unfavorite Nintendo Switch OLED'));
        expect(
          find.byTooltip('Unfavorite Nintendo Switch OLED'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
        await pipeline?.dispose();
        await db.close();
        // File is a unique test artifact in this app's temporary directory.
        if (await file.exists()) await file.delete();
      }
    },
  );
}
