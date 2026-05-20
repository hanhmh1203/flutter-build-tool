import 'package:hive/hive.dart';
import '../domain/models/build_log.dart';
import '../domain/models/custom_command.dart';
import '../domain/models/project.dart';
import 'app_paths.dart';

class HiveBoxes {
  HiveBoxes({required this.projects, required this.buildLogs});
  final Box<Project> projects;
  final Box<BuildLog> buildLogs;
}

Future<HiveBoxes> initHive(AppPaths paths) async {
  Hive.init(paths.hiveDir.path);
  if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(ProjectAdapter());
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(CustomCommandAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(BuildLogAdapter());

  final projects = await Hive.openBox<Project>('projects');
  final buildLogs = await Hive.openBox<BuildLog>('build_logs');
  return HiveBoxes(projects: projects, buildLogs: buildLogs);
}
