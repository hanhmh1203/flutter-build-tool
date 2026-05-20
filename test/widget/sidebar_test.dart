import 'dart:io';

import 'package:build_tool/data/app_paths.dart';
import 'package:build_tool/data/hive_setup.dart';
import 'package:build_tool/domain/models/project.dart';
import 'package:build_tool/state/providers.dart';
import 'package:build_tool/ui/sidebar/sidebar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tmp;
  late HiveBoxes boxes;
  late AppPaths paths;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('sb');
    paths = AppPaths(base: tmp);
    await paths.ensure();
    boxes = await initHive(paths);
    await boxes.projects.put(
      'p1',
      Project(
        id: 'p1',
        name: 'my_app',
        path: '/tmp/my_app',
        addedAt: DateTime.now(),
      ),
    );
  });

  tearDown(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  testWidgets('Sidebar lists projects from store', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appPathsProvider.overrideWithValue(paths),
        hiveBoxesProvider.overrideWithValue(boxes),
      ],
      child: const MaterialApp(home: Scaffold(body: Sidebar())),
    ));
    expect(find.text('my_app'), findsOneWidget);
  });

  testWidgets('Tapping a project sets selectedProjectId', (tester) async {
    late ProviderContainer container;
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appPathsProvider.overrideWithValue(paths),
        hiveBoxesProvider.overrideWithValue(boxes),
      ],
      child: Builder(builder: (context) {
        container = ProviderScope.containerOf(context);
        return const MaterialApp(home: Scaffold(body: Sidebar()));
      }),
    ));
    await tester.tap(find.text('my_app'));
    await tester.pump();
    expect(container.read(selectedProjectIdProvider), 'p1');
  });
}
