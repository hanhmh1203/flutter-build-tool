import 'dart:io';
import 'package:build_tool/domain/services/output_renamer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUp(() async => tmp = await Directory.systemTemp.createTemp('rename'));
  tearDown(() async => tmp.delete(recursive: true));

  Future<File> apk(String name) async {
    final f = File('${tmp.path}/$name');
    await f.writeAsBytes([1, 2, 3]);
    return f;
  }

  Future<void> writePubspec(String content) async {
    await File('${tmp.path}/pubspec.yaml').writeAsString(content);
  }

  test('copies APK to <name>-v<version>.apk in same folder', () async {
    final source = await apk('app-prod-release.apk');
    await writePubspec('name: my_app\nversion: 1.2.3+45\n');
    final result = await const OutputRenamer().rename(
      sourceApk: source,
      projectPath: tmp.path,
    );
    expect(result.target.path, '${tmp.path}/my_app-v1.2.3.apk');
    expect(result.target.existsSync(), isTrue);
    expect(result.fallbackVersionUsed, isFalse);
    expect(source.existsSync(), isTrue);
  });

  test('fallback v0.0.0 when version missing', () async {
    final source = await apk('app-release.apk');
    await writePubspec('name: foo_app\n');
    final result = await const OutputRenamer().rename(
      sourceApk: source,
      projectPath: tmp.path,
    );
    expect(result.target.path.endsWith('foo_app-v0.0.0.apk'), isTrue);
    expect(result.fallbackVersionUsed, isTrue);
  });

  test('overwrites existing target with same name', () async {
    final source = await apk('app-release.apk');
    await writePubspec('name: my_app\nversion: 1.0.0\n');
    final existing = File('${tmp.path}/my_app-v1.0.0.apk');
    await existing.writeAsBytes([9, 9, 9]);
    final result = await const OutputRenamer().rename(
      sourceApk: source,
      projectPath: tmp.path,
    );
    expect(await result.target.readAsBytes(), [1, 2, 3]);
  });

  test('sanitizes weird name chars', () async {
    final source = await apk('app-release.apk');
    await writePubspec('name: My App!\nversion: 1.0.0\n');
    final result = await const OutputRenamer().rename(
      sourceApk: source,
      projectPath: tmp.path,
    );
    expect(result.target.path.endsWith('my_app_-v1.0.0.apk'), isTrue);
  });

  test('missing pubspec throws OutputRenameException', () async {
    final source = await apk('app-release.apk');
    expect(
      () => const OutputRenamer().rename(
        sourceApk: source,
        projectPath: tmp.path,
      ),
      throwsA(isA<OutputRenameException>()),
    );
  });
}
