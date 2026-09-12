import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../application/pipeline/pipeline_controller.dart';
import '../../design_system/terra_theme.dart';
import '../targets/targets_page.dart';
import '../deals/deals_page.dart';
import '../diagnostics/settings_dialog.dart';
import '../diagnostics/diagnostics_dialog.dart';
import '../diagnostics/backup_dialog.dart';
import 'shared_widgets.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, this.showOnboarding = false});
  final bool showOnboarding;
  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int selected = 0;
  @override
  void initState() {
    super.initState();
    if (widget.showOnboarding) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const SettingsDialog(firstRun: true),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state =
        ref.watch(pipelineStatusProvider).asData?.value ??
        const PipelineStatus();
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth >= Terra.shellBreakpoint &&
            MediaQuery.textScalerOf(context).scale(14) <= 21;
        return PopScope(
          canPop: !state.running,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              showMessage(
                context,
                'A scan is running. Cancel it before closing the app.',
              );
            }
          },
          child: Scaffold(
            appBar: AppBar(
              toolbarHeight: 80,
              titleSpacing: wide ? 32 : 16,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.eco_outlined, size: 28),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Deal Finder',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              actions: [
                if (wide) ...[
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(
                        value: 0,
                        label: Text('Targets'),
                        icon: Icon(Icons.devices_outlined),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text('Deals'),
                        icon: Icon(Icons.local_offer_outlined),
                      ),
                    ],
                    selected: {selected},
                    onSelectionChanged: (value) =>
                        setState(() => selected = value.first),
                  ),
                  const SizedBox(width: 24),
                ],
                PopupMenuButton<String>(
                  tooltip: 'Settings and diagnostics',
                  icon: const Icon(Icons.more_horiz),
                  onSelected: (value) {
                    if (value == 'settings') {
                      showDialog<void>(
                        context: context,
                        builder: (_) => const SettingsDialog(),
                      );
                    }
                    if (value == 'history') {
                      showDialog<void>(
                        context: context,
                        builder: (_) => const DiagnosticsDialog(),
                      );
                    }
                    if (value == 'backup') {
                      showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const BackupDialog(),
                      );
                    }
                    if (value == 'audit') {
                      setState(() => selected = 0);
                      ref.read(pipelineProvider).start(auditMode: true);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'settings',
                      child: Text('Settings & connections'),
                    ),
                    const PopupMenuItem(
                      value: 'history',
                      child: Text('Run history & diagnostics'),
                    ),
                    PopupMenuItem(
                      value: 'backup',
                      enabled: !state.running,
                      child: const Text('Backup & restore'),
                    ),
                    PopupMenuItem(
                      value: 'audit',
                      enabled: !state.running,
                      child: const Text('Run Audit Mode (no publishing)'),
                    ),
                  ],
                ),
                SizedBox(width: wide ? 24 : 8),
              ],
            ),
            body: IndexedStack(
              index: selected,
              children: const [TargetsPage(), DealsPage()],
            ),
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                    selectedIndex: selected,
                    onDestinationSelected: (value) =>
                        setState(() => selected = value),
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.devices_outlined),
                        selectedIcon: Icon(Icons.devices),
                        label: 'Targets',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.local_offer_outlined),
                        selectedIcon: Icon(Icons.local_offer),
                        label: 'Deals',
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }
}
