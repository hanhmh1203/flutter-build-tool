import 'dart:io';
import 'package:uuid/uuid.dart';
import '../models/project.dart';
import 'pubspec_parser.dart';

class ProjectImportException implements Exception {
  ProjectImportException({required this.code, required this.message});
  final String code;
  final String message;
  @override
  String toString() => 'ProjectImportException($code): $message';
}

class ProjectImporter {
  const ProjectImporter();

  Future<Project> import(String projectPath) async {
    final pubspec = File('$projectPath/pubspec.yaml');
    if (!pubspec.existsSync()) {
      throw ProjectImportException(
        code: 'NO_PUBSPEC',
        message: 'No pubspec.yaml at $projectPath',
      );
    }
    final String content;
    try {
      content = await pubspec.readAsString();
    } on FileSystemException catch (e) {
      throw ProjectImportException(
        code: 'READ_FAILED',
        message: e.message,
      );
    }
    final PubspecInfo info;
    try {
      info = parsePubspec(content);
    } on PubspecParseException catch (e) {
      throw ProjectImportException(
        code: 'MALFORMED_PUBSPEC',
        message: e.message,
      );
    }
    return Project(
      id: const Uuid().v4(),
      name: info.name,
      path: projectPath,
      addedAt: DateTime.now().toUtc(),
    );
  }
}
