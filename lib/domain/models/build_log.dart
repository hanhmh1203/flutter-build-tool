import 'package:hive/hive.dart';

part 'build_log.g.dart';

@HiveType(typeId: 2)
class BuildLog extends HiveObject {
  BuildLog({
    required this.id,
    required this.projectId,
    required this.commandLabel,
    required this.fullCommand,
    required this.startedAt,
    required this.logFilePath,
    Duration? duration,
    this.exitCode,
  }) : durationMs = duration?.inMilliseconds;

  @HiveField(0)
  final String id;
  @HiveField(1)
  final String projectId;
  @HiveField(2)
  final String commandLabel;
  @HiveField(3)
  final String fullCommand;
  @HiveField(4)
  final DateTime startedAt;
  @HiveField(5)
  int? durationMs;
  @HiveField(6)
  int? exitCode;
  @HiveField(7)
  final String logFilePath;

  Duration? get duration =>
      durationMs == null ? null : Duration(milliseconds: durationMs!);
  set duration(Duration? d) => durationMs = d?.inMilliseconds;
}
