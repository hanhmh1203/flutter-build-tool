import 'dart:io';
import 'package:hive/hive.dart';
import '../app_paths.dart';
import '../../domain/models/build_log.dart';

class BuildLogRepository {
  BuildLogRepository(this._box, this._paths);
  final Box<BuildLog> _box;
  final AppPaths _paths;

  AppPaths get paths => _paths;

  List<BuildLog> forProject(String projectId) {
    final items =
        _box.values.where((l) => l.projectId == projectId).toList();
    items.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return items;
  }

  Future<void> add(BuildLog log) => _box.put(log.id, log);

  Future<void> finish(String id,
      {required int exitCode, required Duration duration}) async {
    final log = _box.get(id);
    if (log == null) return;
    log.exitCode = exitCode;
    log.duration = duration;
    await log.save();
  }

  Future<void> enforceRetention(String projectId, {int keep = 50}) async {
    final logs = forProject(projectId);
    if (logs.length <= keep) return;
    final toDelete = logs.sublist(keep);
    for (final log in toDelete) {
      final f = File(log.logFilePath);
      if (f.existsSync()) {
        try {
          await f.delete();
        } catch (_) {/* swallow */}
      }
      await _box.delete(log.id);
    }
  }
}
