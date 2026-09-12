import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../application/pipeline/pipeline_controller.dart';
import '../../design_system/terra_theme.dart';
import '../../domain/models/target.dart';
import '../shell/shared_widgets.dart';
import 'target_editor.dart';

class TargetsPage extends ConsumerStatefulWidget {
  const TargetsPage({super.key});
  @override
  ConsumerState<TargetsPage> createState() => _TargetsPageState();
}

class _TargetsPageState extends ConsumerState<TargetsPage> {
  String query = '';
  void edit([Target? target]) => showDialog<void>(
    context: context,
    builder: (_) => TargetEditor(target: target),
  );
  Future<void> delete(Target target) async {
    if (!await confirmAction(
      context,
      title: 'Remove ${target.name}?',
      message: 'Past deals and saved favorites will be kept.',
      confirmLabel: 'Remove target',
    )) {
      return;
    }
    try {
      await ref.read(targetRepositoryProvider).deleteTarget(target.id);
    } catch (_) {
      if (mounted) {
        showMessage(context, 'Could not remove this target. Please retry.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final targets = ref.watch(targetsProvider);
    final state =
        ref.watch(pipelineStatusProvider).asData?.value ??
        const PipelineStatus();
    final controller = ref.read(pipelineProvider);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        key: const PageStorageKey('targets-scroll'),
        padding: EdgeInsets.all(
          constraints.maxWidth >= Terra.shellBreakpoint
              ? Terra.desktopMargin
              : Terra.mobileMargin,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: Terra.contentWidth),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'My targets',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Good things are worth finding. Keep your wish list close.',
                ),
                const SizedBox(height: 24),
                Card(
                  color: Terra.sandstone,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Icon(
                              Icons.travel_explore,
                              color: Terra.primary,
                              size: 32,
                            ),
                            Text(
                              state.running
                                  ? 'Finding your next good deal'
                                  : 'Ready to discover something good?',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Semantics(liveRegion: true, child: Text(state.message)),
                        if (state.running) ...[
                          const SizedBox(height: 16),
                          LinearProgressIndicator(
                            value: state.progress,
                            // Keep work-unit wording in the label. The progress
                            // role requires the framework's numeric 0–100 value.
                            semanticsLabel: state.total > 0
                                ? '${state.message} (${state.completed} of ${state.total})'
                                : state.message,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${state.scraped} listings • ${state.deals} verified deals',
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: state.stage == RunStage.cancelling
                              ? null
                              : state.running
                              ? controller.cancel
                              : (targets.asData?.value.any((t) => t.enabled) ??
                                    false)
                              ? () => controller.start()
                              : null,
                          icon: Icon(
                            state.running
                                ? Icons.stop_circle_outlined
                                : Icons.search,
                          ),
                          label: Text(
                            state.running ? 'Cancel scan' : 'Scan now',
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Scans run while the app is open. Changes to targets apply to your next scan.',
                          style: TextStyle(color: Terra.muted),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    Text(
                      'Your wish list${targets.asData == null ? '' : ' (${targets.asData!.value.length})'}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    FilledButton.icon(
                      onPressed: () => edit(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add target'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search your targets',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) =>
                      setState(() => query = value.trim().toLowerCase()),
                ),
                const SizedBox(height: 24),
                targets.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Loading targets',
                    ),
                  ),
                  error: (_, _) => NoticeCard(
                    title: 'Your targets need a moment',
                    message: 'We couldn’t load the local list.',
                    action: OutlinedButton(
                      onPressed: () => ref.invalidate(targetsProvider),
                      child: const Text('Retry'),
                    ),
                  ),
                  data: (items) {
                    final visible = items
                        .where(
                          (t) => '${t.name} ${t.category}'
                              .toLowerCase()
                              .contains(query),
                        )
                        .toList();
                    if (items.isEmpty) {
                      return NoticeCard(
                        title: 'Make room for a good find',
                        message: 'Add a device or game and set your target price. We’ll take it from there.',
                        action: OutlinedButton(
                          onPressed: () => edit(),
                          child: const Text('Create your first target'),
                        ),
                      );
                    }
                    if (visible.isEmpty) {
                      return const NoticeCard(
                        title: 'No matching targets',
                        message: 'Try another name or category.',
                      );
                    }
                    return FlowCards(
                      children: visible
                          .map(
                            (t) => Card(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          t.type == TargetType.game
                                              ? Icons.sports_esports_outlined
                                              : Icons.devices_outlined,
                                          color: Terra.primary,
                                        ),
                                        const Spacer(),
                                        IconButton(
                                          tooltip: 'Edit ${t.name}',
                                          onPressed: () => edit(t),
                                          icon: const Icon(Icons.edit_outlined),
                                        ),
                                        PopupMenuButton<String>(
                                          tooltip: 'Actions for ${t.name}',
                                          onSelected: (value) {
                                            if (value == 'delete') delete(t);
                                            if (value == 'scan') {
                                              controller.start(
                                                targetIds: {t.id},
                                              );
                                            }
                                          },
                                          itemBuilder: (_) => [
                                            PopupMenuItem(
                                              value: 'scan',
                                              enabled:
                                                  t.enabled && !state.running,
                                              child: const Text(
                                                'Scan this target',
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Remove target'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      t.name,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      t.category,
                                      style: const TextStyle(
                                        color: Terra.muted,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    const Text(
                                      'Target price',
                                      style: TextStyle(color: Terra.muted),
                                    ),
                                    Text(
                                      t.dealPrice.formatted,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: Terra.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        TerraBadge(
                                          t.enabled ? 'Watching' : 'Paused',
                                          icon: t.enabled
                                              ? Icons.visibility_outlined
                                              : Icons.pause,
                                          color: t.enabled
                                              ? Terra.primary
                                              : Terra.muted,
                                        ),
                                        if (t.allowBundle)
                                          const TerraBadge(
                                            'Bundle check',
                                            color: Terra.amber,
                                          ),
                                        if (t.searchMode == SearchMode.itemName)
                                          const TerraBadge(
                                            'Name search',
                                            color: Terra.amber,
                                          ),
                                      ],
                                    ),
                                    if (t.notes.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      Text(
                                        t.notes,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
