import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/project.dart';
import '../../state/providers.dart';

class ProjectToolbar extends ConsumerWidget {
  const ProjectToolbar({super.key, required this.project});

  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flavors = ref.watch(flavorsForProjectProvider(project.path));
    final devices = ref.watch(devicesProvider);
    final entryPoints = ref.watch(entryPointsForProjectProvider(project.path));

    // Reactive StateProviders — toolbar rebuilds immediately on any change.
    final selectedDevice = ref.watch(selectedDeviceIdProvider(project.id));
    final selectedFlavor = ref.watch(selectedFlavorProvider(project.id));
    final selectedEntry = ref.watch(selectedEntryPointProvider(project.id));
    final cleanBefore = ref.watch(selectedCleanProvider(project.id));

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _entryPointDropdown(ref, entryPoints, selectedEntry),
          _flavorDropdown(ref, flavors, selectedFlavor),
          _deviceDropdown(ref, devices, selectedDevice),
          _cleanToggle(ref, cleanBefore),
          IconButton(
            tooltip: 'Refresh devices / entry points / flavors',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(devicesProvider);
              ref.invalidate(flavorsForProjectProvider(project.path));
              ref.invalidate(entryPointsForProjectProvider(project.path));
            },
          ),
        ],
      ),
    );
  }

  // ─── Entry point ────────────────────────────────────────────────────────────

  Widget _entryPointDropdown(
      WidgetRef ref, AsyncValue<List<String>> entryPoints, String? selected) {
    final items = entryPoints.maybeWhen(
      data: (l) => l,
      orElse: () => const <String>['lib/main.dart'],
    );
    // Display label: strip "lib/" prefix for brevity.
    String label(String path) => path.startsWith('lib/') ? path.substring(4) : path;

    final currentValue =
        (selected != null && items.contains(selected)) ? selected : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Entry: '),
        DropdownButton<String?>(
          value: currentValue,
          hint: const Text('main.dart'),
          items: [
            const DropdownMenuItem(value: null, child: Text('main.dart')),
            for (final e in items)
              if (e != 'lib/main.dart')
                DropdownMenuItem(value: e, child: Text(label(e))),
          ],
          onChanged: (v) {
            ref.read(selectedEntryPointProvider(project.id).notifier).state = v;
            project.lastEntryPoint = v;
            ref.read(projectsProvider.notifier).update(project);
          },
        ),
      ],
    );
  }

  // ─── Flavor ─────────────────────────────────────────────────────────────────

  Widget _flavorDropdown(
      WidgetRef ref, AsyncValue<List<String>> flavors, String? selectedFlavor) {
    final items = flavors.maybeWhen(
      data: (l) => l,
      orElse: () => const <String>[],
    );
    final currentValue =
        (selectedFlavor != null && items.contains(selectedFlavor))
            ? selectedFlavor
            : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Flavor: '),
        DropdownButton<String?>(
          value: currentValue,
          hint: const Text('(default)'),
          items: [
            const DropdownMenuItem(value: null, child: Text('(default)')),
            for (final f in items) DropdownMenuItem(value: f, child: Text(f)),
          ],
          onChanged: (v) {
            ref.read(selectedFlavorProvider(project.id).notifier).state = v;
            project.lastFlavor = v;
            ref.read(projectsProvider.notifier).update(project);
          },
        ),
      ],
    );
  }

  // ─── Device ─────────────────────────────────────────────────────────────────

  Widget _deviceDropdown(
      WidgetRef ref, AsyncValue devices, String? selectedDevice) {
    final isLoading = devices is AsyncLoading;
    final list = devices.maybeWhen(
      data: (d) => d as List,
      orElse: () => const [],
    );
    final currentValue =
        (selectedDevice != null && list.any((d) => d.id == selectedDevice))
            ? selectedDevice
            : null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Device: '),
        if (isLoading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          DropdownButton<String?>(
            value: currentValue,
            hint: const Text('(pick)'),
            items: [
              const DropdownMenuItem(value: null, child: Text('(none)')),
              for (final d in list)
                DropdownMenuItem(
                    value: d.id as String, child: Text(d.name as String)),
            ],
            onChanged: (v) {
              ref.read(selectedDeviceIdProvider(project.id).notifier).state = v;
              project.lastDeviceId = v;
              ref.read(projectsProvider.notifier).update(project);
            },
          ),
      ],
    );
  }

  // ─── Clean toggle ────────────────────────────────────────────────────────────

  Widget _cleanToggle(WidgetRef ref, bool cleanBefore) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: cleanBefore,
          onChanged: (v) {
            final val = v ?? false;
            ref.read(selectedCleanProvider(project.id).notifier).state = val;
            project.cleanBeforeBuild = val;
            ref.read(projectsProvider.notifier).update(project);
          },
        ),
        const Text('Clean before build'),
      ],
    );
  }
}
