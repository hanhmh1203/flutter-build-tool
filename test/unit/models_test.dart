import 'dart:io';
import 'package:build_tool/domain/models/build_log.dart';
import 'package:build_tool/domain/models/custom_command.dart';
import 'package:build_tool/domain/models/project.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('models_test');
    Hive.init(tmp.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ProjectAdapter());
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(CustomCommandAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(BuildLogAdapter());
  });

  tearDown(() async {
    await Hive.close();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('Project round-trips through Hive', () async {
    final box = await Hive.openBox<Project>('projects');
    final p = Project(
      id: 'abc',
      name: 'my_app',
      path: '/Users/me/my_app',
      lastFlavor: 'prod',
      lastDeviceId: 'iPhone15',
      cleanBeforeBuild: true,
      customCommands: [
        CustomCommand(id: 'c1', label: 'Deploy', command: 'firebase deploy'),
      ],
      addedAt: DateTime.utc(2026, 5, 1),
    );
    await box.put(p.id, p);

    final loaded = box.get('abc')!;
    expect(loaded.name, 'my_app');
    expect(loaded.lastFlavor, 'prod');
    expect(loaded.customCommands.single.label, 'Deploy');
    expect(loaded.cleanBeforeBuild, isTrue);
  });

  test('BuildLog round-trips', () async {
    final box = await Hive.openBox<BuildLog>('build_logs');
    final l = BuildLog(
      id: 'l1',
      projectId: 'abc',
      commandLabel: 'Build APK (prod)',
      fullCommand: 'flutter build apk --release --flavor prod',
      startedAt: DateTime.utc(2026, 5, 1, 12),
      duration: const Duration(seconds: 90),
      exitCode: 0,
      logFilePath: '/tmp/logs/abc/log1.log',
    );
    await box.put(l.id, l);
    expect(box.get('l1')!.exitCode, 0);
  });
}
