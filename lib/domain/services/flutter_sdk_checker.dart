import 'dart:io';

class SdkStatus {
  const SdkStatus({required this.available, this.version, this.error});
  final bool available;
  final String? version;
  final String? error;
}

class FlutterSdkChecker {
  const FlutterSdkChecker();

  Future<SdkStatus> check({String executable = 'flutter'}) async {
    try {
      // Use login shell so PATH from ~/.zprofile / ~/.zshrc is inherited.
      // Plain `Process.run('flutter', ...)` uses /bin/sh which misses user PATH
      // in macOS GUI apps.
      final result = await Process.run(
        '/bin/zsh',
        ['-l', '-c', '$executable --version'],
      ).timeout(const Duration(seconds: 10));
      if (result.exitCode != 0) {
        return SdkStatus(available: false, error: result.stderr.toString());
      }
      final first = result.stdout.toString().split('\n').first.trim();
      return SdkStatus(available: true, version: first);
    } catch (e) {
      return SdkStatus(available: false, error: e.toString());
    }
  }
}
