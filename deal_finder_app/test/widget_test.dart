import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deal_finder_app/src/app/deal_finder_app.dart';
import 'package:deal_finder_app/src/app/providers.dart';
import 'package:deal_finder_app/src/domain/models/target.dart';
import 'package:deal_finder_app/src/domain/models/money.dart';
import 'package:deal_finder_app/src/features/deals/deals_page.dart';

import 'support/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
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
  Future<void> launch(
    WidgetTester tester,
    MemoryLibrary library, {
    Size size = const Size(412, 892),
    double scale = 1,
    MemoryCredentials? credentials,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final pipeline = fakePipeline(library);
    addTearDown(pipeline.dispose);
    addTearDown(library.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          targetRepositoryProvider.overrideWithValue(library),
          dealRepositoryProvider.overrideWithValue(library),
          runRepositoryProvider.overrideWithValue(library),
          appPreferencesProvider.overrideWithValue(library),
          credentialProvider.overrideWithValue(
            credentials ?? MemoryCredentials(),
          ),
          pipelineProvider.overrideWithValue(pipeline),
        ],
        child: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: const DealFinderApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('empty mobile shell has exactly two destinations', (
    tester,
  ) async {
    await launch(tester, MemoryLibrary());
    expect(find.byType(NavigationDestination), findsNWidgets(2));
    expect(find.text('My targets'), findsOneWidget);
    expect(find.text('Make room for a good find'), findsOneWidget);
    await tester.tap(find.text('Deals').last);
    await tester.pumpAndSettle();
    expect(find.text('Your next find is taking root'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('first run explains setup and can be completed later', (
    tester,
  ) async {
    final library = MemoryLibrary(onboardingCompleted: false);
    await launch(tester, library);
    expect(find.text('Welcome to Deal Finder'), findsOneWidget);
    expect(find.textContaining('A Gemini API key is required'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(2));
    await tester.tap(find.text('Set up later'));
    await tester.pumpAndSettle();
    expect(library.onboardingCompleted, isTrue);
    expect(find.text('Welcome to Deal Finder'), findsNothing);
    expect(find.text('My targets'), findsOneWidget);
  });
  testWidgets('first-run setup saves a Gemini key and completes onboarding', (
    tester,
  ) async {
    final library = MemoryLibrary(onboardingCompleted: false);
    final credentials = MemoryCredentials();
    await launch(tester, library, credentials: credentials);
    await tester.enterText(
      find.widgetWithText(TextField, 'Gemini API key'),
      'owner-supplied-value',
    );
    final save = find.text('Save & continue');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(credentials.values['geminiKey'], 'owner-supplied-value');
    expect(credentials.values['geminiModel'], 'gemini-3.1-flash-lite');
    expect(library.onboardingCompleted, isTrue);
    expect(find.text('Welcome to Deal Finder'), findsNothing);
  });
  testWidgets('credential removal preserves library and onboarding state', (
    tester,
  ) async {
    final library = MemoryLibrary(targets: [sampleTarget]);
    final credentials = MemoryCredentials()
      ..values.addAll({
        'geminiKey': 'owner-supplied-value',
        'geminiModel': 'gemini-3.1-flash-lite',
        'serviceAccount': 'owner-supplied-account',
        'spreadsheetId': 'owner-sheet',
        'postRunSync': 'true',
      });
    await launch(tester, library, credentials: credentials);
    await tester.tap(find.byTooltip('Settings and diagnostics'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings & connections'));
    await tester.pumpAndSettle();
    final remove = find.text('Remove credentials');
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove credentials').last);
    await tester.pumpAndSettle();
    expect(credentials.values, isEmpty);
    expect(library.targets.single.id, sampleTarget.id);
    expect(library.onboardingCompleted, isTrue);
    expect(
      find.textContaining('Your local library was not changed'),
      findsOneWidget,
    );
  });
  testWidgets('200 percent text remains usable on compact mobile', (
    tester,
  ) async {
    await launch(
      tester,
      MemoryLibrary(targets: [sampleTarget], deals: [sampleDeal]),
      scale: 2,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Deals').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/deals_mobile_text200.png'),
    );
  });
  testWidgets('target editor validates and persists a complete target', (
    tester,
  ) async {
    final library = MemoryLibrary();
    await launch(tester, library, size: const Size(1280, 1100));
    await tester.tap(find.text('Add target'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Device or game name'),
      'Steam Deck OLED',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Target price (PHP)'),
      '25000.50',
    );
    final save = find.text('Save target');
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(library.targets.single.name, 'Steam Deck OLED');
    expect(library.targets.single.dealPrice.centavos, 2500050);
    expect(tester.takeException(), isNull);
  });
  testWidgets('favorite and dismiss with undo update persisted flags', (
    tester,
  ) async {
    final library = MemoryLibrary(deals: [sampleDeal]);
    await launch(tester, library, size: const Size(1280, 1500));
    await tester.tap(find.text('Deals').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Favorite Nintendo Switch OLED'));
    await tester.pumpAndSettle();
    expect(library.deals.single.isFavorite, isTrue);
    await tester.ensureVisible(find.text('Dismiss').first);
    await tester.tap(find.text('Dismiss').first);
    await tester.pumpAndSettle();
    expect(library.deals.single.isDismissed, isTrue);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(library.deals.single.isDismissed, isFalse);
  });
  for (final size in [
    const Size(390, 844),
    const Size(412, 892),
    const Size(600, 900),
    const Size(840, 900),
    const Size(1280, 800),
  ]) {
    testWidgets('Targets golden ${size.width.toInt()} and no overflow', (
      tester,
    ) async {
      await launch(
        tester,
        MemoryLibrary(
          targets: [
            sampleTarget,
            Target(
              id: 't2',
              name: 'Steam Deck OLED',
              category: 'Computers & Tech',
              dealPrice: const Money(2500000),
            ),
          ],
        ),
        size: size,
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/targets_${size.width.toInt()}.png'),
      );
    });
  }
  testWidgets('Deals desktop golden and long title layout', (tester) async {
    await launch(
      tester,
      MemoryLibrary(deals: [sampleDeal]),
      size: const Size(1280, 1100),
    );
    await tester.tap(find.text('Deals').last);
    await tester.pumpAndSettle();
    expect(find.byType(DealCard), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/deals_1280.png'),
    );
  });
}
