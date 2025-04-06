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
      expect(report.stoppedAt.isAfter(report.startedAt), isTrue);
    });

    test('should collect memory usage samples', () async {
      measure.start();
      // Allocate some memory
      final list = List<int>.filled(1000000, 0);
      await Future.delayed(const Duration(milliseconds: 50));
      measure.stop();
      final report = measure.getReport();

      expect(report.memoryUsageBytes, hasLength(greaterThanOrEqualTo(2)));
      expect(report.memoryUsageBeforeStartBytes, greaterThan(0));
      expect(report.memoryUsageAfterStoppedBytes, greaterThan(0));
      expect(report.stoppedAt.isAfter(report.startedAt), isTrue);
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
      expect(report.stoppedAt.isAfter(report.startedAt), isTrue);
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
      expect(secondReport.startedAt.isAfter(firstReport.stoppedAt), isTrue);
      expect(secondReport.elapsed, greaterThan(Duration.zero));
      expect(secondReport.stoppedAt.isAfter(secondReport.startedAt), isTrue);
    });

    test('should reset all measurements', () {
      measure.start();
      measure.stop();
      measure.reset();
      final report = measure.getReport();
      expect(report.memoryUsageBytes, isEmpty);
      expect(report.memoryUsageBeforeStartBytes, 0);
      expect(report.memoryUsageAfterStoppedBytes, 0);
      expect(report.startedAt, isNotNull);
      expect(report.stoppedAt, isNotNull);
    });

    test('should handle empty measurement period', () {
      measure.start();
      measure.stop();
      final report = measure.getReport();
      expect(report.memoryUsageBytes, hasLength(greaterThanOrEqualTo(2)));
      expect(report.memoryUsageBeforeStartBytes, greaterThan(0));
      expect(report.memoryUsageAfterStoppedBytes, greaterThan(0));
      expect(report.elapsed, greaterThan(Duration.zero));
      expect(report.stoppedAt.isAfter(report.startedAt), isTrue);
    });

    test('should convert to JSON correctly', () {
      measure.start();
      measure.stop();
      final report = measure.getReport();
      final json = report.toJson();

      expect(json['elapsed'], isA<int>());
      expect(json['memory_usage_before_start_bytes'], isA<int>());
      expect(json['memory_usage_after_stop_bytes'], isA<int>());
      expect(json['memory_usage_bytes'], isA<List<int>>());
      expect(json['started_at'], isA<String>());
      expect(json['stopped_at'], isA<String>());
      expect(
          DateTime.parse(json['stopped_at'] as String)
              .isAfter(DateTime.parse(json['started_at'] as String)),
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
        startedAt: DateTime(2024, 1, 1, 12, 0),
        stoppedAt: DateTime(2024, 1, 1, 12, 0, 1),
        elapsed: const Duration(seconds: 1),
        memoryUsageBeforeStartBytes: 1000,
        memoryUsageAfterStoppedBytes: 2000,
        memoryUsageBytes: [1000, 1500, 2000],
      );

      final json = report.toJson();

      expect(json['started_at'], '2024-01-01T12:00:00.000');
      expect(json['stopped_at'], '2024-01-01T12:00:01.000');
      expect(json['elapsed'], 1000000); // 1 second in microseconds
      expect(json['memory_usage_before_start_bytes'], 1000);
      expect(json['memory_usage_after_stop_bytes'], 2000);
      expect(json['memory_usage_bytes'], [1000, 1500, 2000]);
    });

    test('should convert to JSON with empty memory samples', () {
      final report = PerformanceReport(
        startedAt: DateTime(2024, 1, 1, 12, 0),
        stoppedAt: DateTime(2024, 1, 1, 12, 0, 1),
        elapsed: const Duration(seconds: 1),
        memoryUsageBeforeStartBytes: 1000,
        memoryUsageAfterStoppedBytes: 2000,
        memoryUsageBytes: const [],
      );

      final json = report.toJson();

      expect(json['started_at'], '2024-01-01T12:00:00.000');
      expect(json['stopped_at'], '2024-01-01T12:00:01.000');
      expect(json['elapsed'], 1000000);
      expect(json['memory_usage_before_start_bytes'], 1000);
      expect(json['memory_usage_after_stop_bytes'], 2000);
      expect(json['memory_usage_bytes'], isEmpty);
    });

    test('should convert to JSON with single memory sample', () {
      final report = PerformanceReport(
        startedAt: DateTime(2024, 1, 1, 12, 0),
        stoppedAt: DateTime(2024, 1, 1, 12, 0, 1),
        elapsed: const Duration(seconds: 1),
        memoryUsageBeforeStartBytes: 1000,
        memoryUsageAfterStoppedBytes: 2000,
        memoryUsageBytes: [1500],
      );

      final json = report.toJson();

      expect(json['started_at'], '2024-01-01T12:00:00.000');
      expect(json['stopped_at'], '2024-01-01T12:00:01.000');
      expect(json['elapsed'], 1000000);
      expect(json['memory_usage_before_start_bytes'], 1000);
      expect(json['memory_usage_after_stop_bytes'], 2000);
      expect(json['memory_usage_bytes'], [1500]);
    });

    test('should convert to JSON with zero values', () {
      final report = PerformanceReport(
        startedAt: DateTime(2024, 1, 1, 12, 0),
        stoppedAt: DateTime(2024, 1, 1, 12, 0, 1),
        elapsed: Duration.zero,
        memoryUsageBeforeStartBytes: 0,
        memoryUsageAfterStoppedBytes: 0,
        memoryUsageBytes: const [],
      );

      final json = report.toJson();

      expect(json['started_at'], '2024-01-01T12:00:00.000');
      expect(json['stopped_at'], '2024-01-01T12:00:01.000');
      expect(json['elapsed'], 0);
      expect(json['memory_usage_before_start_bytes'], 0);
      expect(json['memory_usage_after_stop_bytes'], 0);
      expect(json['memory_usage_bytes'], isEmpty);
    });

    group('toJsonMapConverter', () {
      test('should use default converter when no custom converter is provided', () {
        final report = PerformanceReport(
          startedAt: DateTime(2024, 1, 1, 12, 0),
          stoppedAt: DateTime(2024, 1, 1, 12, 0, 1),
          elapsed: const Duration(seconds: 1),
          memoryUsageBeforeStartBytes: 1000,
          memoryUsageAfterStoppedBytes: 2000,
          memoryUsageBytes: [1000, 1500, 2000],
        );

        final json = report.toJson();

        expect(json['started_at'], '2024-01-01T12:00:00.000');
        expect(json['stopped_at'], '2024-01-01T12:00:01.000');
        expect(json['elapsed'], 1000000);
        expect(json['memory_usage_before_start_bytes'], 1000);
        expect(json['memory_usage_after_stop_bytes'], 2000);
        expect(json['memory_usage_bytes'], [1000, 1500, 2000]);
      });

      test('should use custom converter when provided', () {
        customConverter(PerformanceReport report) => {
              'custom_start': report.startedAt.toIso8601String(),
              'custom_stop': report.stoppedAt.toIso8601String(),
              'custom_elapsed': report.elapsed.inMilliseconds,
              'custom_memory': {
                'before': report.memoryUsageBeforeStartBytes,
                'after': report.memoryUsageAfterStoppedBytes,
                'samples': report.memoryUsageBytes,
              },
            };

        final report = PerformanceReport(
          startedAt: DateTime(2024, 1, 1, 12, 0),
          stoppedAt: DateTime(2024, 1, 1, 12, 0, 1),
          elapsed: const Duration(seconds: 1),
          memoryUsageBeforeStartBytes: 1000,
          memoryUsageAfterStoppedBytes: 2000,
          memoryUsageBytes: [1000, 1500, 2000],
          toJsonMapConverter: customConverter,
        );

        final json = report.toJson();
        final memory = json['custom_memory'] as Map<String, dynamic>;

        expect(json['custom_start'], '2024-01-01T12:00:00.000');
        expect(json['custom_stop'], '2024-01-01T12:00:01.000');
        expect(json['custom_elapsed'], 1000);
        expect(memory['before'], 1000);
        expect(memory['after'], 2000);
        expect(memory['samples'], [1000, 1500, 2000]);
      });

      test('should handle custom converter with minimal fields', () {
        minimalConverter(PerformanceReport report) => {
              'elapsed_ms': report.elapsed.inMilliseconds,
            };

        final report = PerformanceReport(
          startedAt: DateTime(2024, 1, 1, 12, 0),
          stoppedAt: DateTime(2024, 1, 1, 12, 0, 1),
          elapsed: const Duration(seconds: 1),
          memoryUsageBeforeStartBytes: 1000,
          memoryUsageAfterStoppedBytes: 2000,
          memoryUsageBytes: [1000, 1500, 2000],
          toJsonMapConverter: minimalConverter,
        );

        final json = report.toJson();

        expect(json.length, 1);
        expect(json['elapsed_ms'], 1000);
      });

      test('should handle custom converter with transformed data', () {
        transformedConverter(PerformanceReport report) => {
              'duration': '${report.elapsed.inMilliseconds}ms',
              'memory': {
                'before': '${PerformanceReport.bytesToMb(report.memoryUsageBeforeStartBytes)}MB',
                'after': '${PerformanceReport.bytesToMb(report.memoryUsageAfterStoppedBytes)}MB',
                'max': '${PerformanceReport.bytesToMb(report.maxMemoryUsageBytes)}MB',
              },
            };

        final report = PerformanceReport(
          startedAt: DateTime(2024, 1, 1, 12, 0),
          stoppedAt: DateTime(2024, 1, 1, 12, 0, 1),
          elapsed: const Duration(seconds: 1),
          memoryUsageBeforeStartBytes: 1000000, // 1MB
          memoryUsageAfterStoppedBytes: 2000000, // 2MB
          memoryUsageBytes: [1000000, 1500000, 2000000],
          toJsonMapConverter: transformedConverter,
        );

        final json = report.toJson();
        final memory = json['memory'] as Map<String, dynamic>;

        expect(json['duration'], '1000ms');
        expect(memory['before'], '1.0MB');
        expect(memory['after'], '2.0MB');
        expect(memory['max'], '2.0MB');
      });

      test('should handle custom converter with null values', () {
        nullableConverter(PerformanceReport report) => {
              'started_at': report.startedAt.toIso8601String(),
              'stopped_at': report.stoppedAt.toIso8601String(),
              'elapsed': report.elapsed.inMicroseconds,
              'memory': null,
            };

        final report = PerformanceReport(
          startedAt: DateTime(2024, 1, 1, 12, 0),
          stoppedAt: DateTime(2024, 1, 1, 12, 0, 1),
          elapsed: const Duration(seconds: 1),
          memoryUsageBeforeStartBytes: 1000,
          memoryUsageAfterStoppedBytes: 2000,
          memoryUsageBytes: [1000, 1500, 2000],
          toJsonMapConverter: nullableConverter,
        );

        final json = report.toJson();

        expect(json['started_at'], '2024-01-01T12:00:00.000');
        expect(json['stopped_at'], '2024-01-01T12:00:01.000');
        expect(json['elapsed'], 1000000);
        expect(json['memory'], isNull);
      });
    });
  });
}
