import 'dart:io';

class OutputFinder {
  const OutputFinder();

  /// Returns the newest *-release.apk under build/app/outputs/flutter-apk/,
  /// or null if none.
  Future<File?> findApk(String projectPath) async {
    final dir = Directory('$projectPath/build/app/outputs/flutter-apk');
    if (!dir.existsSync()) return null;
    final candidates = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('-release.apk'))
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) =>
        b.statSync().modified.compareTo(a.statSync().modified));
    return candidates.first;
  }
}
