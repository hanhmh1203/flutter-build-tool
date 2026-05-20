import 'dart:io';
import 'package:build_tool/data/app_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempBase;

  setUp(() async {
    tempBase = await Directory.systemTemp.createTemp('build_tool_test');
  });

  tearDown(() async {
    if (tempBase.existsSync()) await tempBase.delete(recursive: true);
  });

  test('hiveDir is <base>/hive', () {
    final paths = AppPaths(base: tempBase);
    expect(paths.hiveDir.path, '${tempBase.path}/hive');
  });

  test('logDir for project is <base>/logs/<projectId>', () {
    final paths = AppPaths(base: tempBase);
    expect(paths.logDirFor('p1').path, '${tempBase.path}/logs/p1');
  });

  test('ensure() creates missing directories', () async {
    final paths = AppPaths(base: tempBase);
    await paths.ensure();
    expect(paths.hiveDir.existsSync(), isTrue);
    expect(Directory('${tempBase.path}/logs').existsSync(), isTrue);
  });
}
