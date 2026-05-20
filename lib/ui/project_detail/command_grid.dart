import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/command_intent.dart';
import '../../domain/models/custom_command.dart';
import '../../domain/models/project.dart';
import '../../state/providers.dart';
import '../dialogs/custom_command_dialog.dart';

class CommandGrid extends ConsumerWidget {
  const CommandGrid({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(projectRunnerProvider(project.id));
    // Read all reactive selections so commands always use current values.
    final selectedDevice = ref.watch(selectedDeviceIdProvider(project.id));
    final selectedFlavor = ref.watch(selectedFlavorProvider(project.id));
    final selectedEntry = ref.watch(selectedEntryPointProvider(project.id));
    final cleanBefore = ref.watch(selectedCleanProvider(project.id));
    return StreamBuilder(
      stream: controller.stream,
      builder: (_, __) {
        final running = controller.isRunning;
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _btn('▶ Run', !running, () => _run(ref, RunIntent(
                    deviceId: selectedDevice ?? '',
                    flavor: selectedFlavor,
                    entryPoint: selectedEntry,
                  ), cleanBefore: cleanBefore)),
                  _btn('🧹 Clean + Pub', !running,
                      () => _run(ref, const CleanIntent(), cleanBefore: false)),
                  _btn('Build APK', !running,
                      () => _run(ref, BuildApkIntent(
                        flavor: selectedFlavor,
                        entryPoint: selectedEntry,
                      ), cleanBefore: cleanBefore)),
                  _btn('⚙️ build_runner', !running,
                      () => _run(ref, const BuildRunnerIntent(), cleanBefore: false)),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Custom',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in project.customCommands)
                    _btn(c.label, !running,
                        () => _run(ref, CustomIntent(label: c.label, command: c.command), cleanBefore: false)),
                  OutlinedButton.icon(
                    onPressed: () => _editCustom(context, ref, null),
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _btn(String label, bool enabled, VoidCallback onTap) {
    return FilledButton(
      onPressed: enabled ? onTap : null,
      child: Text(label),
    );
  }

  void _run(WidgetRef ref, CommandIntent intent, {required bool cleanBefore}) {
    final composed = ref.read(commandComposerProvider).compose(
      intent,
      cleanBeforeBuild: cleanBefore,
    );
    final controller = ref.read(projectRunnerProvider(project.id));
    // Clear previous output file so button disappears until next success
    controller.setLastOutputFile(null);
    controller.start(
      label: composed.label,
      command: composed.shell,
      workingDir: project.path,
      onComplete: (code, duration) async {
        if (code == 0 && intent is BuildApkIntent) {
          final apk =
              await ref.read(outputFinderProvider).findApk(project.path);
          if (apk == null) {
            // Couldn't find APK — just open the build folder
            await ref
                .read(finderRevealProvider)
                .openFolder('${project.path}/build');
            return;
          }
          try {
            final result = await ref.read(outputRenamerProvider).rename(
                  sourceApk: apk,
                  projectPath: project.path,
                );
            controller.setLastOutputFile(result.target);
            await ref
                .read(finderRevealProvider)
                .reveal(result.target.path);
          } catch (_) {
            await ref
                .read(finderRevealProvider)
                .openFolder('${project.path}/build');
          }
        }
      },
    );
  }

  Future<void> _editCustom(
      BuildContext context, WidgetRef ref, CustomCommand? existing) async {
    final result = await showDialog<CustomCommand>(
      context: context,
      builder: (_) => CustomCommandDialog(initial: existing),
    );
    if (result == null) return;
    final updated = [
      ...project.customCommands.where((x) => x.id != result.id),
      result,
    ];
    project.customCommands = updated;
    await ref.read(projectsProvider.notifier).update(project);
  }
}
