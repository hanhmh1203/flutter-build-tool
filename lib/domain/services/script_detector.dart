import 'dart:io';

class ShScript {
  const ShScript({
    required this.name,
    required this.path,
    required this.desc,
  });

  /// Filename, e.g. "build_nightly.sh"
  final String name;

  /// Relative path, e.g. "scripts/build_nightly.sh"
  final String path;

  /// First `# ` comment line in the file
  final String desc;
}

class ScriptDetector {
  const ScriptDetector();

  Future<List<ShScript>> detect(String projectPath) async {
    final sep = Platform.pathSeparator;
    final scriptsDir = Directory('$projectPath${sep}scripts');
    if (!await scriptsDir.exists()) return const [];

    final results = <ShScript>[];

    final entities = await scriptsDir.list().toList();
    for (final entity in entities) {
      if (entity is! File) continue;
      final fullPath = entity.path;
      // Extract filename from full path
      final lastSep = fullPath.lastIndexOf(sep);
      final name = lastSep >= 0 ? fullPath.substring(lastSep + 1) : fullPath;
      if (!name.endsWith('.sh')) continue;

      String desc = '';
      try {
        final lines = await entity.readAsLines();
        for (final line in lines) {
          if (line.startsWith('# ')) {
            desc = line.substring(2).trim();
            break;
          }
        }
      } catch (_) {
        // Ignore read errors
      }

      results.add(ShScript(
        name: name,
        path: 'scripts$sep$name',
        desc: desc,
      ));
    }

    results.sort((a, b) => a.name.compareTo(b.name));
    return results;
  }
}
