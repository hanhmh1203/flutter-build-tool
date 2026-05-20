import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:build_tool/data/app_paths.dart';
import 'package:build_tool/data/hive_setup.dart';
import 'package:build_tool/domain/models/project.dart';
import 'package:build_tool/domain/services/command_runner.dart';
import 'package:build_tool/state/providers.dart';
import 'package:build_tool/ui/project_detail/command_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class RecordingRunner implements CommandRunner {
  final List<String> calls = [];
  late Completer<int> exit;
  late StreamController<Uint8List> out;

  @override
  RunningCommand start({
    required String command,
    required String workingDir,
    Map<String, String>? env,
  }) {
    calls.add(command);
    out = StreamController<Uint8List>.broadcast();
    exit = Completer<int>();
    return RunningCommand(
      output: out.stream,
      exitCode: exit.future,
      startedAt: DateTime.now(),
      onKill: () {
        if (!exit.isCompleted) exit.complete(-1);
      },
    );
  }
}

void main() {
  late Directory tmp;
  late HiveBoxes boxes;
  late AppPaths paths;
  late Project project;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('cg');
    paths = AppPaths(base: tmp);
    await paths.ensure();
    boxes = await initHive(paths);
    project = Project(
      id: 'p',
      name: 'x',
      path: '/tmp/x',
      addedAt: DateTime.now(),
      lastFlavor: 'prod',
      lastDeviceId: 'iPhone',
    );
    await boxes.projects.put('p', project);
  });

  tearDown(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  testWidgets('Build APK button triggers composed flutter build apk command',
      (tester) async {
    final runner = RecordingRunner();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appPathsProvider.overrideWithValue(paths),
        hiveBoxesProvider.overrideWithValue(boxes),
        commandRunnerProvider.overrideWithValue(runner),
      ],
      child: MaterialApp(
          home: Scaffold(body: CommandGrid(project: project))),
    ));
    await tester.tap(find.text('Build APK'));
    await tester.pump();
    expect(runner.calls.single, "flutter build apk --release --flavor 'prod'");
  });
}
