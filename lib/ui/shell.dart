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
    final sdk = ref.watch(sdkStatusProvider);
    return Scaffold(
      body: Column(
        children: [
          sdk.when(
            data: (s) => s.available
                ? const SizedBox.shrink()
                : Container(
                    color: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.error, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Flutter SDK not found in PATH — install Flutter '
                            'and ensure `flutter` is on your shell PATH.'
                            '${s.error == null ? '' : '\n${s.error}'}',
                          ),
                        ),
                      ],
                    ),
                  ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          Expanded(
            child: Row(
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
