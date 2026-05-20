import 'dart:convert';
import 'dart:io';

import '../models/flutter_device.dart';

class DeviceLister {
  const DeviceLister();

  /// Runs `flutter devices --machine` and parses the result.
  /// Returns empty list on any failure (timeout, non-zero exit, parse error).
  Future<List<FlutterDevice>> list() async {
    try {
      final result = await Process.run(
        'flutter',
        ['devices', '--machine'],
        runInShell: true,
      ).timeout(const Duration(seconds: 10));
      if (result.exitCode != 0) return const [];
      return parseJson(result.stdout.toString());
    } catch (_) {
      return const [];
    }
  }

  static List<FlutterDevice> parseJson(String input) {
    try {
      final decoded = jsonDecode(input);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((m) => FlutterDevice(
                id: (m['id'] ?? '').toString(),
                name: (m['name'] ?? '').toString(),
                platformType: (m['platformType'] ?? '').toString(),
                isEmulator: m['emulator'] == true,
              ))
          .where((d) => d.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
