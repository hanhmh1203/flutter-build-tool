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
      final result = await Process.run(executable, ['--version'],
              runInShell: true)
          .timeout(const Duration(seconds: 10));
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
