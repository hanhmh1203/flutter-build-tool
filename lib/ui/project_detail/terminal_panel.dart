import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

import '../../domain/models/project.dart';
import '../../state/project_runner_controller.dart';
import '../../state/providers.dart';

class TerminalPanel extends ConsumerStatefulWidget {
  const TerminalPanel({super.key, required this.project});

  final Project project;

  @override
  ConsumerState<TerminalPanel> createState() => _TerminalPanelState();
}

class _TerminalPanelState extends ConsumerState<TerminalPanel> {
  final Terminal _terminal = Terminal(maxLines: 10000);
  final StringBuffer _log = StringBuffer(); // plain text for Save log
  StreamSubscription<Uint8List>? _outSub;
  StreamSubscription<RunnerState>? _stateSub;

  @override
  void initState() {
    super.initState();
    final controller = ref.read(projectRunnerProvider(widget.project.id));
    _outSub = controller.output.listen((data) {
      final text = utf8.decode(data, allowMalformed: true);
      _terminal.write(text);
      _log.write(text);
    });
    _stateSub = controller.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _outSub?.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  Future<void> _saveLog() async {
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save log to…',
      fileName: '${widget.project.name}-log.txt',
    );
    if (path == null) return;
    await File(path).writeAsString(_stripAnsi(_log.toString()));
  }

  void _clearTerminal() {
    _terminal.write('\x1b[2J\x1b[H'); // ANSI ED2 + cursor home
    _log.clear();
    if (mounted) setState(() {});
  }

  String _stripAnsi(String input) =>
      input.replaceAll(RegExp(r'\x1B\[[0-9;?]*[ -/]*[@-~]'), '');

  String _statusText(ProjectRunnerController controller) {
    final code = controller.lastExitCode;
    final dur = controller.lastDuration;
    final label = controller.current?.label ?? '';
    if (code == null) return '';
    if (code == 0) return '✓ $label (${dur?.inSeconds ?? 0}s)';
    if (code < 0) return '✗ Cancelled';
    return '✗ exit $code';
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(projectRunnerProvider(widget.project.id));
    final running = controller.isRunning;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              if (running)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.redAccent),
                  onPressed: controller.stop,
                  icon: const Icon(Icons.stop),
                  label: const Text('Stop'),
                ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _clearTerminal,
                icon: const Icon(Icons.cleaning_services),
                label: const Text('Clear'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _saveLog,
                icon: const Icon(Icons.save),
                label: const Text('Save log'),
              ),
              const SizedBox(width: 8),
              if (!running && controller.lastOutputFile != null)
                OutlinedButton.icon(
                  onPressed: () => ref
                      .read(finderRevealProvider)
                      .reveal(controller.lastOutputFile!.path),
                  icon: const Icon(Icons.folder_open),
                  label: const Text('Open output'),
                ),
              const Spacer(),
              if (controller.lastDuration != null && !running)
                Text(
                  _statusText(controller),
                  style: TextStyle(
                    color: controller.lastExitCode == 0
                        ? Colors.greenAccent
                        : Colors.redAccent,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: TerminalView(_terminal),
        ),
      ],
    );
  }
}
