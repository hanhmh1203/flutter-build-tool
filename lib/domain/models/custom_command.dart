import 'package:hive/hive.dart';

part 'custom_command.g.dart';

@HiveType(typeId: 1)
class CustomCommand {
  CustomCommand({
    required this.id,
    required this.label,
    required this.command,
    this.icon,
  });

  @HiveField(0)
  final String id;
  @HiveField(1)
  String label;
  @HiveField(2)
  String command;
  @HiveField(3)
  String? icon;
}
