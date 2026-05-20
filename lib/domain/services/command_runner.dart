import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_pty/flutter_pty.dart';

abstract class CommandRunner {
  RunningCommand start({
    required String command,
    required String workingDir,
    Map<String, String>? env,
  });
}

class RunningCommand {
  RunningCommand({
    required this.output,
    required this.exitCode,
    required this.startedAt,
    required void Function() onKill,
  }) : _onKill = onKill;

  final Stream<Uint8List> output;
  final Future<int> exitCode;
  final DateTime startedAt;
  final void Function() _onKill;

  void kill() => _onKill();
}

/// PTY-backed runner — uses flutter_pty for full ANSI color output.
/// Only works inside the Flutter native embedding (not in bare unit tests).
class PtyCommandRunner implements CommandRunner {
  const PtyCommandRunner();

  @override
  RunningCommand start({
    required String command,
    required String workingDir,
    Map<String, String>? env,
  }) {
    final pty = Pty.start(
      '/bin/zsh',
      arguments: ['-l', '-c', command],
      workingDirectory: workingDir,
      environment: env ?? Map.from(Platform.environment),
    );

    final controller = StreamController<Uint8List>.broadcast();
    final outSub = pty.output.listen(controller.add);

    final exitCompleter = Completer<int>();
    pty.exitCode.then((code) async {
      await outSub.cancel();
      await controller.close();
      if (!exitCompleter.isCompleted) exitCompleter.complete(code);
    });

    var killed = false;
    void doKill() {
      if (killed) return;
      killed = true;
      pty.kill(ProcessSignal.sigterm);
      Future.delayed(const Duration(seconds: 2), () {
        if (!exitCompleter.isCompleted) {
          pty.kill(ProcessSignal.sigkill);
        }
      });
    }

    return RunningCommand(
      output: controller.stream,
      exitCode: exitCompleter.future,
      startedAt: DateTime.now(),
      onKill: doKill,
    );
  }
}

/// Process.start fallback — no PTY, loses ANSI colors in some CLIs.
/// Used in unit tests and as a runtime fallback if flutter_pty is unavailable.
class ProcessCommandRunner implements CommandRunner {
  const ProcessCommandRunner();

  @override
  RunningCommand start({
    required String command,
    required String workingDir,
    Map<String, String>? env,
  }) {
    final baseEnv = env ?? Map.from(Platform.environment);
    // Keep TERM set so programs that check it still output color sequences.
    baseEnv['TERM'] = 'xterm-256color';

    final controller = StreamController<Uint8List>.broadcast();
    final exitCompleter = Completer<int>();
    final startedAt = DateTime.now();

    // Mutable kill action; populated once the process starts.
    // Captured by the closure passed to RunningCommand.
    void Function()? killAction;

    Process.start(
      '/bin/zsh',
      ['-l', '-c', command],
      workingDirectory: workingDir,
      environment: baseEnv,
    ).then((process) {
      killAction = () {
        process.kill(ProcessSignal.sigterm);
        Future.delayed(const Duration(seconds: 2), () {
          if (!exitCompleter.isCompleted) process.kill(ProcessSignal.sigkill);
        });
      };

      StreamSubscription<List<int>>? stdoutSub;
      StreamSubscription<List<int>>? stderrSub;

      void finish(int code) {
        stdoutSub?.cancel();
        stderrSub?.cancel();
        controller.close();
        if (!exitCompleter.isCompleted) exitCompleter.complete(code);
      }

      stdoutSub = process.stdout.listen(
        (data) => controller.add(Uint8List.fromList(data)),
        onDone: () {},
      );
      stderrSub = process.stderr.listen(
        (data) => controller.add(Uint8List.fromList(data)),
        onDone: () {},
      );
      process.exitCode.then(finish);
    }).catchError((Object e) {
      controller.addError(e);
      controller.close();
      if (!exitCompleter.isCompleted) exitCompleter.complete(1);
    });

    return RunningCommand(
      output: controller.stream,
      exitCode: exitCompleter.future,
      startedAt: startedAt,
      onKill: () => killAction?.call(),
    );
  }
}
