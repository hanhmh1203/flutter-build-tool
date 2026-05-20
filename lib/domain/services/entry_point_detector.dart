import 'dart:io';

class EntryPointDetector {
  const EntryPointDetector();

  /// Scans the top-level lib/ directory for Dart files that declare a main()
  /// function. Returns relative paths such as "lib/main.dart".
  /// Always returns at minimum ["lib/main.dart"] (even if not present on disk)
  /// so the dropdown always has a default option.
  Future<List<String>> detect(String projectPath) async {
    const defaultEntry = 'lib/main.dart';
    final libDir = Directory('$projectPath/lib');
    if (!libDir.existsSync()) return const [defaultEntry];

    try {
      final results = <String>[];
      final entities = libDir.listSync(recursive: false);
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.dart')) {
          final content = await entity.readAsString();
          if (content.contains('void main(') ||
              content.contains('Future<void> main(')) {
            final rel = 'lib/${entity.uri.pathSegments.last}';
            results.add(rel);
          }
        }
      }
      results.sort();
      if (!results.contains(defaultEntry)) {
        results.insert(0, defaultEntry);
      }
      return results;
    } catch (_) {
      return const [defaultEntry];
    }
  }
}
