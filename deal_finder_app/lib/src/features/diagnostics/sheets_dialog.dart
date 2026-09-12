import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../application/pipeline/cancellation.dart';
import '../../application/sync/sync_coordinator.dart';
import '../../data/sheets/sheet_models.dart';
import '../../data/sheets/sheets_gateway.dart';
import '../../domain/models/target.dart';
import '../../domain/models/sync_job.dart';
import '../../domain/matching/text_cleaner.dart';
import '../shell/shared_widgets.dart';

class SheetsDialog extends ConsumerStatefulWidget {
  const SheetsDialog({super.key});
  @override
  ConsumerState<SheetsDialog> createState() => _SheetsDialogState();
}

class _SheetsDialogState extends ConsumerState<SheetsDialog> {
  bool busy = false, automatic = false;
  String message =
      'Connection tests only read spreadsheet metadata. No sharing or permission changes are made.';
  Cancellation? cancellation;
  SheetsGateway? active;
  @override
  void initState() {
    super.initState();
    loadPreference();
  }

  Future<void> loadPreference() async {
    try {
      final value = await ref.read(credentialProvider).read('postRunSync');
      if (mounted) setState(() => automatic = value == 'true');
    } catch (_) {
      if (mounted) {
        setState(
          () => message = 'Secure settings are unavailable. Retry after unlocking the device.',
        );
      }
    }
  }

  @override
  void dispose() {
    cancellation?.cancel();
    active?.close();
    super.dispose();
  }

