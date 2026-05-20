import 'package:build_tool/domain/models/command_intent.dart';
import 'package:build_tool/domain/services/command_composer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const composer = CommandComposer();

  test('run with device and flavor', () {
    final cmd = composer.compose(
      const RunIntent(deviceId: 'iPhone15', flavor: 'prod'),
      cleanBeforeBuild: false,
    );
    expect(cmd.label, 'Run (prod)');
    expect(cmd.shell, "flutter run -d 'iPhone15' --flavor 'prod'");
  });

  test('run without flavor omits --flavor', () {
    final cmd = composer.compose(
      const RunIntent(deviceId: 'macos', flavor: null),
      cleanBeforeBuild: false,
    );
    expect(cmd.shell, "flutter run -d 'macos'");
    expect(cmd.label, 'Run');
  });

  test('build APK release with flavor', () {
    final cmd = composer.compose(
      const BuildApkIntent(flavor: 'prod'),
      cleanBeforeBuild: false,
    );
    expect(cmd.shell, "flutter build apk --release --flavor 'prod'");
    expect(cmd.label, 'Build APK (prod)');
  });

  test('build APK with cleanBeforeBuild prepends clean+pub get', () {
    final cmd = composer.compose(
      const BuildApkIntent(flavor: 'dev'),
      cleanBeforeBuild: true,
    );
    expect(
      cmd.shell,
      "flutter clean && flutter pub get && flutter build apk --release --flavor 'dev'",
    );
  });

  test('clean+pub composes the chain', () {
    final cmd = composer.compose(const CleanIntent(), cleanBeforeBuild: false);
    expect(cmd.shell, 'flutter clean && flutter pub get');
    expect(cmd.label, 'Clean + Pub get');
  });

  test('build_runner intent', () {
    final cmd =
        composer.compose(const BuildRunnerIntent(), cleanBeforeBuild: false);
    expect(cmd.shell,
        'dart run build_runner build --delete-conflicting-outputs');
    expect(cmd.label, 'build_runner');
  });

  test('custom intent uses raw command and label', () {
    final cmd = composer.compose(
      const CustomIntent(label: 'Deploy', command: 'firebase deploy'),
      cleanBeforeBuild: false,
    );
    expect(cmd.shell, 'firebase deploy');
    expect(cmd.label, 'Deploy');
  });

  test('flavor with shell special chars is single-quoted safely', () {
    final cmd = composer.compose(
      const BuildApkIntent(flavor: "weird'name"),
      cleanBeforeBuild: false,
    );
    expect(cmd.shell, contains(r"--flavor 'weird'\''name'"));
  });
}
