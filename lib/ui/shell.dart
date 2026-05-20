import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/providers.dart';
import 'project_detail/project_detail.dart';
import 'sidebar/sidebar.dart';

class Shell extends ConsumerWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedProjectProvider);
    return Scaffold(
      body: Row(
        children: [
          const SizedBox(width: 260, child: Sidebar()),
          const VerticalDivider(width: 1),
          Expanded(
            child: selected == null
                ? const _EmptyState()
                : ProjectDetail(project: selected),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Select a project to begin'));
  }
}
