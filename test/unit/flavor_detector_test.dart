import 'dart:io';
import 'package:build_tool/domain/services/flavor_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String fx(String n) => File('test/fixtures/$n').readAsStringSync();

  test('groovy: extracts three flavors', () {
    final flavors = FlavorDetector.parseGradle(
      fx('build_gradle_groovy_flavors.txt'),
      isKotlin: false,
    );
    expect(flavors, ['dev', 'staging', 'prod']);
  });

  test('groovy: no productFlavors returns empty', () {
    final flavors = FlavorDetector.parseGradle(
      fx('build_gradle_groovy_no_flavors.txt'),
      isKotlin: false,
    );
    expect(flavors, isEmpty);
  });

  test('kotlin DSL: extracts flavors from create("name")', () {
    final flavors = FlavorDetector.parseGradle(
      fx('build_gradle_kts_flavors.txt'),
      isKotlin: true,
    );
    expect(flavors, ['dev', 'prod']);
  });

  test('garbage input returns empty (no throw)', () {
    expect(FlavorDetector.parseGradle('::: not gradle :::', isKotlin: false),
        isEmpty);
  });

  test('detectFromProject reads from android/app/build.gradle', () async {
    final tmp = await Directory.systemTemp.createTemp('flavor');
    final gradle = File('${tmp.path}/android/app/build.gradle');
    await gradle.create(recursive: true);
    await gradle.writeAsString(fx('build_gradle_groovy_flavors.txt'));

    final flavors = await FlavorDetector().detect(tmp.path);
    expect(flavors, ['dev', 'staging', 'prod']);
    await tmp.delete(recursive: true);
  });

  test('detectFromProject prefers .kts when both present', () async {
    final tmp = await Directory.systemTemp.createTemp('flavor');
    final groovy = File('${tmp.path}/android/app/build.gradle');
    final kts = File('${tmp.path}/android/app/build.gradle.kts');
    await groovy.create(recursive: true);
    await groovy.writeAsString(fx('build_gradle_groovy_no_flavors.txt'));
    await kts.writeAsString(fx('build_gradle_kts_flavors.txt'));

    final flavors = await FlavorDetector().detect(tmp.path);
    expect(flavors, ['dev', 'prod']);
    await tmp.delete(recursive: true);
  });
}
