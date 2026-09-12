import 'dart:async';
import 'dart:ui' show SemanticsRole;

import 'package:deal_finder_app/src/app/deal_finder_app.dart';
import 'package:deal_finder_app/src/app/providers.dart';
import 'package:deal_finder_app/src/application/pipeline/pipeline_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fakes.dart';

void main() {
  testWidgets('scan progress exposes valid native accessibility values', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();
    try {
      final library = MemoryLibrary(targets: [sampleTarget]);
      final pipeline = fakePipeline(library);
      final updates = StreamController<PipelineStatus>();
      addTearDown(library.dispose);
      addTearDown(pipeline.dispose);
      addTearDown(updates.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            targetRepositoryProvider.overrideWithValue(library),
            dealRepositoryProvider.overrideWithValue(library),
            runRepositoryProvider.overrideWithValue(library),
            appPreferencesProvider.overrideWithValue(library),
            credentialProvider.overrideWithValue(MemoryCredentials()),
            pipelineProvider.overrideWithValue(pipeline),
            pipelineStatusProvider.overrideWith((ref) => updates.stream),
          ],
          child: const DealFinderApp(),
        ),
      );
      await tester.pumpAndSettle();

      for (final counts in [(0, 1), (1, 2), (1, 1), (3, 2), (0, 0)]) {
        final state = PipelineStatus(
          stage: RunStage.scraping,
          message: 'Searching Video Gaming',
          completed: counts.$1,
          total: counts.$2,
        );
        updates.add(state);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        final data = tester
            .getSemantics(find.byType(LinearProgressIndicator))
            .getSemanticsData();
        expect(data.label, contains(state.message));
        if (state.total > 0) {
          expect(data.role, SemanticsRole.progressBar);
          expect(data.value, '${(state.progress! * 100).round()}');
          expect(data.minValue, '0');
          expect(data.maxValue, '100');
          expect(data.label, contains('${counts.$1} of ${counts.$2}'));
        } else {
          expect(data.role, SemanticsRole.loadingSpinner);
          expect(data.value, isEmpty);
        }
        expect(find.text('Cancel scan'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      updates.add(const PipelineStatus(stage: RunStage.cancelled));
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text('Scan now'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    } finally {
      semantics.dispose();
    }
  });
}
