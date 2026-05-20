import 'dart:io';

import 'package:build_tool/data/app_paths.dart';
import 'package:build_tool/data/hive_setup.dart';
import 'package:build_tool/domain/models/flutter_device.dart';
import 'package:build_tool/domain/models/project.dart';
import 'package:build_tool/domain/services/device_lister.dart';
import 'package:build_tool/domain/services/flavor_detector.dart';
import 'package:build_tool/state/providers.dart';
import 'package:build_tool/ui/project_detail/toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class FakeDevices extends DeviceLister {
  const FakeDevices();
  @override
  Future<List<FlutterDevice>> list() async => const [
        FlutterDevice(
            id: 'macos',
            name: 'macOS',
            platformType: 'darwin',
            isEmulator: false),
        FlutterDevice(
            id: 'iPhone',
            name: 'iPhone 15',
            platformType: 'ios',
            isEmulator: false),
      ];
}

class FakeFlavors extends FlavorDetector {
  @override
  Future<List<String>> detect(String _) async => ['dev', 'prod'];
}

void main() {
  late Directory tmp;
  late HiveBoxes boxes;
  late AppPaths paths;
  late Project project;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('tb');
    paths = AppPaths(base: tmp);
    await paths.ensure();
    boxes = await initHive(paths);
    project =
        Project(id: 'p', name: 'x', path: '/tmp/x', addedAt: DateTime.now());
    await boxes.projects.put('p', project);
  });

  tearDown(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  testWidgets('renders flavor and device dropdowns from providers',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appPathsProvider.overrideWithValue(paths),
        hiveBoxesProvider.overrideWithValue(boxes),
        deviceListerProvider.overrideWithValue(const FakeDevices()),
        flavorDetectorProvider.overrideWithValue(FakeFlavors()),
      ],
      child: MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: ProjectToolbar(project: project)))),
    ));
    // Settle async futures (FakeDevices and FakeFlavors resolve instantly)
    await tester.pumpAndSettle();

    // Clean before build toggle is always visible
    expect(find.text('Clean before build'), findsOneWidget);

    // Open the flavor dropdown and verify items loaded from FakeFlavors
    await tester.tap(find.text('(default)').first);
    await tester.pumpAndSettle();
    expect(find.text('dev'), findsWidgets);
    // Dismiss
    await tester.tapAt(const Offset(0, 0));
    await tester.pumpAndSettle();

    // Open the device dropdown and verify items loaded from FakeDevices
    await tester.tap(find.text('(pick)'));
    await tester.pumpAndSettle();
    expect(find.text('macOS'), findsWidgets);
  });
}
