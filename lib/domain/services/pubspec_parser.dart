import 'package:yaml/yaml.dart';

class PubspecInfo {
  PubspecInfo({required this.name, this.version, this.buildNumber});
  final String name;
  final String? version;
  final String? buildNumber;

  /// Sanitizes a name for safe filenames: lowercase, keep [a-z0-9_-], others → _.
  static String sanitize(String input) {
    final lower = input.toLowerCase();
    return lower.replaceAllMapped(RegExp(r'[^a-z0-9_-]'), (_) => '_');
  }
}

class PubspecParseException implements Exception {
  PubspecParseException(this.message);
  final String message;
  @override
  String toString() => 'PubspecParseException: $message';
}

PubspecInfo parsePubspec(String content) {
  final YamlMap doc;
  try {
    final parsed = loadYaml(content);
    if (parsed is! YamlMap) {
      throw PubspecParseException('pubspec root is not a map');
    }
    doc = parsed;
  } on YamlException catch (e) {
    throw PubspecParseException(e.message);
  }

  final name = doc['name'];
  if (name is! String || name.isEmpty) {
    throw PubspecParseException('pubspec has no `name`');
  }

  final rawVersion = doc['version'];
  String? version;
  String? buildNumber;
  if (rawVersion is String && rawVersion.isNotEmpty) {
    final plus = rawVersion.indexOf('+');
    if (plus >= 0) {
      version = rawVersion.substring(0, plus);
      buildNumber = rawVersion.substring(plus + 1);
    } else {
      version = rawVersion;
    }
  }

  return PubspecInfo(name: name, version: version, buildNumber: buildNumber);
}
