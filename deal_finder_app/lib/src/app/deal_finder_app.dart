import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design_system/terra_theme.dart';
import '../features/shell/app_shell.dart';
import 'providers.dart';

final class StartupState {
  const StartupState({required this.showOnboarding});
  final bool showOnboarding;
}

final startupProvider = FutureProvider<StartupState>((ref) async {
  await ref.read(runRepositoryProvider).recoverInterruptedRuns();
  return StartupState(
    showOnboarding: !await ref
        .read(appPreferencesProvider)
        .hasCompletedOnboarding(),
  );
});

class DealFinderApp extends ConsumerWidget {
  const DealFinderApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    title: 'Deal Finder',
    debugShowCheckedModeBanner: false,
    theme: Terra.theme,
    home: ref
        .watch(startupProvider)
        .when(
          data: (state) => AppShell(showOnboarding: state.showOnboarding),
          loading: () => const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Opening your saved deals',
              ),
            ),
          ),
          error: (_, _) => Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.storage_outlined, size: 40),
                    const SizedBox(height: 16),
                    const Text(
                      'Your local library could not be opened. Your data has not been reset.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => ref.invalidate(startupProvider),
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
  );
}
