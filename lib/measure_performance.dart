/// A Dart library for measuring and analyzing performance metrics of code execution.
///
/// This library provides tools to measure:
/// - Execution time (elapsed duration)
/// - Memory usage (before, during, and after execution)
/// - Memory usage statistics (min, max, average)
///
/// ## Usage
///
/// ```dart
/// final measure = MeasurePerformance();
/// // Your code to measure
/// final report = measure.stop();
/// print('Elapsed time: ${report.elapsed}');
/// print('Memory usage: ${report.averageMemoryUsageBytes} bytes');
/// ```
///
/// The library is particularly useful for:
/// - Performance testing and benchmarking
/// - Memory leak detection
/// - Optimizing critical code paths
/// - Comparing different implementations
library;

export 'src/measure_performance_base.dart';
