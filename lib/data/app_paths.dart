import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AppPaths {
  AppPaths({required this.base});

  final Directory base;

  Directory get hiveDir => Directory('${base.path}/hive');
  Directory get logsRoot => Directory('${base.path}/logs');
  Directory logDirFor(String projectId) =>
      Directory('${logsRoot.path}/$projectId');

  Future<void> ensure() async {
    await hiveDir.create(recursive: true);
    await logsRoot.create(recursive: true);
  }

  static Future<AppPaths> forApp() async {
    final dir = await getApplicationSupportDirectory();
    final base = Directory('${dir.path}/build_tool');
    await base.create(recursive: true);
    final paths = AppPaths(base: base);
    await paths.ensure();
    return paths;
  }
}
