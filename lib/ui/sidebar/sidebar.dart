import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';
import '../dialogs/add_project_dialog.dart';

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider);
    final selectedId = ref.watch(selectedProjectIdProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text('Projects',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: projects.length,
            itemBuilder: (context, i) {
              final p = projects[i];
              final isSel = p.id == selectedId;
              return ListTile(
                title: Text(p.name),
                subtitle: Text(
                  p.path,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11),
                ),
                selected: isSel,
                onTap: () =>
                    ref.read(selectedProjectIdProvider.notifier).state = p.id,
                trailing: PopupMenuButton<String>(
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'remove', child: Text('Remove')),
                    PopupMenuItem(
                        value: 'open_finder', child: Text('Open in Finder')),
                  ],
                  onSelected: (v) async {
                    if (v == 'remove') {
                      await ref.read(projectsProvider.notifier).remove(p.id);
                      if (selectedId == p.id) {
                        ref
                            .read(selectedProjectIdProvider.notifier)
                            .state = null;
                      }
                    } else if (v == 'open_finder') {
                      ref.read(finderRevealProvider).openFolder(p.path);
                    }
                  },
                ),
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => const AddProjectDialog(),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Add project'),
            ),
          ),
        ),
      ],
    );
  }
}
