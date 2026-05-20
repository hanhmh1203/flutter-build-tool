import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/custom_command.dart';

class CustomCommandDialog extends StatefulWidget {
  const CustomCommandDialog({super.key, required this.initial});

  final CustomCommand? initial;

  @override
  State<CustomCommandDialog> createState() => _CustomCommandDialogState();
}

class _CustomCommandDialogState extends State<CustomCommandDialog> {
  late final TextEditingController _label =
      TextEditingController(text: widget.initial?.label ?? '');
  late final TextEditingController _command =
      TextEditingController(text: widget.initial?.command ?? '');

  bool get _valid =>
      _label.text.trim().isNotEmpty && _command.text.trim().isNotEmpty;

  @override
  void dispose() {
    _label.dispose();
    _command.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null
          ? 'New custom command'
          : 'Edit custom command'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('label-field'),
              controller: _label,
              decoration: const InputDecoration(labelText: 'Label'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('command-field'),
              controller: _command,
              decoration: const InputDecoration(labelText: 'Shell command'),
              maxLines: 3,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: _valid
              ? () {
                  Navigator.pop(
                    context,
                    CustomCommand(
                      id: widget.initial?.id ?? const Uuid().v4(),
                      label: _label.text.trim(),
                      command: _command.text.trim(),
                    ),
                  );
                }
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
