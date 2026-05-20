import 'dart:io';

class FlavorDetector {
  /// Reads android/app/build.gradle(.kts) and returns flavor names.
  /// Returns empty list on any failure (missing files, parse errors, etc.).
  Future<List<String>> detect(String projectPath) async {
    final kts = File('$projectPath/android/app/build.gradle.kts');
    final groovy = File('$projectPath/android/app/build.gradle');
    if (kts.existsSync()) {
      try {
        return parseGradle(await kts.readAsString(), isKotlin: true);
      } catch (_) {
        return const [];
      }
    }
    if (groovy.existsSync()) {
      try {
        return parseGradle(await groovy.readAsString(), isKotlin: false);
      } catch (_) {
        return const [];
      }
    }
    return const [];
  }

  static List<String> parseGradle(String content, {required bool isKotlin}) {
    final block = _extractBlock(content, 'productFlavors');
    if (block == null) return const [];
    return isKotlin ? _extractKts(block) : _extractGroovy(block);
  }

  static String? _extractBlock(String src, String keyword) {
    final i = src.indexOf(keyword);
    if (i < 0) return null;
    final open = src.indexOf('{', i);
    if (open < 0) return null;
    var depth = 1;
    var j = open + 1;
    while (j < src.length && depth > 0) {
      final c = src[j];
      if (c == '{') depth++;
      if (c == '}') depth--;
      j++;
    }
    if (depth != 0) return null;
    return src.substring(open + 1, j - 1);
  }

  static List<String> _extractGroovy(String block) {
    final result = <String>[];
    final lines = block.split('\n');
    var depth = 0;
    for (final raw in lines) {
      final line = raw.trim();
      if (depth == 0) {
        final m = RegExp(r'^([a-zA-Z_][a-zA-Z0-9_]*)\s*\{').firstMatch(line);
        if (m != null) result.add(m.group(1)!);
      }
      for (final c in line.split('')) {
        if (c == '{') depth++;
        if (c == '}') depth--;
      }
    }
    return result;
  }

  static List<String> _extractKts(String block) {
    final pattern = RegExp(r'(?:create|register)\s*\(\s*"([^"]+)"');
    return pattern.allMatches(block).map((m) => m.group(1)!).toList();
  }
}
