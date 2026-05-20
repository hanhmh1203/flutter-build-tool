import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/project_importer.dart';
import '../../state/providers.dart';

class AddProjectDialog extends ConsumerStatefulWidget {
  const AddProjectDialog({super.key});

  @override
  ConsumerState<AddProjectDialog> createState() => _AddProjectDialogState();
}

class _AddProjectDialogState extends ConsumerState<AddProjectDialog> {
  String? _error;
  bool _busy = false;

  Future<void> _pickAndImport() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) {
      setState(() => _busy = false);
      return;
    }
    try {
      final project = await ref.read(projectImporterProvider).import(path);
      // Duplicate check
      final exists =
          ref.read(projectsProvider).any((p) => p.path == project.path);
      if (exists) {
        setState(() {
          _busy = false;
          _error = 'Project already imported';
        });
        return;
      }
      await ref.read(projectsProvider.notifier).add(project);
      ref.read(selectedProjectIdProvider.notifier).state = project.id;
      if (mounted) Navigator.of(context).pop();
    } on ProjectImportException catch (e) {
      setState(() {
        _busy = false;
        _error = switch (e.code) {
          'NO_PUBSPEC' => 'Not a Flutter project (no pubspec.yaml)',
          'MALFORMED_PUBSPEC' => 'pubspec.yaml is malformed: ${e.message}',
          _ => 'Failed: ${e.message}',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Flutter Project'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pick the root folder of your Flutter project.'),
            const SizedBox(height: 12),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _pickAndImport,
          child: const Text('Pick folder…'),
        ),
      ],
    );
  }
}
