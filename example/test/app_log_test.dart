import 'dart:ui';

import 'package:dicom_rs_example/core/app_log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DebugPrintCallback originalDebugPrint;
  late FlutterExceptionHandler? originalFlutterOnError;
  late ErrorCallback? originalPlatformOnError;

  setUp(() {
    originalDebugPrint = debugPrint;
    originalFlutterOnError = FlutterError.onError;
    originalPlatformOnError = PlatformDispatcher.instance.onError;
  });

  tearDown(() {
    debugPrint = originalDebugPrint;
    FlutterError.onError = originalFlutterOnError;
    PlatformDispatcher.instance.onError = originalPlatformOnError;
  });

  test('what the app prints ends up in the in-app log', () {
    initAppLog();
    debugPrint('Loading 3 files...');

    expect(
      appLog.history.map((entry) => entry.message),
      contains('Loading 3 files...'),
    );
  });

  test('uncaught errors end up in the in-app log', () {
    initAppLog();
    final handled = PlatformDispatcher.instance.onError!(
      StateError('decoder crashed'),
      StackTrace.current,
    );

    expect(handled, isTrue);
    expect(
      appLog.history.any(
        (entry) =>
            '${entry.exception}${entry.error}'.contains('decoder crashed'),
      ),
      isTrue,
    );
  });
}
