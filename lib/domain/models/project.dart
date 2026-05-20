import 'package:hive/hive.dart';
import 'custom_command.dart';

part 'project.g.dart';

@HiveType(typeId: 0)
class Project extends HiveObject {
  Project({
    required this.id,
    required this.name,
    required this.path,
    required this.addedAt,
    this.lastFlavor,
    this.lastDeviceId,
    this.cleanBeforeBuild = false,
    List<CustomCommand>? customCommands,
    this.lastOpenedAt,
  }) : customCommands = customCommands ?? <CustomCommand>[];

  @HiveField(0)
  final String id;
  @HiveField(1)
  String name;
  @HiveField(2)
  String path;
  @HiveField(3)
  String? lastFlavor;
  @HiveField(4)
  String? lastDeviceId;
  @HiveField(5)
  bool cleanBeforeBuild;
  @HiveField(6)
  List<CustomCommand> customCommands;
  @HiveField(7)
  DateTime addedAt;
  @HiveField(8)
  DateTime? lastOpenedAt;
}