  Future<void> operation(
    Future<String> Function(SheetsGateway, Cancellation, SheetsOperation)
    action, {
    String? destination,
  }) async {
    if (busy) return;
    setState(() {
      busy = true;
      message = 'Connecting to your spreadsheet…';
    });
    final c = Cancellation();
    cancellation = c;
    final coordinator = ref.read(syncCoordinatorProvider);
    SheetsOperation? lease;
    try {
      lease = coordinator.acquire();
      final gateway = await ref.read(sheetsGatewayFactoryProvider)(
        c,
        destination: destination,
      );
      active = gateway;
      final result = await action(gateway, c, lease);
      if (mounted) setState(() => message = result);
    } on RunCancelled {
      if (mounted) {
        setState(
          () => message = 'Stopped. A pending write may have completed; retry will re-read the sheet.',
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => message = e is StateError || e is FormatException
              ? redactSecrets(
                  redactPii(
                    e is StateError
                        ? e.message.toString()
                        : (e as FormatException).message,
                  ),
                )
              : 'Sheets could not finish this operation. Your local data is still available.',
        );
      }
    } finally {
      active?.close();
      active = null;
      cancellation = null;
      if (lease != null) coordinator.release(lease);
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> import() => operation((gateway, c, _) async {
    final remote = await gateway.read('Price List', c),
        local = await ref.read(targetRepositoryProvider).loadTargets();
    final incoming = readTargets(remote, local, () => const Uuid().v4());
    if (!mounted) return 'Import cancelled.';
    final selected = await reviewTargets(
      context,
      incoming,
      local,
      action: 'Import selected',
      currentLabel: 'On device',
      incomingLabel: 'From Sheets',
    );
    if (selected == null || selected.isEmpty) return 'No targets imported.';
    c.check();
    if ((await gateway.read('Price List', c)).fingerprint !=
        remote.fingerprint) {
      throw StateError(
        'Price List changed while you reviewed it. Preview again.',
      );
    }
    await ref.read(targetRepositoryProvider).importTargets(selected, local);
    return '${selected.length} targets imported. Other local targets were kept.';
  });
  Future<void> export() => operation((gateway, c, _) async {
    final remote = await gateway.read('Price List', c),
        local = await ref.read(targetRepositoryProvider).loadTargets();
    final old = readTargets(remote, [], () => const Uuid().v4());
    if (!mounted) return 'Export cancelled.';
    final selected = await reviewTargets(
      context,
      local,
      old,
      action: 'Export selected',
      currentLabel: 'In Sheets',
      incomingLabel: 'From device',
    );
    if (selected == null || selected.isEmpty) return 'No targets exported.';
    c.check();
    await gateway.apply(remote, targetExport(remote, selected), c);
    return '${selected.length} targets exported. Remote-only targets and custom columns were preserved.';
  });
  Future<void> syncLatest() async {
    final snapshot = await ref
        .read(dealRepositoryProvider)
        .loadLatestSnapshot();
    if (snapshot == null) {
      if (mounted) {
        setState(
          () =>
              message = 'Complete a normal scan before exporting its results.',
        );
      }
      return;
    }
    final destination = spreadsheetId(
      await ref.read(credentialProvider).read('spreadsheetId') ?? '',
    );
    if (!mounted ||
        !await confirmAction(
          context,
          title: 'Sync this scan to Sheets?',
          message:
              'Upload ${snapshot.deals.length} deals and ${snapshot.listings.length} listings to $destination? '
              'Managed columns in Current Deals and All Listings will be replaced. History is deduplicated. Descriptions and seller metadata are included.',
          confirmLabel: 'Sync results',
        )) {
      return;
    }
    await operation((gateway, c, lease) async {
      final coordinator = ref.read(syncCoordinatorProvider),
          job = await ref
              .read(syncCoordinatorProvider)
              .enqueue(snapshot, destination);
      await coordinator.execute(job, gateway, c, operation: lease);
      return 'Run results synced. Local favorites and dismissed flags were not changed.';
    }, destination: destination);
  }

  Future<void> retry(SyncJob job) => operation((gateway, c, lease) async {
    await ref
        .read(syncCoordinatorProvider)
        .execute(job, gateway, c, operation: lease);
    return 'Saved run ${job.snapshot.runId} synced to its original destination.';
  }, destination: job.destination);
  Future<void> setAutomatic(bool value) async {
    if (value &&
        !await confirmAction(
          context,
          title: 'Sync after each normal scan?',
          message: 'Each scan will send listing descriptions and results to your saved spreadsheet and replace its managed Current Deals and All Listings columns. Audit Mode never syncs.',
          confirmLabel: 'Enable sync',
        )) {
      return;
    }
    try {
      await ref.read(credentialProvider).write('postRunSync', value.toString());
      if (mounted) setState(() => automatic = value);
    } catch (_) {
      if (mounted) {
        setState(() => message = 'The sync preference could not be saved.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Google Sheets',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Semantics(liveRegion: true, child: Text(message)),
            if (busy) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(
                semanticsLabel: 'Sheets operation in progress',
              ),
            ],
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => operation((gateway, c, _) async {
                          final tabs = await gateway.tabs(c);
                          return 'Readable spreadsheet. Found ${tabs.length} tabs. Write permission has not been tested. Missing managed tabs: ${managedTabs.keys.where((name) => !tabs.containsKey(name)).join(', ')}';
                        }),
                  child: const Text('Test read access'),
                ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          if (!await confirmAction(
                            context,
                            title: 'Initialize required tabs?',
                            message: 'Create missing Price List, Current Deals, All Listings, and History tabs; add headers and formatting only to empty tabs. Existing content stays unchanged.',
                            confirmLabel: 'Initialize tabs',
                          )) {
                            return;
                          }
                          await operation((gateway, c, _) async {
                            await gateway.initialize(c);
                            return 'Required tabs are ready. Existing populated tabs were not altered.';
                          });
                        },
                  child: const Text('Initialize empty tabs'),
                ),
                FilledButton(
                  onPressed: busy ? null : import,
                  child: const Text('Import targets'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : export,
                  child: const Text('Export targets'),
                ),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          try {
                            await syncLatest();
                          } catch (_) {
                            if (mounted) {
                              setState(
                                () => message = 'Save a valid spreadsheet destination in Settings first.',
                              );
                            }
                          }
                        },
                  child: const Text('Sync latest results'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Sync results after normal scans'),
              value: automatic,
              onChanged: busy ? null : setAutomatic,
            ),
            const SizedBox(height: 16),
            Text(
              'Saved sync jobs',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            ref
                .watch(syncJobsProvider)
                .when(
                  loading: () => const Text('Loading…'),
                  error: (_, _) => const Text('Sync history unavailable.'),
                  data: (jobs) => jobs.isEmpty
                      ? const Text('No results have been queued for Sheets.')
                      : Column(
                          children: jobs
                              .take(20)
                              .map(
                                (job) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    '${localDate(job.snapshot.createdAt)} • ${job.state}',
                                  ),
                                  subtitle: Text(
                                    '${job.completedTabs.length}/3 tabs • ${job.attempts} attempts\nDestination: ${job.destination}',
                                  ),
                                  trailing: job.state == 'completed'
                                      ? const Icon(Icons.check_circle_outline)
                                      : IconButton(
                                          tooltip: 'Retry this saved sync',
                                          onPressed: busy
                                              ? null
                                              : () => retry(job),
                                          icon: const Icon(Icons.refresh),
                                        ),
                                ),
                              )
                              .toList(),
                        ),
                ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              children: [
                if (busy)
                  TextButton(
                    onPressed: () => cancellation?.cancel(),
                    child: const Text('Cancel operation'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Future<List<Target>?> reviewTargets(
  BuildContext context,
  List<Target> incoming,
  List<Target> current, {
  required String action,
  required String currentLabel,
  required String incomingLabel,
}) {
  final selected = incoming.map((t) => t.id).toSet();
  return showDialog<List<Target>>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 700),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Review target changes',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Expand each target to compare fields. Unselected and unrelated targets stay unchanged. Renames create a new target in Sheets.',
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: incoming.map((target) {
                      final old = current
                          .where(
                            (t) =>
                                t.name.toLowerCase() ==
                                target.name.toLowerCase(),
                          )
                          .firstOrNull;
                      final next = targetCells(target),
                          before = old == null
                              ? <String, SheetCell>{}
                              : targetCells(old);
                      return ExpansionTile(
                        leading: Checkbox(
                          value: selected.contains(target.id),
                          onChanged: (value) => setState(() {
                            if (value == true) {
                              selected.add(target.id);
                            } else {
                              selected.remove(target.id);
                            }
                          }),
                        ),
                        title: Text(target.name),
                        subtitle: Text(
                          old == null
                              ? 'New target • ${target.dealPrice.formatted}'
                              : '${old.dealPrice.formatted} → ${target.dealPrice.formatted}',
                        ),
                        children: next.entries
                            .where(
                              (entry) =>
                                  entry.value.value != before[entry.key]?.value,
                            )
                            .map(
                              (entry) => ListTile(
                                title: Text(entry.key),
                                subtitle: Text(
                                  '$currentLabel: ${before[entry.key]?.value ?? 'Not present'}\n$incomingLabel: ${entry.value.value ?? 'Empty'}',
                                ),
                              ),
                            )
                            .toList(),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: selected.isEmpty
                          ? null
                          : () => Navigator.pop(
                              context,
                              incoming
                                  .where((t) => selected.contains(t.id))
                                  .toList(),
                            ),
                      child: Text(action),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
