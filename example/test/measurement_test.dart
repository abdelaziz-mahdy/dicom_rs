import 'package:flutter_test/flutter_test.dart';
import 'package:dicom_rs_example/models/measurement_models.dart';

void main() {
  group('Measurement Models Tests', () {
    test('MeasurementPoint distance calculation', () {
      final point1 = MeasurementPoint(0, 0);
      final point2 = MeasurementPoint(3, 4);
      
      expect(point1.distanceTo(point2), equals(5.0));
    });
    
    test('Distance measurement calculation', () {
      final measurement = DicomMeasurement.distance(
        id: 'test-1',
        start: MeasurementPoint(0, 0),
        end: MeasurementPoint(10, 0),
      );
      
      final result = measurement.calculateValue();
      expect(result.pixelValue, equals(10.0));
      expect(result.displayText, equals('10.00 px'));
    });
    
    test('Distance measurement with pixel spacing', () {
      final measurement = DicomMeasurement.distance(
        id: 'test-2',
        start: MeasurementPoint(0, 0),
        end: MeasurementPoint(10, 0),
      );
      
      final result = measurement.calculateValue(pixelSpacing: [0.5], units: 'mm');
      expect(result.pixelValue, equals(10.0));
      expect(result.realWorldValue, equals(5.0));
      expect(result.displayText, equals('5.00 mm'));
    });
    
    test('Angle measurement calculation', () {
      final measurement = DicomMeasurement.angle(
        id: 'test-3',
        vertex: MeasurementPoint(0, 0),
        point1: MeasurementPoint(1, 0),
        point2: MeasurementPoint(0, 1),
      );
      
      final result = measurement.calculateValue();
      expect(result.pixelValue, closeTo(90.0, 0.1));
      expect(result.displayText, equals('90.0°'));
    });
    
    test('Circle measurement calculation', () {
      final measurement = DicomMeasurement.circle(
        id: 'test-4',
        center: MeasurementPoint(0, 0),
        edge: MeasurementPoint(5, 0),
      );
      
      final result = measurement.calculateValue();
      expect(result.pixelValue, equals(5.0)); // radius
      expect(result.additionalData['area'], closeTo(78.54, 0.01)); // π * 5²
    });
    
    test('MeasurementManager operations', () {
      final manager = MeasurementManager();
      
      final measurement1 = DicomMeasurement.distance(
        id: 'test-5',
        start: MeasurementPoint(0, 0),
        end: MeasurementPoint(10, 0),
      );
      
      final measurement2 = DicomMeasurement.angle(
        id: 'test-6',
        vertex: MeasurementPoint(0, 0),
        point1: MeasurementPoint(1, 0),
        point2: MeasurementPoint(0, 1),
      );
      
      manager.addMeasurement(measurement1);
      manager.addMeasurement(measurement2);
      
      expect(manager.measurements.length, equals(2));
      expect(manager.getMeasurement('test-5'), equals(measurement1));
      expect(manager.getMeasurementsByType(MeasurementType.distance).length, equals(1));
      expect(manager.getMeasurementsByType(MeasurementType.angle).length, equals(1));
      
      expect(manager.removeMeasurement('test-5'), isTrue);
      expect(manager.measurements.length, equals(1));
      expect(manager.getMeasurement('test-5'), isNull);
    });
    
    test('MeasurementManager JSON serialization', () {
      final manager = MeasurementManager(pixelSpacing: [0.5, 0.5], units: 'mm');
      
      final measurement = DicomMeasurement.distance(
        id: 'test-7',
        start: MeasurementPoint(0, 0),
        end: MeasurementPoint(10, 0),
      );
      
      manager.addMeasurement(measurement);
      
      final json = manager.toJson();
      expect(json['pixelSpacing'], equals([0.5, 0.5]));
      expect(json['units'], equals('mm'));
      expect(json['measurements'].length, equals(1));
      
      final restoredManager = MeasurementManager.fromJson(json);
      expect(restoredManager.measurements.length, equals(1));
      expect(restoredManager.pixelSpacing, equals([0.5, 0.5]));
      expect(restoredManager.units, equals('mm'));
    });
  });
}