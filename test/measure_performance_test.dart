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
      expect(report.measurementStoppedAt.isAfter(report.measurementStartedAt), isTrue);
    });

    test('should collect memory usage samples', () async {
      measure.start();
      // Allocate some memory
      final list = List<int>.filled(1000000, 0);
      await Future.delayed(const Duration(milliseconds: 50));
      measure.stop();
      final report = measure.getReport();

      expect(report.memoryUsageBytes, hasLength(greaterThanOrEqualTo(2)));
      expect(report.memoryUsageBeforeMeasurementBytes, greaterThan(0));
      expect(report.memoryUsageAfterMeasurementBytes, greaterThan(0));
      expect(report.measurementStoppedAt.isAfter(report.measurementStartedAt), isTrue);
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

      expect(report.maxMemoryUsageBytes, greaterThan(report.minMemoryUsageBytes));
      expect(
        report.averageMemoryUsageBytes,
        allOf([
          greaterThanOrEqualTo(report.minMemoryUsageBytes),
          lessThanOrEqualTo(report.maxMemoryUsageBytes),
        ]),
      );
      expect(report.measurementStoppedAt.isAfter(report.measurementStartedAt), isTrue);
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
      final firstReport = measure.getReport();
      measure.start();
      measure.stop();
      final secondReport = measure.getReport();

      expect(firstReport.elapsed, greaterThan(Duration.zero));
      expect(secondReport.measurementStartedAt.isAfter(firstReport.measurementStoppedAt), isTrue);
      expect(secondReport.elapsed, greaterThan(Duration.zero));
      expect(secondReport.measurementStoppedAt.isAfter(secondReport.measurementStartedAt), isTrue);
    });

    test('should reset all measurements', () {
      measure.start();
      measure.stop();
      measure.reset();
      final report = measure.getReport();
      expect(report.memoryUsageBytes, isEmpty);
      expect(report.memoryUsageBeforeMeasurementBytes, 0);
      expect(report.memoryUsageAfterMeasurementBytes, 0);
      expect(report.measurementStartedAt, isNotNull);
      expect(report.measurementStoppedAt, isNotNull);
    });

    test('should handle empty measurement period', () {
      measure.start();
      measure.stop();
      final report = measure.getReport();
      expect(report.memoryUsageBytes, hasLength(greaterThanOrEqualTo(2)));
      expect(report.memoryUsageBeforeMeasurementBytes, greaterThan(0));
      expect(report.memoryUsageAfterMeasurementBytes, greaterThan(0));
      expect(report.elapsed, greaterThan(Duration.zero));
      expect(report.measurementStoppedAt.isAfter(report.measurementStartedAt), isTrue);
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
      expect(json['measurementStartedAt'], isA<String>());
      expect(json['measurementStoppedAt'], isA<String>());
      expect(
          DateTime.parse(json['measurementStoppedAt'] as String)
              .isAfter(DateTime.parse(json['measurementStartedAt'] as String)),
          isTrue);
    });

    test('should handle dispose correctly', () {
      expect(() => measure.start(), returnsNormally);
      expect(() => measure.start(), throwsStateError);
      measure.dispose();
      expect(() => measure.start(), returnsNormally);
    });
  });

  group('PerformanceReport', () {
    test('should convert to JSON with all fields', () {
      final report = PerformanceReport(
        measurementStartedAt: DateTime(2024, 1, 1, 12, 0),
        measurementStoppedAt: DateTime(2024, 1, 1, 12, 0, 1),
        elapsed: const Duration(seconds: 1),
        memoryUsageBeforeMeasurementBytes: 1000,
        memoryUsageAfterMeasurementBytes: 2000,
        memoryUsageBytes: [1000, 1500, 2000],
      );

      final json = report.toJson();

      expect(json['measurementStartedAt'], '2024-01-01T12:00:00.000');
      expect(json['measurementStoppedAt'], '2024-01-01T12:00:01.000');
      expect(json['elapsed'], 1000000); // 1 second in microseconds
      expect(json['memoryUsageBeforeMeasurementBytes'], 1000);
      expect(json['memoryUsageAfterMeasurementBytes'], 2000);
      expect(json['memoryUsageBytes'], [1000, 1500, 2000]);
    });

    test('should convert to JSON with empty memory samples', () {
      final report = PerformanceReport(
        measurementStartedAt: DateTime(2024, 1, 1, 12, 0),
        measurementStoppedAt: DateTime(2024, 1, 1, 12, 0, 1),
        elapsed: const Duration(seconds: 1),
        memoryUsageBeforeMeasurementBytes: 1000,
        memoryUsageAfterMeasurementBytes: 2000,
        memoryUsageBytes: const [],
      );

      final json = report.toJson();

      expect(json['measurementStartedAt'], '2024-01-01T12:00:00.000');
      expect(json['measurementStoppedAt'], '2024-01-01T12:00:01.000');
      expect(json['elapsed'], 1000000);
      expect(json['memoryUsageBeforeMeasurementBytes'], 1000);
      expect(json['memoryUsageAfterMeasurementBytes'], 2000);
      expect(json['memoryUsageBytes'], isEmpty);
    });

    test('should convert to JSON with single memory sample', () {
      final report = PerformanceReport(
        measurementStartedAt: DateTime(2024, 1, 1, 12, 0),
        measurementStoppedAt: DateTime(2024, 1, 1, 12, 0, 1),
        elapsed: const Duration(seconds: 1),
        memoryUsageBeforeMeasurementBytes: 1000,
        memoryUsageAfterMeasurementBytes: 2000,
        memoryUsageBytes: [1500],
      );

      final json = report.toJson();

      expect(json['measurementStartedAt'], '2024-01-01T12:00:00.000');
      expect(json['measurementStoppedAt'], '2024-01-01T12:00:01.000');
      expect(json['elapsed'], 1000000);
      expect(json['memoryUsageBeforeMeasurementBytes'], 1000);
      expect(json['memoryUsageAfterMeasurementBytes'], 2000);
      expect(json['memoryUsageBytes'], [1500]);
    });

    test('should convert to JSON with zero values', () {
      final report = PerformanceReport(
        measurementStartedAt: DateTime(2024, 1, 1, 12, 0),
        measurementStoppedAt: DateTime(2024, 1, 1, 12, 0, 1),
        elapsed: Duration.zero,
        memoryUsageBeforeMeasurementBytes: 0,
        memoryUsageAfterMeasurementBytes: 0,
        memoryUsageBytes: const [],
      );

      final json = report.toJson();

      expect(json['measurementStartedAt'], '2024-01-01T12:00:00.000');
      expect(json['measurementStoppedAt'], '2024-01-01T12:00:01.000');
      expect(json['elapsed'], 0);
      expect(json['memoryUsageBeforeMeasurementBytes'], 0);
      expect(json['memoryUsageAfterMeasurementBytes'], 0);
      expect(json['memoryUsageBytes'], isEmpty);
    });
  });
}
