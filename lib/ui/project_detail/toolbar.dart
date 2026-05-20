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

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _flavorDropdown(ref, flavors),
          _deviceDropdown(ref, devices),
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

  Widget _flavorDropdown(WidgetRef ref, AsyncValue<List<String>> flavors) {
    final items = flavors.maybeWhen(
      data: (l) => l,
      orElse: () => const <String>[],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Flavor: '),
        DropdownButton<String?>(
          value: project.lastFlavor,
          hint: const Text('(default)'),
          items: [
            const DropdownMenuItem(value: null, child: Text('(default)')),
            for (final f in items) DropdownMenuItem(value: f, child: Text(f)),
          ],
          onChanged: (v) {
            project.lastFlavor = v;
            ref.read(projectsProvider.notifier).update(project);
          },
        ),
      ],
    );
  }

  Widget _deviceDropdown(WidgetRef ref, AsyncValue devices) {
    final list = devices.maybeWhen(
      data: (d) => d as List,
      orElse: () => const [],
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Device: '),
        DropdownButton<String?>(
          value: project.lastDeviceId,
          hint: const Text('(pick)'),
          items: [
            for (final d in list)
              DropdownMenuItem(
                  value: d.id as String, child: Text(d.name as String)),
          ],
          onChanged: (v) {
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
