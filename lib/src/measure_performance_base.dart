import 'dart:async';
import 'dart:io';

typedef PerformanceReportToJsonMapConverter = Map<String, Object?> Function(PerformanceReport);

/// A report containing performance metrics for a code execution.
///
/// This class provides various memory usage statistics and timing information
/// for a measured code block.
class PerformanceReport {
  /// The date and time when the measurement started.
  final DateTime startedAt;

  /// The date and time when the measurement stopped.
  final DateTime stoppedAt;

  /// The total elapsed time of the measurement.
  final Duration elapsed;

  /// Memory usage in bytes before the measurement started.
  final int memoryUsageBeforeStartBytes;

  /// Memory usage in bytes after the measurement ended.
  final int memoryUsageAfterStoppedBytes;

  /// List of memory usage samples in bytes taken during the measurement.
  final List<int> memoryUsageBytes;

  /// A function that converts the performance report to a JSON-compatible map.
  final PerformanceReportToJsonMapConverter? toJsonMapConverter;

  const PerformanceReport({
    required this.startedAt,
    required this.stoppedAt,
    required this.elapsed,
    required this.memoryUsageBeforeStartBytes,
    required this.memoryUsageAfterStoppedBytes,
    required this.memoryUsageBytes,
    this.toJsonMapConverter,
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

  /// Returns a new [PerformanceReport] with the specified properties.
  ///
  /// This method creates a new instance of [PerformanceReport] with the same
  /// properties as the current instance, but allows for overriding specific
  /// properties.
  ///
  /// [toJsonMapConverter] can be provided to customize the JSON conversion.
  /// If [removeToJsonMapConverter] is true, the custom converter will be removed.
  PerformanceReport copyWith({
    DateTime? startedAt,
    DateTime? stoppedAt,
    Duration? elapsed,
    int? memoryUsageBeforeStartBytes,
    int? memoryUsageAfterStoppedBytes,
    List<int>? memoryUsageBytes,
    PerformanceReportToJsonMapConverter? toJsonMapConverter,
    bool removeToJsonMapConverter = false,
  }) {
    return PerformanceReport(
      startedAt: startedAt ?? this.startedAt,
      stoppedAt: stoppedAt ?? this.stoppedAt,
      elapsed: elapsed ?? this.elapsed,
      memoryUsageBeforeStartBytes: memoryUsageBeforeStartBytes ?? this.memoryUsageBeforeStartBytes,
      memoryUsageAfterStoppedBytes: memoryUsageAfterStoppedBytes ?? this.memoryUsageAfterStoppedBytes,
      memoryUsageBytes: memoryUsageBytes ?? this.memoryUsageBytes,
      toJsonMapConverter: removeToJsonMapConverter ? null : (toJsonMapConverter ?? this.toJsonMapConverter),
    );
  }

  /// Converts the performance report to a JSON-compatible map.
  Map<String, Object?> toJson() {
    final toJsonMapConverter = this.toJsonMapConverter;
    if (toJsonMapConverter != null) {
      return toJsonMapConverter(this);
    }
    return {
      'started_at': startedAt.toIso8601String(),
      'stopped_at': stoppedAt.toIso8601String(),
      'elapsed': elapsed.inMicroseconds,
      'memory_usage_before_start_bytes': memoryUsageBeforeStartBytes,
      'memory_usage_after_stop_bytes': memoryUsageAfterStoppedBytes,
      'memory_usage_bytes': memoryUsageBytes,
    };
  }

  @override
  String toString() {
    return 'PerformanceReport(startedAt: $startedAt, stoppedAt: $stoppedAt, elapsed: $elapsed, memoryUsageBeforeStartBytes: $memoryUsageBeforeStartBytes, memoryUsageAfterStoppedBytes: $memoryUsageAfterStoppedBytes, maxMemoryUsageBytes: $maxMemoryUsageBytes, minMemoryUsageBytes: $minMemoryUsageBytes, averageMemoryUsageBytes: $averageMemoryUsageBytes, memoryUsageBytes: $memoryUsageBytes)';
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
  final PerformanceReportToJsonMapConverter? toJsonMapConverter;

  /// Creates a new performance measurement instance.
  ///
  /// [samplingFrequency] determines how often memory usage is sampled.
  /// Default is every 10 milliseconds.
  MeasurePerformance({
    this.samplingFrequency = const Duration(milliseconds: 10),
    this.toJsonMapConverter,
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
      memoryUsageBeforeStartBytes: _memoryUsageBeforeStartBytes,
      memoryUsageAfterStoppedBytes: _memoryUsageAfterStartBytes,
      memoryUsageBytes: List.unmodifiable(measuredMemoryUsageBytes),
      startedAt: _measurementStartedAt,
      stoppedAt: _measurementStoppedAt,
      toJsonMapConverter: toJsonMapConverter,
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
