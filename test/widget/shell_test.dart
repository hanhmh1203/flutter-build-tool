import 'dart:io';

import 'package:build_tool/data/app_paths.dart';
import 'package:build_tool/data/hive_setup.dart';
import 'package:build_tool/state/providers.dart';
import 'package:build_tool/ui/shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tmp;
  late HiveBoxes boxes;
  late AppPaths paths;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('shell_widget');
    paths = AppPaths(base: tmp);
    await paths.ensure();
    boxes = await initHive(paths);
  });

  tearDown(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  testWidgets('Shell renders sidebar and empty-state when no project selected',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appPathsProvider.overrideWithValue(paths),
        hiveBoxesProvider.overrideWithValue(boxes),
      ],
      child: const MaterialApp(home: Shell()),
    ));
    expect(find.text('Projects'), findsOneWidget);
    expect(find.text('Select a project to begin'), findsOneWidget);
  });
}
