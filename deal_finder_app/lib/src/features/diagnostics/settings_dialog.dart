import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../shell/shared_widgets.dart';
import 'sheets_dialog.dart';
import '../../data/sheets/sheet_models.dart';

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key, this.firstRun = false});
  final bool firstRun;
  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  final keyInput = TextEditingController(),
      model = TextEditingController(),
      sheet = TextEditingController(),
      serviceAccount = TextEditingController();
  bool loading = true,
      saving = false,
      hasKey = false,
      hasAccount = false,
      reveal = false;
  String? message;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final store = ref.read(credentialProvider);
      final values = await Future.wait(
        [
          'geminiKey',
          'geminiModel',
          'spreadsheetId',
          'serviceAccount',
        ].map(store.read),
      );
      if (!mounted) return;
      setState(() {
        hasKey = values[0]?.isNotEmpty ?? false;
        model.text = values[1] ?? 'gemini-3.1-flash-lite';
        sheet.text = values[2] ?? '';
        hasAccount = values[3]?.isNotEmpty ?? false;
        loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          message =
              'Secure storage could not be opened. Try again before saving.';
        });
      }
    }
  }

  @override
  void dispose() {
    for (final c in [keyInput, model, sheet, serviceAccount]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (sheet.text.trim().isNotEmpty) {
      try {
        spreadsheetId(sheet.text);
      } on FormatException catch (e) {
        setState(() => message = e.message);
        return;
      }
    }
    if (model.text.trim().isEmpty ||
        !RegExp(r'^[a-zA-Z0-9._-]+$').hasMatch(model.text.trim())) {
      setState(() => message = 'Enter a valid Gemini model identifier.');
      return;
    }
    if (serviceAccount.text.trim().isNotEmpty) {
      try {
        final value = jsonDecode(serviceAccount.text);
        if (value is! Map ||
            value['type'] != 'service_account' ||
            value['client_email'] is! String ||
            value['private_key'] is! String) {
          throw const FormatException();
        }
      } catch (_) {
        setState(
          () => message = 'Service-account JSON must include type, client_email, and private_key.',
        );
        return;
      }
    }
    setState(() {
      saving = true;
      message = null;
    });
    try {
      final store = ref.read(credentialProvider);
      if (keyInput.text.trim().isNotEmpty) {
        await store.write('geminiKey', keyInput.text.trim());
      }
      if (serviceAccount.text.trim().isNotEmpty) {
        await store.write('serviceAccount', serviceAccount.text.trim());
      }
      await store.write('geminiModel', model.text.trim());
      await store.write('spreadsheetId', sheet.text.trim());
      keyInput.clear();
      serviceAccount.clear();
      if (widget.firstRun) {
        await ref.read(appPreferencesProvider).completeOnboarding();
        if (mounted) Navigator.pop(context);
        return;
      }
      await load();
      if (mounted) {
        setState(
          () => message = 'Saved securely on this device. Existing scans keep their initial configuration.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message = 'Settings could not be saved. Verify secure storage is available.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> remove() async {
    if (!await confirmAction(
      context,
      title: 'Remove saved credentials?',
      message:
          'Targets and deals stay on this device. Scans will need a new key.',
      confirmLabel: 'Remove credentials',
    )) {
      return;
    }
    setState(() => saving = true);
    try {
      await ref.read(credentialProvider).removeAll();
      keyInput.clear();
      serviceAccount.clear();
      await load();
      if (mounted) {
        setState(
          () => message = 'Saved credentials and connection settings were removed. Your local library was not changed.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => message = 'Could not remove credentials. Please retry.');
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> finishLater() async {
    setState(() {
      saving = true;
      message = null;
    });
    try {
      await ref.read(appPreferencesProvider).completeOnboarding();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(
          () => message = 'Setup status could not be saved. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.all(16),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.firstRun
                  ? 'Welcome to Deal Finder'
                  : 'Settings & connections',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              widget.firstRun
                  ? 'Add targets for the items you want, then scan for matching deals. A Gemini API key is required to publish matches. Google Sheets is optional and never automatic.'
                  : 'Personal build • keys belong to you and are stored using platform-protected storage. API usage may incur charges.',
            ),
            const SizedBox(height: 24),
            if (loading)
              const LinearProgressIndicator(
                semanticsLabel: 'Reading secure settings',
              ),
            TextField(
              controller: keyInput,
              obscureText: !reveal,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: hasKey
                    ? 'Gemini key (saved; enter to replace)'
                    : 'Gemini API key',
                suffixIcon: IconButton(
                  tooltip: reveal ? 'Hide key' : 'Show key',
                  onPressed: () => setState(() => reveal = !reveal),
                  icon: Icon(reveal ? Icons.visibility_off : Icons.visibility),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: model,
              decoration: const InputDecoration(labelText: 'Gemini model'),
            ),
            const SizedBox(height: 24),
            Text(
              'Google Sheets (optional)',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Use your own spreadsheet. Imports, exports, and sharing are never automatic.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: sheet,
              decoration: const InputDecoration(
                labelText: 'Spreadsheet ID or Google Sheets URL',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: serviceAccount,
              maxLines: 4,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: hasAccount
                    ? 'Service account (saved; paste JSON to replace)'
                    : 'Service-account JSON',
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Do not distribute a build containing your keys. Removing credentials does not revoke them at Google.',
            ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Semantics(liveRegion: true, child: Text(message!)),
              ),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 12,
              runSpacing: 12,
              children: [
                if (!widget.firstRun)
                  OutlinedButton(
                    onPressed: saving || loading
                        ? null
                        : () => showDialog<void>(
                            context: context,
                            builder: (_) => const SheetsDialog(),
                          ),
                    child: const Text('Manage Sheets (saved settings)'),
                  ),
                if (!widget.firstRun)
                  TextButton(
                    onPressed: saving || loading ? null : remove,
                    child: const Text('Remove credentials'),
                  ),
                TextButton(
                  onPressed: saving || loading
                      ? null
                      : widget.firstRun
                      ? finishLater
                      : () => Navigator.pop(context),
                  child: Text(widget.firstRun ? 'Set up later' : 'Close'),
                ),
                FilledButton(
                  onPressed: saving || loading ? null : save,
                  child: Text(
                    saving
                        ? 'Saving…'
                        : widget.firstRun
                        ? 'Save & continue'
                        : 'Save settings',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
