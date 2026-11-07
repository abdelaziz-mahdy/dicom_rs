import 'package:dicom_rs_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the welcome screen with its actions', (tester) async {
    await tester.pumpWidget(const DicomViewerApp());
    await tester.pumpAndSettle();

    expect(find.text('Welcome to DICOM Viewer'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Help'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Examples'), findsOneWidget);
  });
}
