import 'dart:convert';
import 'dart:io';

import '../models/flutter_device.dart';

class DeviceLister {
  const DeviceLister();

  /// Runs `flutter devices --machine` and parses the result.
  /// Returns empty list on any failure (timeout, non-zero exit, parse error).
  Future<List<FlutterDevice>> list() async {
    try {
      // Use login shell so Flutter is on PATH in macOS GUI apps.
      final result = await Process.run(
        '/bin/zsh',
        ['-l', '-c', 'flutter devices --machine'],
      ).timeout(const Duration(seconds: 10));
      if (result.exitCode != 0) return const [];
      // Strip any non-JSON preamble from login shell (e.g. greeting messages)
      final raw = result.stdout.toString();
      final jsonStart = raw.indexOf('[');
      if (jsonStart < 0) return const [];
      return parseJson(raw.substring(jsonStart));
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
