import 'dart:io';
import 'package:build_tool/domain/services/output_finder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;
  late Directory apkDir;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('output');
    apkDir = Directory('${tmp.path}/build/app/outputs/flutter-apk');
    await apkDir.create(recursive: true);
  });

  tearDown(() async => tmp.delete(recursive: true));

  Future<File> mkApk(String name, DateTime mtime) async {
    final f = File('${apkDir.path}/$name');
    await f.writeAsBytes([0]);
    await f.setLastModified(mtime);
    return f;
  }

  test('picks newest -release.apk by mtime', () async {
    await mkApk('app-prod-release.apk', DateTime.utc(2026, 5, 1));
    final newer = await mkApk('app-dev-release.apk', DateTime.utc(2026, 5, 5));
    final found = await const OutputFinder().findApk(tmp.path);
    expect(found?.path, newer.path);
  });

  test('ignores -debug.apk and unsigned variants', () async {
    await mkApk('app-debug.apk', DateTime.utc(2026, 6, 1));
    final release =
        await mkApk('app-prod-release.apk', DateTime.utc(2026, 5, 1));
    final found = await const OutputFinder().findApk(tmp.path);
    expect(found?.path, release.path);
  });

  test('returns null when no apk present', () async {
    final found = await const OutputFinder().findApk(tmp.path);
    expect(found, isNull);
  });

  test('returns null when folder missing entirely', () async {
    await apkDir.delete(recursive: true);
    final found = await const OutputFinder().findApk(tmp.path);
    expect(found, isNull);
  });
}
