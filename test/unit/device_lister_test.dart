import 'package:build_tool/domain/services/device_lister.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses JSON output into FlutterDevice list', () {
    const json = '''
[
  {"name":"iPhone 15","id":"7E1F","platformType":"ios","emulator":false},
  {"name":"macOS","id":"macos","platformType":"darwin","emulator":false}
]
''';
    final devices = DeviceLister.parseJson(json);
    expect(devices.length, 2);
    expect(devices[0].id, '7E1F');
    expect(devices[0].name, 'iPhone 15');
    expect(devices[0].platformType, 'ios');
    expect(devices[1].id, 'macos');
  });

  test('returns empty list on garbage', () {
    expect(DeviceLister.parseJson('not json'), isEmpty);
  });

  test('returns empty list on empty array', () {
    expect(DeviceLister.parseJson('[]'), isEmpty);
  });
}
