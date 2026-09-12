import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/providers.dart';
import '../../domain/models/target.dart';
import '../../domain/models/money.dart';

class TargetEditor extends ConsumerStatefulWidget {
  const TargetEditor({super.key, this.target});
  final Target? target;
  @override
  ConsumerState<TargetEditor> createState() => _TargetEditorState();
}

class _TargetEditorState extends ConsumerState<TargetEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController name,
      price,
      retail,
      notes,
      downsizing,
      freebies;
  late String category;
  late SearchMode mode;
  late TargetType type;
  late bool bundle, enabled;
  bool saving = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final t = widget.target;
    name = TextEditingController(text: t?.name);
    price = TextEditingController(text: t?.dealPrice.decimal);
    retail = TextEditingController(text: t?.retailPrice?.decimal);
    notes = TextEditingController(text: t?.notes);
    downsizing = TextEditingController(text: t?.downsizingKeywords.join(', '));
    freebies = TextEditingController(text: t?.freebieKeywords.join(', '));
    category = t?.category ?? categoryUrls.keys.first;
    mode = t?.searchMode ?? SearchMode.category;
    type = t?.type ?? TargetType.hardware;
    bundle = t?.allowBundle ?? false;
    enabled = t?.enabled ?? true;
  }

  @override
  void dispose() {
    for (final controller in [
      name,
      price,
      retail,
      notes,
      downsizing,
      freebies,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? validatePrice(String? value, {bool optional = false}) {
    if (optional && (value?.trim().isEmpty ?? true)) return null;
    try {
      if (Money.parse(value ?? '').centavos > 0) return null;
    } catch (_) {
      /* inline validation */
    }
    return 'Enter a positive peso amount with up to 2 decimal places.';
  }

  List<String> keywords(String text) =>
      text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await ref
          .read(targetRepositoryProvider)
          .saveTarget(
            Target(
              id: widget.target?.id ?? const Uuid().v4(),
              name: name.text,
              category: category,
              dealPrice: Money.parse(price.text),
              retailPrice: retail.text.trim().isEmpty
                  ? null
                  : Money.parse(retail.text),
              searchMode: mode,
              type: type,
              allowBundle: bundle,
              enabled: enabled,
              notes: notes.text.trim(),
              downsizingKeywords: keywords(downsizing.text),
              freebieKeywords: keywords(freebies.text),
              revision: widget.target?.revision ?? 0,
            ),
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e is StateError
              ? e.message.toString()
              : 'Could not save this target. Please try again.';
          saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.target == null ? 'Plant a new target' : 'Edit target',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tell us what you’re looking for and the price that feels right.',
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: name,
                  autofocus: true,
                  maxLength: 160,
                  decoration: const InputDecoration(
                    labelText: 'Device or game name',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'A name is required.'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: price,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Target price (PHP)',
                    prefixText: '₱ ',
                  ),
                  validator: validatePrice,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: category,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: {category, ...categoryUrls.keys}
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  validator: (value) =>
                      mode == SearchMode.category &&
                          !categoryUrls.containsKey(value)
                      ? 'Choose a supported category or search by target name.'
                      : null,
                  onChanged: saving
                      ? null
                      : (value) => setState(() => category = value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<SearchMode>(
                  initialValue: mode,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Search using'),
                  items: const [
                    DropdownMenuItem(
                      value: SearchMode.category,
                      child: Text('Recent category listings'),
                    ),
                    DropdownMenuItem(
                      value: SearchMode.itemName,
                      child: Text('This exact target name'),
                    ),
                  ],
                  onChanged: saving
                      ? null
                      : (value) => setState(() => mode = value!),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<TargetType>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Target type'),
                  items: const [
                    DropdownMenuItem(
                      value: TargetType.hardware,
                      child: Text('Hardware'),
                    ),
                    DropdownMenuItem(
                      value: TargetType.game,
                      child: Text('Game'),
                    ),
                  ],
                  onChanged: saving
                      ? null
                      : (value) => setState(() => type = value!),
                ),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include in scans'),
                  value: enabled,
                  onChanged: saving
                      ? null
                      : (value) => setState(() => enabled = value),
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Check bundle listings'),
                  subtitle: const Text(
                    'Only accept an item with clear individual pricing and separate-sale evidence.',
                  ),
                  value: bundle,
                  onChanged: saving
                      ? null
                      : (value) => setState(() => bundle = value),
                ),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('More details'),
                  children: [
                    TextFormField(
                      controller: retail,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Retail price (optional)',
                        prefixText: '₱ ',
                      ),
                      validator: (value) =>
                          validatePrice(value, optional: true),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: downsizing,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Condition keywords (comma separated)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: freebies,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Freebie keywords (comma separated)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: notes,
                      maxLines: 3,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'Personal notes',
                      ),
                    ),
                  ],
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(error!, semanticsLabel: 'Save error: $error'),
                  ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    TextButton(
                      onPressed: saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: saving ? null : save,
                      child: Text(saving ? 'Saving…' : 'Save target'),
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
