import '../models/command_intent.dart';

class ComposedCommand {
  const ComposedCommand({required this.label, required this.shell});
  final String label;
  final String shell;
}

class CommandComposer {
  const CommandComposer();

  ComposedCommand compose(
    CommandIntent intent, {
    required bool cleanBeforeBuild,
    String flutterPath = 'flutter',
  }) {
    final fl = flutterPath;
    return switch (intent) {
      RunIntent(deviceId: final d, flavor: final f, entryPoint: final e) =>
        ComposedCommand(
          label: f == null ? 'Run' : 'Run ($f)',
          shell: _join([
            '$fl run',
            if (d.isNotEmpty) '-d ${_q(d)}',
            if (f != null) '--flavor ${_q(f)}',
            if (e != null && e != 'lib/main.dart') '--target ${_q(e)}',
          ]),
        ),
      BuildApkIntent(flavor: final f, entryPoint: final e) => ComposedCommand(
          label: f == null ? 'Build APK' : 'Build APK ($f)',
          shell: _withCleanPrefix(
            cleanBeforeBuild,
            _join([
              '$fl build apk --release',
              if (f != null) '--flavor ${_q(f)}',
              if (e != null && e != 'lib/main.dart') '--target ${_q(e)}',
            ]),
            fl: fl,
          ),
        ),
      BuildAabIntent(flavor: final f, entryPoint: final e) => ComposedCommand(
          label: f == null ? 'Build AAB' : 'Build AAB ($f)',
          shell: _withCleanPrefix(
            cleanBeforeBuild,
            _join([
              '$fl build appbundle --release',
              if (f != null) '--flavor ${_q(f)}',
              if (e != null && e != 'lib/main.dart') '--target ${_q(e)}',
            ]),
            fl: fl,
          ),
        ),
      BuildIpaIntent(flavor: final f, entryPoint: final e) => ComposedCommand(
          label: f == null ? 'Build IPA' : 'Build IPA ($f)',
          shell: _withCleanPrefix(
            cleanBeforeBuild,
            _join([
              '$fl build ipa --release',
              if (f != null) '--flavor ${_q(f)}',
              if (e != null && e != 'lib/main.dart') '--target ${_q(e)}',
            ]),
            fl: fl,
          ),
        ),
      CleanIntent() => ComposedCommand(
          label: 'Clean + Pub get',
          shell: '$fl clean && $fl pub get',
        ),
      BuildRunnerIntent() => const ComposedCommand(
          label: 'build_runner',
          shell: 'dart run build_runner build --delete-conflicting-outputs',
        ),
      CustomIntent(label: final l, command: final c) =>
        ComposedCommand(label: l, shell: c),
      ScriptIntent(label: final l, scriptPath: final sp) =>
        ComposedCommand(label: l, shell: 'bash ${_q(sp)}'),
    };
  }

  String _withCleanPrefix(bool clean, String tail, {required String fl}) =>
      clean ? '$fl clean && $fl pub get && $tail' : tail;

  String _join(List<String> parts) =>
      parts.where((p) => p.isNotEmpty).join(' ');

  /// POSIX shell single-quote escape: ' becomes '\''
  String _q(String input) {
    final escaped = input.replaceAll("'", r"'\''");
    return "'$escaped'";
  }
}
