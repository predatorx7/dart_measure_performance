import 'package:measure_performance/measure_performance.dart';
import 'package:test/test.dart';
import 'dart:async';

void main() {
  group('MeasurePerformance', () {
    late MeasurePerformance measure;

    setUp(() {
      measure = MeasurePerformance();
    });

    tearDown(() {
      measure.dispose();
    });

    test('should initialize with default sampling frequency', () {
      expect(measure.samplingFrequency, const Duration(milliseconds: 10));
    });

    test('should initialize with custom sampling frequency', () {
      final customMeasure = MeasurePerformance(
        samplingFrequency: const Duration(milliseconds: 100),
      );
      expect(
        customMeasure.samplingFrequency,
        const Duration(milliseconds: 100),
      );
      customMeasure.dispose();
    });

    test('should measure elapsed time correctly', () async {
      measure.start();
      await Future.delayed(const Duration(milliseconds: 100));
      measure.stop();
      final report = measure.getReport();

      expect(report.elapsed.inMilliseconds, greaterThanOrEqualTo(100));
    });

    test('should collect memory usage samples', () async {
      measure.start();
      // Allocate some memory
      final list = List<int>.filled(1000000, 0);
      await Future.delayed(const Duration(milliseconds: 50));
      measure.stop();
      final report = measure.getReport();

      expect(report.memoryUsageBytes, isNotEmpty);
      expect(report.memoryUsageBeforeMeasurementBytes, greaterThan(0));
      expect(report.memoryUsageAfterMeasurementBytes, greaterThan(0));
      // Prevent the list from being optimized away
      expect(list.length, 1000000);
    });

    test('should calculate memory statistics correctly', () async {
      measure.start();
      // Create memory usage pattern
      final list1 = List<int>.filled(1000000, 0);
      await Future.delayed(const Duration(milliseconds: 50));
      final list2 = List<int>.filled(2000000, 0);
      await Future.delayed(const Duration(milliseconds: 50));
      measure.stop();
      final report = measure.getReport();

      expect(
        report.maxMemoryUsageBytes,
        greaterThan(report.minMemoryUsageBytes),
      );
      expect(
        report.averageMemoryUsageBytes,
        allOf([
          greaterThanOrEqualTo(report.minMemoryUsageBytes),
          lessThanOrEqualTo(report.maxMemoryUsageBytes),
        ]),
      );
      // Prevent lists from being optimized away
      expect(list1.length + list2.length, 3000000);
    });

    test('should throw when starting an already started measurement', () {
      measure.start();
      expect(() => measure.start(), throwsStateError);
      measure.stop();
    });

    test('should handle multiple start-stop cycles', () {
      measure.start();
      measure.stop();
      measure.start();
      measure.stop();
      final report = measure.getReport();
      expect(report.elapsed, isNotNull);
    });

    test('should reset all measurements', () {
      measure.start();
      measure.stop();
      measure.reset();
      final report = measure.getReport();
      expect(report.memoryUsageBytes, isEmpty);
      expect(report.memoryUsageBeforeMeasurementBytes, 0);
      expect(report.memoryUsageAfterMeasurementBytes, 0);
    });

    test('should handle empty measurement period', () {
      measure.start();
      measure.stop();
      final report = measure.getReport();
      expect(report.memoryUsageBytes, hasLength(greaterThanOrEqualTo(2)));
      expect(report.memoryUsageBeforeMeasurementBytes, greaterThan(0));
      expect(report.memoryUsageAfterMeasurementBytes, greaterThan(0));
      expect(report.elapsed, greaterThan(Duration.zero));
    });

    test('should convert to JSON correctly', () {
      measure.start();
      measure.stop();
      final report = measure.getReport();
      final json = report.toJson();

      expect(json['elapsed'], isA<int>());
      expect(json['memoryUsageBeforeMeasurementBytes'], isA<int>());
      expect(json['memoryUsageAfterMeasurementBytes'], isA<int>());
      expect(json['memoryUsageBytes'], isA<List<int>>());
    });

    test('should handle dispose correctly', () {
      expect(() => measure.start(), returnsNormally);
      expect(() => measure.start(), throwsStateError);
      measure.dispose();
      expect(() => measure.start(), returnsNormally);
    });
  });
}
