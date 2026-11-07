import 'package:dicom_rs_example/screens/dicom_loading_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late int completions;
  late List<String> errors;

  Future<void> pumpLoadingScreen(WidgetTester tester) async {
    completions = 0;
    errors = [];
    await tester.pumpWidget(
      MaterialApp(
        home: DicomLoadingScreen(
          onLoadingComplete: () => completions++,
          onLoadingError: errors.add,
        ),
      ),
    );
  }

  Future<void> waitForCompletionDelay(WidgetTester tester) async {
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('reports completion once when several completed events arrive', (
    tester,
  ) async {
    await pumpLoadingScreen(tester);

    // A directory load sends one event when the scan ends and another when
    // the images are loaded. Popping the route twice removed the home screen.
    DicomLoadingProgressNotifier.notify(
      DicomLoadingProgressEvent.completed(totalLoaded: 3),
    );
    await tester.pump(const Duration(milliseconds: 50));
    DicomLoadingProgressNotifier.notify(
      DicomLoadingProgressEvent.completed(totalLoaded: 3),
    );
    await waitForCompletionDelay(tester);

    expect(completions, 1);
    expect(errors, isEmpty);
  });

  testWidgets('reports an error once when several error events arrive', (
    tester,
  ) async {
    await pumpLoadingScreen(tester);

    DicomLoadingProgressNotifier.notify(
      DicomLoadingProgressEvent.error('Error scanning directory'),
    );
    DicomLoadingProgressNotifier.notify(
      DicomLoadingProgressEvent.error('No valid DICOM content found'),
    );
    await waitForCompletionDelay(tester);

    expect(errors, ['Error scanning directory']);
    expect(completions, 0);
  });

  testWidgets('ignores an error that arrives after completion', (tester) async {
    await pumpLoadingScreen(tester);

    DicomLoadingProgressNotifier.notify(
      DicomLoadingProgressEvent.completed(totalLoaded: 1),
    );
    DicomLoadingProgressNotifier.notify(
      DicomLoadingProgressEvent.error('late failure'),
    );
    await waitForCompletionDelay(tester);

    expect(completions, 1);
    expect(errors, isEmpty);
  });

  testWidgets('finishes when the load completed before the screen opened', (
    tester,
  ) async {
    completions = 0;
    errors = [];
    // Example studies load from the app bundle in milliseconds, so the load
    // can finish before the screen subscribes to progress events.
    final task = Future<void>.value();
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: DicomLoadingScreen(
          task: task,
          onLoadingComplete: () => completions++,
          onLoadingError: errors.add,
        ),
      ),
    );
    await waitForCompletionDelay(tester);

    expect(completions, 1);
    expect(errors, isEmpty);
  });

  testWidgets('reports a failed load from its task', (tester) async {
    completions = 0;
    errors = [];
    final task = Future<void>.error(Exception('no valid DICOM files'));
    task.ignore();
    await tester.pumpWidget(
      MaterialApp(
        home: DicomLoadingScreen(
          task: task,
          onLoadingComplete: () => completions++,
          onLoadingError: errors.add,
        ),
      ),
    );
    await waitForCompletionDelay(tester);

    expect(completions, 0);
    expect(errors.single, contains('no valid DICOM files'));
  });
}
