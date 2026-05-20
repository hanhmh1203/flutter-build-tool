import 'dart:io';
import 'package:build_tool/domain/services/project_importer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmp;

  setUp(() async => tmp = await Directory.systemTemp.createTemp('imp'));
  tearDown(() async => tmp.delete(recursive: true));

  test('valid flutter project: returns Project with parsed name', () async {
    await File('${tmp.path}/pubspec.yaml')
        .writeAsString('name: my_app\nversion: 0.1.0\n');
    final result = await const ProjectImporter().import(tmp.path);
    expect(result.name, 'my_app');
    expect(result.path, tmp.path);
    expect(result.id, isNotEmpty);
    expect(result.cleanBeforeBuild, isFalse);
    expect(result.customCommands, isEmpty);
  });

  test('missing pubspec throws ProjectImportException with code', () async {
    expect(
      () => const ProjectImporter().import(tmp.path),
      throwsA(predicate(
          (e) => e is ProjectImportException && e.code == 'NO_PUBSPEC')),
    );
  });

  test('malformed pubspec throws with code MALFORMED_PUBSPEC', () async {
    await File('${tmp.path}/pubspec.yaml').writeAsString(':\n:\n:');
    expect(
      () => const ProjectImporter().import(tmp.path),
      throwsA(predicate(
          (e) => e is ProjectImportException && e.code == 'MALFORMED_PUBSPEC')),
    );
  });
}
