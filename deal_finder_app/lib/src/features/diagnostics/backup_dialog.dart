import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../domain/models/backup_archive.dart';
import '../../domain/repositories/backup_repository.dart';

class BackupDialog extends ConsumerStatefulWidget {
  const BackupDialog({super.key});
  @override
  ConsumerState<BackupDialog> createState() => _BackupDialogState();
}

class _BackupDialogState extends ConsumerState<BackupDialog> {
  bool busy = false;
  bool reviewing = false;
  String? message;

  Future<void> operation(Future<void> Function(BackupRepository) action) async {
    setState(() {
      busy = true;
      message = null;
    });
    try {
      await ref.read(backupCoordinatorProvider).exclusive(action);
    } on FormatException catch (error) {
      if (mounted) setState(() => message = error.message);
    } on StateError catch (error) {
      if (mounted) setState(() => message = error.message);
    } catch (_) {
      // Native/file errors may contain private paths or file contents.
      if (mounted) {
        setState(
          () => message = 'Backup operation failed. Local data was not replaced. Check file access and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> export() => operation((repository) async {
    final files = ref.read(backupFilesProvider);
    final archive = await repository.exportBackup();
    final saved = await files.saveBackup(archive);
    if (mounted) {
      setState(
        () => message = saved
            ? 'Backup saved. Keep it in a private, safe location.'
            : 'Export cancelled.',
      );
    }
  });

  Future<void> restore() => operation((repository) async {
    final files = ref.read(backupFilesProvider);
    final expected = await repository.backupFingerprint();
    final contents = await files.pickBackup();
    if (contents == null || !mounted) {
      if (mounted) setState(() => message = 'Restore cancelled.');
      return;
    }
    final archive = BackupArchive.decode(contents);
    final current = await repository.exportBackup();
    if (!mounted) return;
    setState(() => reviewing = true);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _RestoreConfirmation(incoming: archive, current: current),
    );
    if (mounted) setState(() => reviewing = false);
    if (confirmed != true || !mounted) {
      if (mounted) {
        setState(() => message = 'Restore cancelled. No data was replaced.');
      }
      return;
    }
    await repository.restoreBackup(archive, expectedFingerprint: expected);
    if (mounted) {
      setState(
        () => message = 'Library restored. Credentials and settings were unchanged. No Sheets writes were started.',
      );
    }
  });

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: AlertDialog(
      title: const Text('Backup & restore'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Export targets, deals, favorites, dismissed items, run history, scan snapshots and pending Sheets jobs.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Credentials and connection settings are not included. This JSON file is not encrypted: it contains your notes and marketplace details. Save it privately.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Restore replaces the local library, not Google Sheets. Export your current library first if you may need to undo the replacement. Only import backups you trust (up to 32 MiB).',
              ),
              if (busy && !reviewing)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: LinearProgressIndicator(
                    semanticsLabel: 'Backup operation in progress',
                  ),
                ),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(liveRegion: true, child: Text(message!)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        OutlinedButton(
          onPressed: busy ? null : restore,
          child: const Text('Choose backup to restore'),
        ),
        FilledButton.icon(
          onPressed: busy ? null : export,
          icon: const Icon(Icons.save_alt),
          label: const Text('Export backup'),
        ),
      ],
    ),
  );
}

class _RestoreConfirmation extends StatefulWidget {
  const _RestoreConfirmation({required this.incoming, required this.current});
  final BackupArchive incoming, current;
  @override
  State<_RestoreConfirmation> createState() => _RestoreConfirmationState();
}

class _RestoreConfirmationState extends State<_RestoreConfirmation> {
  bool acknowledged = false;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Replace local library?'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Backup created ${widget.incoming.createdAt.toLocal().toString().split('.').first}',
            ),
            const SizedBox(height: 16),
            for (final entry in const {
              'targets': 'Targets',
              'deals': 'Deals',
              'runs': 'Runs',
              'snapshots': 'Scan snapshots',
              'syncJobs': 'Sheets jobs',
            }.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${entry.value}: ${widget.current.counts[entry.key]} on this device; ${widget.incoming.counts[entry.key]} in backup',
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Existing local records and flags will be replaced. Credentials stay on this device. Restored pending jobs require an explicit retry.',
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: acknowledged,
              onChanged: (value) =>
                  setState(() => acknowledged = value ?? false),
              title: const Text(
                'I have saved anything I need and want to replace the local library.',
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Cancel restore'),
      ),
      FilledButton(
        onPressed: acknowledged ? () => Navigator.pop(context, true) : null,
        child: const Text('Replace local library'),
      ),
    ],
  );
}
