import 'dart:io';
import 'package:build_tool/data/app_paths.dart';
import 'package:build_tool/data/hive_setup.dart';
import 'package:build_tool/data/repositories/build_log_repository.dart';
import 'package:build_tool/domain/models/build_log.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tmp;
  late BuildLogRepository repo;
  late AppPaths paths;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('blr');
    paths = AppPaths(base: tmp);
    await paths.ensure();
    final boxes = await initHive(paths);
    repo = BuildLogRepository(boxes.buildLogs, paths);
  });

  tearDown(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  BuildLog mk(String id, String projectId, DateTime start) => BuildLog(
        id: id,
        projectId: projectId,
        commandLabel: 'X',
        fullCommand: 'echo X',
        startedAt: start,
        logFilePath: '${paths.logDirFor(projectId).path}/$id.log',
      );

  test('add inserts log entry', () async {
    await repo.add(mk('l1', 'p1', DateTime.utc(2026, 5, 1)));
    expect(repo.forProject('p1').single.id, 'l1');
  });

  test('forProject returns most recent first', () async {
    await repo.add(mk('a', 'p1', DateTime.utc(2026, 5, 1)));
    await repo.add(mk('b', 'p1', DateTime.utc(2026, 5, 2)));
    expect(repo.forProject('p1').map((l) => l.id), ['b', 'a']);
  });

  test('retention trims old logs beyond limit', () async {
    for (var i = 0; i < 55; i++) {
      await repo.add(mk('l$i', 'p1',
          DateTime.utc(2026, 5, 1).add(Duration(seconds: i))));
    }
    await repo.enforceRetention('p1', keep: 50);
    expect(repo.forProject('p1').length, 50);
    expect(repo.forProject('p1').first.id, 'l54');
    expect(repo.forProject('p1').last.id, 'l5');
  });

  test('retention also deletes log files', () async {
    final logDir = paths.logDirFor('p1');
    await logDir.create(recursive: true);
    final fileA = File('${logDir.path}/a.log');
    await fileA.writeAsString('old');
    await repo.add(mk('a', 'p1', DateTime.utc(2026, 5, 1)));
    await repo.add(mk('b', 'p1', DateTime.utc(2026, 5, 2)));
    await repo.enforceRetention('p1', keep: 1);
    expect(fileA.existsSync(), isFalse);
  });

  test('finish updates exitCode and duration', () async {
    final log = mk('l1', 'p1', DateTime.utc(2026, 5, 1));
    await repo.add(log);
    await repo.finish('l1',
        exitCode: 0, duration: const Duration(seconds: 5));
    final loaded = repo.forProject('p1').single;
    expect(loaded.exitCode, 0);
    expect(loaded.duration, const Duration(seconds: 5));
  });
}
