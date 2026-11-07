import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:talker_flutter/talker_flutter.dart';

/// The app's log: everything the app prints with [debugPrint], plus uncaught
/// errors. People can read, search and share it from the Logs screen, which
/// is what a useful bug report needs; developers still see it in the console.
Talker appLog = TalkerFlutter.init();

/// Routes [debugPrint] and uncaught errors into [appLog]. Call once at start-up.
void initAppLog() {
  // Keep the original console printer for talker's own output: talker's
  // default output on Android, Windows and Linux is debugPrint, which would
  // loop back into the log once debugPrint is redirected below.
  final consolePrint = debugPrint;
  appLog = TalkerFlutter.init(
    logger: TalkerLogger(output: (message) => consolePrint(message)),
    settings: TalkerSettings(maxHistoryItems: 2000),
  );

  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) appLog.debug(message);
  };

  final previousFlutterOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    appLog.handle(details.exception, details.stack, 'Flutter error');
    previousFlutterOnError?.call(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    appLog.handle(error, stack, 'Uncaught error');
    return true;
  };
}

/// Opens the Logs screen.
void showAppLogs(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TalkerScreen(talker: appLog, appBarTitle: 'Logs'),
    ),
  );
}
