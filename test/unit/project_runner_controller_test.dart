import 'dart:async';
import 'dart:typed_data';

import 'package:build_tool/domain/services/command_runner.dart';
import 'package:build_tool/state/project_runner_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCommandRunner implements CommandRunner {
  late StreamController<Uint8List> controller;
  late Completer<int> exit;
  bool killed = false;

  @override
  RunningCommand start({
    required String command,
    required String workingDir,
    Map<String, String>? env,
  }) {
    controller = StreamController<Uint8List>.broadcast();
    exit = Completer<int>();
    return RunningCommand(
      output: controller.stream,
      exitCode: exit.future,
      startedAt: DateTime.now(),
      onKill: () {
        killed = true;
        if (!exit.isCompleted) exit.complete(-1);
      },
    );
  }
}

void main() {
  test('start emits running state then completed on exit 0', () async {
    final runner = FakeCommandRunner();
    final c = ProjectRunnerController(runner: runner);

    final events = <RunnerState>[];
    c.stream.listen(events.add);

    c.start(label: 'echo', command: 'echo hi', workingDir: '/tmp');
    expect(c.current?.label, 'echo');
    expect(c.isRunning, isTrue);

    runner.controller.add(Uint8List.fromList('hello\n'.codeUnits));
    runner.exit.complete(0);

    // Wait for stream events.
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(c.isRunning, isFalse);
    expect(c.lastExitCode, 0);
    expect(events.any((e) => e == RunnerState.running), isTrue);
    expect(events.last, RunnerState.success);
  });

  test('stop calls kill on the running command', () async {
    final runner = FakeCommandRunner();
    final c = ProjectRunnerController(runner: runner);
    c.start(label: 'sleep', command: 'sleep 60', workingDir: '/tmp');

    c.stop();
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(runner.killed, isTrue);
    expect(c.isRunning, isFalse);
  });

  test('starting a second command while running is rejected', () async {
    final runner = FakeCommandRunner();
    final c = ProjectRunnerController(runner: runner);
    c.start(label: 'a', command: 'a', workingDir: '/tmp');

    expect(
      () => c.start(label: 'b', command: 'b', workingDir: '/tmp'),
      throwsStateError,
    );
  });
}
