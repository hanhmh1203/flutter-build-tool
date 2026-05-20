import 'dart:async';
import 'dart:typed_data';

import '../domain/services/command_runner.dart';

enum RunnerState { idle, running, success, failed, cancelled }

class RunningInfo {
  RunningInfo({
    required this.label,
    required this.command,
    required this.startedAt,
  });
  final String label;
  final String command;
  final DateTime startedAt;
}

class ProjectRunnerController {
  ProjectRunnerController({required CommandRunner runner}) : _runner = runner;

  final CommandRunner _runner;
  final StreamController<RunnerState> _stateCtrl =
      StreamController<RunnerState>.broadcast();
  final StreamController<Uint8List> _outputCtrl =
      StreamController<Uint8List>.broadcast();

  RunningCommand? _running;
  RunningInfo? _current;
  RunnerState _state = RunnerState.idle;
  int? _lastExitCode;
  Duration? _lastDuration;

  Stream<RunnerState> get stream => _stateCtrl.stream;
  Stream<Uint8List> get output => _outputCtrl.stream;
  RunnerState get state => _state;
  bool get isRunning => _state == RunnerState.running;
  RunningInfo? get current => _current;
  int? get lastExitCode => _lastExitCode;
  Duration? get lastDuration => _lastDuration;

  void start({
    required String label,
    required String command,
    required String workingDir,
    Map<String, String>? env,
    void Function(int exitCode, Duration duration)? onComplete,
  }) {
    if (_state == RunnerState.running) {
      throw StateError('Another command is already running');
    }
    final running = _runner.start(
      command: command,
      workingDir: workingDir,
      env: env,
    );
    _running = running;
    _current = RunningInfo(
      label: label,
      command: command,
      startedAt: running.startedAt,
    );
    _setState(RunnerState.running);

    final outSub = running.output.listen(_outputCtrl.add);
    running.exitCode.then((code) async {
      _lastExitCode = code;
      _lastDuration = DateTime.now().difference(running.startedAt);
      await outSub.cancel();
      if (code == 0) {
        _setState(RunnerState.success);
      } else if (code < 0) {
        _setState(RunnerState.cancelled);
      } else {
        _setState(RunnerState.failed);
      }
      _running = null;
      onComplete?.call(code, _lastDuration!);
    });
  }

  void stop() => _running?.kill();

  void _setState(RunnerState s) {
    _state = s;
    _stateCtrl.add(s);
  }

  Future<void> dispose() async {
    await _stateCtrl.close();
    await _outputCtrl.close();
  }
}
