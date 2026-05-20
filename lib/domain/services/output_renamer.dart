import 'dart:io';
import 'pubspec_parser.dart';

class RenameResult {
  RenameResult({
    required this.target,
    required this.fallbackVersionUsed,
  });
  final File target;
  final bool fallbackVersionUsed;
}

class OutputRenameException implements Exception {
  OutputRenameException(this.message);
  final String message;
  @override
  String toString() => 'OutputRenameException: $message';
}

class OutputRenamer {
  const OutputRenamer();

  Future<RenameResult> rename({
    required File sourceApk,
    required String projectPath,
  }) async {
    final pubspecFile = File('$projectPath/pubspec.yaml');
    if (!pubspecFile.existsSync()) {
      throw OutputRenameException('pubspec.yaml not found at $projectPath');
    }
    final info = parsePubspec(await pubspecFile.readAsString());
    final safeName = PubspecInfo.sanitize(info.name);
    final version = info.version ?? '0.0.0';
    final fallback = info.version == null;

    final ext = sourceApk.path.endsWith('.apk') ? 'apk' : 'ipa';
    final dir = sourceApk.parent.path;
    final target = File('$dir/$safeName-v$version.$ext');
    if (target.existsSync()) {
      await target.delete();
    }
    final copied = await sourceApk.copy(target.path);
    return RenameResult(target: copied, fallbackVersionUsed: fallback);
  }
}
