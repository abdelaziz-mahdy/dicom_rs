import 'package:dicom_rs_example/domain/entities/measurement_entity.dart';
import 'package:flutter_test/flutter_test.dart';

MeasurementEntity measurement(
  MeasurementType type,
  List<(double, double)> points, {
  List<double>? pixelSpacing = const [0.5, 0.5],
}) => MeasurementEntity(
  id: 'm',
  type: type,
  points: [for (final (x, y) in points) MeasurementPoint(x: x, y: y)],
  pixelSpacing: pixelSpacing,
);

void main() {
  group('angle', () {
    test('is the angle between the arms, at most 180 degrees', () {
      // Arms 5 degrees above and 5 degrees below the left-hand horizontal:
      // their directions are about +175 and -175 degrees.
      final m = measurement(MeasurementType.angle, [
        (100 - 99.6, 100 - 8.7),
        (100, 100),
        (100 - 99.6, 100 + 8.7),
      ]);
      expect(m.displayValue, '10.0 °');
    });

    test('a right angle reads 90 degrees', () {
      final m = measurement(MeasurementType.angle, [
        (200, 100),
        (100, 100),
        (100, 0),
      ]);
      expect(m.displayValue, '90.0 °');
    });

    test('is in degrees even without pixel spacing', () {
      final m = measurement(MeasurementType.angle, [
        (200, 100),
        (100, 100),
        (100, 0),
      ], pixelSpacing: null);
      expect(m.displayValue, '90.0 °');
    });
  });

  test('area of a four-point polygon', () {
    // A 100x50 px rectangle at 0.5 mm/px is 50 x 25 mm.
    final m = measurement(MeasurementType.area, [
      (0, 0),
      (100, 0),
      (100, 50),
      (0, 50),
    ]);
    expect(m.displayValue, '1250.0 mm²');
  });

  test('circle shows its radius', () {
    final m = measurement(MeasurementType.circle, [(0, 0), (30, 40)]);
    expect(m.displayValue, 'r 25.0 mm');
  });

  test('area needs at least three points and has no fixed maximum', () {
    expect(MeasurementType.area.requiredPoints, 3);
    expect(MeasurementType.area.closesByClickingFirstPoint, isTrue);
    expect(MeasurementType.distance.closesByClickingFirstPoint, isFalse);
  });
}
