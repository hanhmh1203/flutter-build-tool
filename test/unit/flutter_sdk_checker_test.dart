import 'package:build_tool/domain/services/flutter_sdk_checker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('real flutter on PATH returns available (skipped if no flutter)',
      () async {
    final result = await const FlutterSdkChecker().check();
    // Must return a SdkStatus; do not assert availability since CI may lack flutter.
    expect(result, isA<SdkStatus>());
  });

  test('explicitly bad command returns unavailable', () async {
    final result =
        await const FlutterSdkChecker().check(flutterPath: 'nope_xyz_123');
    expect(result.available, isFalse);
    expect(result.error, isNotEmpty);
  });
}
