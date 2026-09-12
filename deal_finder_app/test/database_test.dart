import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deal_finder_app/src/data/local/app_database.dart';
import 'package:deal_finder_app/src/domain/models/target.dart';
import 'package:deal_finder_app/src/domain/repositories/repositories.dart';

import 'support/fakes.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());
  test(
    'current-deals typed join reacts to deals and current-run pointer',
    () async {
      final updates = StreamIterator(db.watchCurrentDeals());
      try {
        expect(await updates.moveNext(), isTrue);
        expect(updates.current, isEmpty);
        await db.persistDeals([sampleDeal], 'first');
        expect(await updates.moveNext(), isTrue);
        expect(updates.current.single.id, sampleDeal.id);
        await db.setDealFlags(sampleDeal.id, favorite: true);
        expect(await updates.moveNext(), isTrue);
        expect(updates.current.single.isFavorite, isTrue);
        await db.persistDeals([], 'empty');
        expect(await updates.moveNext(), isTrue);
        expect(updates.current, isEmpty);
        expect((await db.watchDeals().first).single.isFavorite, isTrue);
      } finally {
        await updates.cancel();
      }
    },
  );
  test(
    'target round trip preserves policy, rejects duplicates and stale edits',
    () async {
      await db.saveTarget(sampleTarget);
      expect((await db.loadTargets()).single.toJson(), sampleTarget.toJson());
      await db.saveTarget(sampleTarget);
      await expectLater(db.saveTarget(sampleTarget), throwsStateError);
      final duplicate = Target.fromJson({
        ...sampleTarget.toJson(),
        'id': 'duplicate',
        'name': sampleTarget.name.toUpperCase(),
      });
      await expectLater(db.saveTarget(duplicate), throwsStateError);
      expect(await db.loadTargets(), hasLength(1));
    },
  );
  test(
    'rediscovery preserves user flags, first seen and target snapshot',
    () async {
      await db.saveTarget(sampleTarget);
      await db.persistDeals([sampleDeal], 'run-1');
      await db.setDealFlags(sampleDeal.id, favorite: true, dismissed: true);
      await db.persistDeals([sampleDeal], 'run-2');
      await db.deleteTarget(sampleTarget.id);
      final saved = (await db.watchDeals().first).single;
      expect(saved.isFavorite, isTrue);
      expect(saved.isDismissed, isTrue);
      expect(saved.firstSeen, sampleDeal.firstSeen);
      expect(saved.target.name, sampleTarget.name);
      expect(saved.provenance.toJson(), sampleDeal.provenance.toJson());
    },
  );
  test('startup recovers only unfinished runs', () async {
    final time = DateTime.utc(2026, 9, 9);
    await db.saveRun(RunRecord(id: 'a', startedAt: time, stage: 'scraping'));
    await db.saveRun(
      RunRecord(id: 'b', startedAt: time, finishedAt: time, stage: 'completed'),
    );
    await db.recoverInterruptedRuns();
    final runs = {for (final r in await db.watchRuns().first) r.id: r};
    expect(runs['a']!.stage, 'interrupted');
    expect(runs['a']!.finishedAt, isNotNull);
    expect(runs['b']!.stage, 'completed');
  });
  test('onboarding completion is durable app state', () async {
    expect(await db.hasCompletedOnboarding(), isFalse);
    await db.completeOnboarding();
    expect(await db.hasCompletedOnboarding(), isTrue);
    await db.completeOnboarding();
    expect(await db.hasCompletedOnboarding(), isTrue);
  });
  test(
    'a committed empty scan clears current results, not history or favorites',
    () async {
      await db.persistDeals(
        [sampleDeal],
        'first',
        listings: [sampleListing],
        targets: [sampleTarget],
      );
      await db.setDealFlags(sampleDeal.id, favorite: true);
      expect(await db.watchCurrentDeals().first, hasLength(1));
      await db.persistDeals([], 'second');
      expect(await db.watchCurrentDeals().first, isEmpty);
      expect((await db.watchDeals().first).single.isFavorite, isTrue);
      expect((await db.loadLatestSnapshot())!.runId, 'second');
    },
  );
  test('bulk import is atomic and rejects a stale local preview', () async {
    final initial = await db.loadTargets();
    await db.saveTarget(sampleTarget);
    await expectLater(db.importTargets([], initial), throwsStateError);
    final before = await db.loadTargets();
    final conflicting = Target.fromJson({
      ...sampleTarget.toJson(),
      'id': 'duplicate',
    });
    await expectLater(
      db.importTargets([sampleTarget, conflicting], before),
      throwsStateError,
    );
    expect(
      (await db.loadTargets()).single.revision,
      0,
      reason: 'First update must roll back with failed second update',
    );
  });
}
