import 'package:dicom_rs_example/domain/entities/measurement_entity.dart';
import 'package:dicom_rs_example/presentation/widgets/slice_measurements.dart';
import 'package:flutter_test/flutter_test.dart';

MeasurementEntity distance(String id) => MeasurementEntity(
  id: id,
  type: MeasurementType.distance,
  points: const [MeasurementPoint(x: 0, y: 0), MeasurementPoint(x: 10, y: 0)],
);

void main() {
  late SliceMeasurements slices;
  setUp(() => slices = SliceMeasurements());

  test('a measurement stays on the slice it was drawn on', () {
    slices.onSlice(3).add(distance('a'));

    expect(slices.onSlice(3).map((m) => m.id), ['a']);
    expect(slices.onSlice(4), isEmpty);
    expect(slices.countOn(3), 1);
    expect(slices.countOn(4), 0);
  });

  test('copy puts a new copy on the other slice and keeps the original', () {
    slices.onSlice(3).add(distance('a'));

    final copy = slices.copy('a', from: 3, to: 4, newId: 'b');

    expect(copy!.id, 'b');
    expect(copy.points, distance('a').points);
    expect(slices.onSlice(3).map((m) => m.id), ['a']);
    expect(slices.onSlice(4).map((m) => m.id), ['b']);
  });

  test('move takes the measurement off its slice and onto the other', () {
    slices.onSlice(3).add(distance('a'));

    expect(slices.move('a', from: 3, to: 4), isTrue);

    expect(slices.onSlice(3), isEmpty);
    expect(slices.onSlice(4).map((m) => m.id), ['a']);
  });

  test('remove and clear', () {
    slices.onSlice(3).addAll([distance('a'), distance('b')]);
    slices.onSlice(5).add(distance('c'));

    slices.remove('a', slice: 3);
    expect(slices.onSlice(3).map((m) => m.id), ['b']);

    slices.clearAll();
    expect(slices.countOn(3) + slices.countOn(5), 0);
  });

  test('copying or moving a missing measurement does nothing', () {
    expect(slices.copy('x', from: 1, to: 2, newId: 'y'), isNull);
    expect(slices.move('x', from: 1, to: 2), isFalse);
    expect(slices.onSlice(2), isEmpty);
  });
}
