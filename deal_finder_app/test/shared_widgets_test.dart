import 'package:deal_finder_app/src/features/shell/shared_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final icon in [
    null,
    Icons.visibility_outlined,
    Icons.verified_outlined,
  ]) {
    testWidgets('badge announces one complete label, icon=$icon', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: TerraBadge('Verified by Gemini', icon: icon)),
          ),
        );
        expect(find.bySemanticsLabel('Verified by Gemini'), findsOneWidget);
        final node = tester.getSemantics(find.byType(TerraBadge));
        expect(node.label, 'Verified by Gemini');
        expect(node.childrenCount, 0);
        expect(tester.takeException(), isNull);
      } finally {
        semantics.dispose();
      }
    });
  }
  test('date helper uses device-local time and explicit 24-hour fields', () {
    final instant = DateTime.utc(2026, 9, 11, 23, 7);
    final local = instant.toLocal();
    expect(
      localDate(instant),
      '${local.year}-${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')} ${local.hour.toString().padLeft(2, '0')}:07',
    );
    expect(localDate(local), localDate(instant));
  });
}
