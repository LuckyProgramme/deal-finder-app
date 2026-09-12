import 'package:flutter/material.dart';

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/matching/text_cleaner.dart';
import '../../domain/matching/report_redaction.dart';
import '../shell/shared_widgets.dart';

class DiagnosticsDialog extends ConsumerWidget {
  const DiagnosticsDialog({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 760),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Run history',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'Recent scans and redacted audit reports. Interrupted runs can be started again from Targets.',
            ),
            const SizedBox(height: 24),
            ref
                .watch(runsProvider)
                .when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) =>
                      const Text('Run history could not be loaded.'),
                  data: (runs) => runs.isEmpty
                      ? const Text(
                          'No scans yet. Your first run will appear here.',
                        )
                      : Column(
                          children: runs
                              .map(
                                (run) => ExpansionTile(
                                  tilePadding: EdgeInsets.zero,
                                  title: Text(
                                    '${localDate(run.startedAt)} • ${run.stage}',
                                  ),
                                  subtitle: Text(
                                    '${run.scraped} listings • ${run.deals} verified deals',
                                  ),
                                  children: [
                                    if (run.error != null)
                                      Text(
                                        redactSecrets(redactPii(run.error!)),
                                      ),
                                    if (run.auditReport != null)
                                      OutlinedButton.icon(
                                        icon: const Icon(
                                          Icons.description_outlined,
                                        ),
                                        label: const Text(
                                          'View redacted audit report',
                                        ),
                                        onPressed: () => showDialog<void>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text(
                                              'Scan diagnostics',
                                            ),
                                            content: SizedBox(
                                              width: 680,
                                              child: SingleChildScrollView(
                                                child: SelectableText(
                                                  safeReportExport(
                                                    run.auditReport!,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(context),
                                                child: const Text('Close'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    if (run.auditReport != null)
                                      OutlinedButton.icon(
                                        icon: const Icon(Icons.copy),
                                        label: const Text(
                                          'Copy redacted audit report',
                                        ),
                                        onPressed: () async {
                                          await Clipboard.setData(
                                            ClipboardData(
                                              text: safeReportExport(
                                                run.auditReport!,
                                              ),
                                            ),
                                          );
                                          if (context.mounted) {
                                            showMessage(
                                              context,
                                              'Redacted report copied. Listing descriptions and credentials are excluded.',
                                            );
                                          }
                                        },
                                      ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              )
                              .toList(),
                        ),
                ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String safeReportExport(String stored) {
  try {
    if (stored.length > 1024 * 1024) throw const FormatException();
    return const JsonEncoder.withIndent('  ')
        .convert(redactedReport(jsonDecode(stored)));
  } catch (_) {
    return '{"error":"Report is unavailable or invalid. No raw content was exported."}';
  }
}
