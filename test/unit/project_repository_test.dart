import 'dart:io';
import 'package:build_tool/data/app_paths.dart';
import 'package:build_tool/data/hive_setup.dart';
import 'package:build_tool/data/repositories/project_repository.dart';
import 'package:build_tool/domain/models/project.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tmp;
  late ProjectRepository repo;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('project_repo');
    final paths = AppPaths(base: tmp);
    await paths.ensure();
    final boxes = await initHive(paths);
    repo = ProjectRepository(boxes.projects);
  });

  tearDown(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  Project sample(String id) => Project(
        id: id,
        name: 'app_$id',
        path: '/Users/me/$id',
        addedAt: DateTime.utc(2026, 5, 1),
      );

  test('add and list returns inserted project', () async {
    await repo.add(sample('a'));
    expect(repo.list().map((p) => p.id), ['a']);
  });

  test('list sorts by lastOpenedAt descending, nulls last', () async {
    final a = sample('a')..lastOpenedAt = DateTime.utc(2026, 1, 1);
    final b = sample('b')..lastOpenedAt = DateTime.utc(2026, 6, 1);
    final c = sample('c');
    await repo.add(a);
    await repo.add(b);
    await repo.add(c);
    expect(repo.list().map((p) => p.id), ['b', 'a', 'c']);
  });

  test('update persists changes', () async {
    final p = sample('a');
    await repo.add(p);
    p.lastFlavor = 'prod';
    await repo.update(p);
    expect(repo.get('a')!.lastFlavor, 'prod');
  });

  test('remove deletes', () async {
    await repo.add(sample('a'));
    await repo.remove('a');
    expect(repo.get('a'), isNull);
  });

  test('exists returns true after add', () async {
    await repo.add(sample('a'));
    expect(repo.exists('a'), isTrue);
    expect(repo.exists('zz'), isFalse);
  });
}
