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
    // Watch reactive StateProviders — toolbar rebuilds immediately on change.
    final selectedDevice = ref.watch(selectedDeviceIdProvider(project.id));
    final selectedFlavor = ref.watch(selectedFlavorProvider(project.id));

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _flavorDropdown(ref, flavors, selectedFlavor),
          _deviceDropdown(ref, devices, selectedDevice),
          _cleanToggle(ref),
          IconButton(
            tooltip: 'Refresh devices/flavors',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(devicesProvider);
              ref.invalidate(flavorsForProjectProvider(project.path));
            },
          ),
        ],
      ),
    );
  }

  Widget _flavorDropdown(
      WidgetRef ref, AsyncValue<List<String>> flavors, String? selectedFlavor) {
    final items = flavors.maybeWhen(
      data: (l) => l,
      orElse: () => const <String>[],
    );
    // Guard: value must exist in items; fall back to null (shows hint).
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
            // Update reactive state → toolbar rebuilds immediately.
            ref.read(selectedFlavorProvider(project.id).notifier).state = v;
            // Persist to Hive.
            project.lastFlavor = v;
            ref.read(projectsProvider.notifier).update(project);
          },
        ),
      ],
    );
  }

  Widget _deviceDropdown(
      WidgetRef ref, AsyncValue devices, String? selectedDevice) {
    final isLoading = devices is AsyncLoading;
    final list = devices.maybeWhen(
      data: (d) => d as List,
      orElse: () => const [],
    );
    // Guard: value must exist in items; fall back to null (shows hint).
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
              // Update reactive state → toolbar rebuilds immediately.
              ref
                  .read(selectedDeviceIdProvider(project.id).notifier)
                  .state = v;
              // Persist to Hive.
              project.lastDeviceId = v;
              ref.read(projectsProvider.notifier).update(project);
            },
          ),
      ],
    );
  }

  Widget _cleanToggle(WidgetRef ref) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: project.cleanBeforeBuild,
          onChanged: (v) {
            project.cleanBeforeBuild = v ?? false;
            ref.read(projectsProvider.notifier).update(project);
          },
        ),
        const Text('Clean before build'),
      ],
    );
  }
}
