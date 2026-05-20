import 'dart:io';
import 'package:build_tool/domain/services/pubspec_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String fixture(String name) =>
      File('test/fixtures/$name').readAsStringSync();

  test('parses name and version, strips build number', () {
    final info = parsePubspec(fixture('pubspec_full.yaml'));
    expect(info.name, 'my_app');
    expect(info.version, '1.2.3');
    expect(info.buildNumber, '45');
  });

  test('missing version yields null version', () {
    final info = parsePubspec(fixture('pubspec_no_version.yaml'));
    expect(info.name, 'another_app');
    expect(info.version, isNull);
    expect(info.buildNumber, isNull);
  });

  test('sanitizeName lowercases and strips weird chars', () {
    expect(PubspecInfo.sanitize('My App!'), 'my_app_');
    expect(PubspecInfo.sanitize('foo-bar_2'), 'foo-bar_2');
  });

  test('malformed yaml throws PubspecParseException', () {
    expect(() => parsePubspec(':\n:\n:'),
        throwsA(isA<PubspecParseException>()));
  });
}
