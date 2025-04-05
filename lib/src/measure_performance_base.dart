import 'dart:async';
import 'dart:io';

/// A report containing performance metrics for a code execution.
///
/// This class provides various memory usage statistics and timing information
/// for a measured code block.
class PerformanceReport {
  /// The date and time when the measurement started.
  final DateTime measurementStartedAt;

  /// The date and time when the measurement stopped.
  final DateTime measurementStoppedAt;

  /// The total elapsed time of the measurement.
  final Duration elapsed;

  /// Memory usage in bytes before the measurement started.
  final int memoryUsageBeforeMeasurementBytes;

  /// Memory usage in bytes after the measurement ended.
  final int memoryUsageAfterMeasurementBytes;

  /// List of memory usage samples in bytes taken during the measurement.
  final List<int> memoryUsageBytes;

  const PerformanceReport({
    required this.measurementStartedAt,
    required this.measurementStoppedAt,
    required this.elapsed,
    required this.memoryUsageBeforeMeasurementBytes,
    required this.memoryUsageAfterMeasurementBytes,
    required this.memoryUsageBytes,
  });

  /// Converts the size in bytes to megabytes.
  static double bytesToMb(num size) {
    return size / 1e+6;
  }

  /// Returns the maximum memory usage in bytes during the measurement.
  ///
  /// Returns 0 if no memory usage samples were collected.
  int get maxMemoryUsageBytes {
    if (memoryUsageBytes.isEmpty) return 0;
    return memoryUsageBytes.reduce((a, b) => a > b ? a : b);
  }

  /// Returns the minimum memory usage in bytes during the measurement.
  ///
  /// Returns 0 if no memory usage samples were collected.
  int get minMemoryUsageBytes {
    if (memoryUsageBytes.isEmpty) return 0;
    return memoryUsageBytes.reduce((a, b) => a < b ? a : b);
  }

  /// Returns the average memory usage in bytes during the measurement.
  ///
  /// Returns 0 if no memory usage samples were collected.
  int get averageMemoryUsageBytes {
    if (memoryUsageBytes.isEmpty) return 0;
    final total = memoryUsageBytes.reduce((a, b) => a + b);
    return (total / memoryUsageBytes.length).round();
  }

  /// Converts the performance report to a JSON-compatible map.
  Map<String, Object?> toJson() {
    return {
      'measurementStartedAt': measurementStartedAt.toIso8601String(),
      'measurementStoppedAt': measurementStoppedAt.toIso8601String(),
      'elapsed': elapsed.inMicroseconds,
      'memoryUsageBeforeMeasurementBytes': memoryUsageBeforeMeasurementBytes,
      'memoryUsageAfterMeasurementBytes': memoryUsageAfterMeasurementBytes,
      'memoryUsageBytes': memoryUsageBytes,
    };
  }

  @override
  String toString() {
    return 'PerformanceReport(measurementStartedAt: $measurementStartedAt, measurementStoppedAt: $measurementStoppedAt, elapsed: $elapsed, memoryUsageBeforeMeasurementBytes: $memoryUsageBeforeMeasurementBytes, memoryUsageAfterMeasurementBytes: $memoryUsageAfterMeasurementBytes, maxMemoryUsageBytes: $maxMemoryUsageBytes, minMemoryUsageBytes: $minMemoryUsageBytes, averageMemoryUsageBytes: $averageMemoryUsageBytes, memoryUsageBytes: $memoryUsageBytes)';
  }
}

/// A utility class for measuring performance metrics of code execution.
///
/// This class provides methods to measure execution time and memory usage
/// of a code block. It samples memory usage at regular intervals and provides
/// detailed statistics about the measurement.
class MeasurePerformance {
  final Stopwatch _stopwatch;
  final List<int> _memoryUsageBytes;
  final Duration samplingFrequency;
  Timer? _snapshotTimer;

