import 'package:dicom_rs_example/presentation/controllers/image_interaction_controller.dart';
import 'package:dicom_rs_example/presentation/widgets/image_display_widget.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps the image area at 400x400 and counts what the input did.
class _Harness {
  _Harness(this.controller) {
    controller
      ..onNextImage = () {
        next++;
      }
      ..onPreviousImage = () {
        previous++;
      }
      ..onBrightnessContrastChanged = (b, c) {
        brightnessChanges++;
      }
      ..onImageTapped = (position, size) {
        taps.add(position);
      };
  }

  final ImageInteractionController controller;
  int next = 0;
  int previous = 0;
  int brightnessChanges = 0;
  final taps = <Offset>[];

  Future<void> pump(WidgetTester tester, {Size? imageSize}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 400,
              height: 400,
              child: AnimatedBuilder(
                animation: controller,
                builder:
                    (context, _) => ImageDisplayWidget(
                      imageSize: imageSize,
                      imageData: null,
                      scale: controller.zoom,
                      measurements: const [],
                      currentMeasurementPoints: const [],
                      interactionController: controller,
                    ),
              ),
            ),
          ),
        ),
      );
}

void main() {
  late _Harness h;
  Offset center(WidgetTester t) => t.getCenter(find.byType(ImageDisplayWidget));

  setUp(() => h = _Harness(ImageInteractionController()));

  group('mouse', () {
    testWidgets('one wheel notch moves one slice, not several', (t) async {
      await h.pump(t);
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      mouse.hover(center(t));
      // A notch on macOS arrives as several small smooth-scroll events.
      for (final dy in [12.0, 14.0, 14.0, 12.0]) {
        await t.sendEventToBinding(mouse.scroll(Offset(0, dy)));
      }
      expect(h.next, 1);
      // A notch on Windows/Linux is one large event.
      await t.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
      expect(h.previous, 1);
    });

    testWidgets('Ctrl + wheel zooms at the pointer instead of changing slice', (
      t,
    ) async {
      await h.pump(t);
      final mouse = TestPointer(1, PointerDeviceKind.mouse);
      mouse.hover(center(t) + const Offset(50, 0));
      await t.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await t.sendEventToBinding(mouse.scroll(const Offset(0, -100)));
      await t.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(h.controller.zoom, greaterThan(1.0));
      expect(h.next + h.previous, 0);
    });

    testWidgets('left-drag pans the image', (t) async {
      await h.pump(t);
      final gesture = await t.startGesture(
        center(t),
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      await gesture.moveBy(const Offset(40, 0));
      await gesture.moveBy(const Offset(40, 30));
      await gesture.up();
      await t.pump();
      expect(h.controller.pan.dx, greaterThan(40));
      expect(h.controller.pan.dy, greaterThan(10));
      expect(h.brightnessChanges, 0);
    });

    testWidgets('right-drag adjusts brightness and does not pan', (t) async {
      await h.pump(t);
      final gesture = await t.startGesture(
        center(t),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await gesture.moveBy(const Offset(40, 0));
      await gesture.moveBy(const Offset(40, 0));
      await gesture.up();
      expect(h.brightnessChanges, greaterThan(0));
      expect(h.controller.pan, Offset.zero);
    });

    testWidgets(
      'a click maps back to image coordinates when zoomed and panned',
      (t) async {
        await h.pump(t);
        h.controller.setZoomForTest(2.0, pan: const Offset(20, 0));
        await t.pump();
        await t.tapAt(center(t) + const Offset(40, 0));
        // 40 px right of centre on screen, minus 20 px of pan, at 2x zoom.
        expect(h.taps.single.dx, closeTo(200 + 10, 0.5));
        expect(h.taps.single.dy, closeTo(200, 0.5));
      },
    );
  });

  group('trackpad', () {
    testWidgets('two-finger swipe changes slices', (t) async {
      await h.pump(t);
      final pad = TestPointer(2, PointerDeviceKind.trackpad);
      await t.sendEventToBinding(pad.panZoomStart(center(t)));
      // Fingers move up 95 px: content scrolls forward about three slices.
      var pan = Offset.zero;
      for (var i = 0; i < 5; i++) {
        pan += const Offset(0, -19);
        await t.sendEventToBinding(pad.panZoomUpdate(center(t), pan: pan));
      }
      await t.sendEventToBinding(pad.panZoomEnd());
      expect(h.next, 3);
      expect(h.previous, 0);
    });

    testWidgets('pinch zooms and builds on the current zoom', (t) async {
      await h.pump(t);
      final pad = TestPointer(2, PointerDeviceKind.trackpad);
      for (final scale in [2.0, 1.5]) {
        await t.sendEventToBinding(pad.panZoomStart(center(t)));
        await t.sendEventToBinding(pad.panZoomUpdate(center(t), scale: scale));
        await t.sendEventToBinding(pad.panZoomEnd());
      }
      expect(h.controller.zoom, closeTo(3.0, 0.01));
      expect(h.next + h.previous, 0);
    });
  });

  testWidgets('clicks map to the image when it is centred in a larger area', (
    t,
  ) async {
    // A 200x200 image centred in the 400x400 viewer area.
    await h.pump(t, imageSize: const Size(200, 200));
    await t.tapAt(center(t));
    expect(h.taps.last, const Offset(100, 100));

    h.controller.setZoomForTest(2.0);
    await t.pump();
    await t.tapAt(center(t) + const Offset(40, 0));
    expect(h.taps.last.dx, closeTo(120, 0.5));
    expect(h.taps.last.dy, closeTo(100, 0.5));
  });
}
