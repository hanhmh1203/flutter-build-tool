import 'dart:async';
import 'dart:convert';

import 'package:build_tool/domain/services/command_runner.dart';
import 'package:flutter_test/flutter_test.dart';

// Unit tests use ProcessCommandRunner (no Flutter native embedding needed).
// PtyCommandRunner is exercised via the running app (flutter_pty requires the
// Flutter framework dylib, which is not available in bare dart test runs).
void main() {
  test('ProcessCommandRunner streams echo output and exits 0', () async {
    const runner = ProcessCommandRunner();
    final running = runner.start(
      command: "echo 'hello-process-world'",
      workingDir: '/tmp',
    );

    final buffer = StringBuffer();
    final sub = running.output
        .cast<List<int>>()
        .transform(utf8.decoder)
        .listen(buffer.write);

    final code = await running.exitCode.timeout(const Duration(seconds: 5));
    await sub.cancel();

    expect(code, 0);
    expect(buffer.toString(), contains('hello-process-world'));
  });

  test('ProcessCommandRunner kill() terminates running process', () async {
    const runner = ProcessCommandRunner();
    final running = runner.start(
      command: 'sleep 30',
      workingDir: '/tmp',
    );

    // Give the process time to start, then kill it.
    await Future<void>.delayed(const Duration(milliseconds: 200));
    running.kill();

    final code = await running.exitCode.timeout(const Duration(seconds: 5));
    expect(code, isNot(0)); // killed → non-zero exit
  });
}