  /// Creates a new performance measurement instance.
  ///
  /// [samplingFrequency] determines how often memory usage is sampled.
  /// Default is every 10 milliseconds.
  MeasurePerformance({
    this.samplingFrequency = const Duration(milliseconds: 10),
  })  : _stopwatch = Stopwatch(),
        _memoryUsageBytes = [];

  /// Returns the current memory usage of the process in bytes.
  static int getMemoryUsageInBytes() {
    return ProcessInfo.currentRss;
  }

  void _collectMemoryUsage(Timer timer) {
    final usage = getMemoryUsageInBytes();
    if (usage < 0) {
      throw StateError('Negative memory usage detected: $usage bytes');
    }
    _memoryUsageBytes.add(usage);
  }

  int _memoryUsageBeforeStartBytes = 0;
  int _memoryUsageAfterStartBytes = 0;
  DateTime _measurementStartedAt = DateTime.now();
  DateTime _measurementStoppedAt = DateTime.now();

  /// Starts the performance measurement by collecting various metrics like
  /// memory usage, elapsed time, etc.
  ///
  /// This method:
  /// - Records the initial memory usage
  /// - Starts periodic memory usage sampling
  void start() {
    if (_snapshotTimer != null) {
      throw StateError('Measurement already started');
    }
    reset();
    _measurementStartedAt = DateTime.now();
    _stopwatch.start();
    _memoryUsageBeforeStartBytes = getMemoryUsageInBytes();
    _snapshotTimer = Timer.periodic(samplingFrequency, _collectMemoryUsage);
  }

  /// Runs the given operation and returns a [PerformanceReport] containing
  /// the elapsed time and memory usage statistics.
  ///
  /// This method:
  /// - Starts the performance measurement
  /// - Executes the provided operation
  FutureOr<PerformanceReport> run(FutureOr<void> Function() operation) async {
    start();
    await operation();
    stop();
    return getReport();
  }

  /// Stops the performance measurement.
  ///
  /// This method:
  /// - Stops the timer
  /// - Records the final memory usage
  void stop() {
    _snapshotTimer?.cancel();
    _snapshotTimer = null;
    _stopwatch.stop();
    _memoryUsageAfterStartBytes = getMemoryUsageInBytes();
    _measurementStoppedAt = DateTime.now();
  }

  /// Resets the performance measurement.
  ///
  /// This method:
  /// - Stops any ongoing measurement
  /// - Clears all collected data
  /// - Resets the stopwatch
  void reset() {
    stop();
    _stopwatch.reset();
    _memoryUsageBytes.clear();
    _memoryUsageBeforeStartBytes = 0;
    _memoryUsageAfterStartBytes = 0;
    _measurementStartedAt = DateTime.now();
    _measurementStoppedAt = DateTime.now();
  }

  /// Returns a [PerformanceReport] containing all collected metrics.
  PerformanceReport getReport() {
    final List<int> measuredMemoryUsageBytes;
    if (_memoryUsageBytes.isEmpty) {
      // if no memory usage samples were collected, return the initial and final memory usage. Memory usage samples may be empty when measured for a short or synchronous operation.
      if (_memoryUsageBeforeStartBytes != 0 || _memoryUsageAfterStartBytes != 0) {
        measuredMemoryUsageBytes = [
          _memoryUsageBeforeStartBytes,
          _memoryUsageAfterStartBytes,
        ];
      } else {
        measuredMemoryUsageBytes = const [];
      }
    } else {
      measuredMemoryUsageBytes = _memoryUsageBytes;
    }
    return PerformanceReport(
      elapsed: _stopwatch.elapsed,
      memoryUsageBeforeMeasurementBytes: _memoryUsageBeforeStartBytes,
      memoryUsageAfterMeasurementBytes: _memoryUsageAfterStartBytes,
      memoryUsageBytes: List.unmodifiable(measuredMemoryUsageBytes),
      measurementStartedAt: _measurementStartedAt,
      measurementStoppedAt: _measurementStoppedAt,
    );
  }

  /// Disposes of resources used by this instance.
  ///
  /// Call this method when you're done with the instance to ensure
  /// all resources are properly released.
  void dispose() {
    reset();
  }
}
