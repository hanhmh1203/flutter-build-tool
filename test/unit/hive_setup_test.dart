import 'dart:io';
import 'package:build_tool/data/app_paths.dart';
import 'package:build_tool/data/hive_setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tmp;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('hive_setup');
  });

  tearDown(() async {
    await Hive.close();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  test('initHive opens both boxes', () async {
    final paths = AppPaths(base: tmp);
    await paths.ensure();
    final result = await initHive(paths);
    expect(result.projects.isOpen, isTrue);
    expect(result.buildLogs.isOpen, isTrue);
  });

  test('initHive is idempotent', () async {
    final paths = AppPaths(base: tmp);
    await paths.ensure();
    await initHive(paths);
    await initHive(paths);
  });
}
