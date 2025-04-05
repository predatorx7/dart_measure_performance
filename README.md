<!-- 
This README describes the package. If you publish this package to pub.dev,
this README's contents appear on the landing page for your package.

For information about how to write a good package README, see the guide for
[writing package pages](https://dart.dev/tools/pub/writing-package-pages). 

For general information about developing packages, see the Dart guide for
[creating packages](https://dart.dev/guides/libraries/create-packages)
and the Flutter guide for
[developing packages and plugins](https://flutter.dev/to/develop-packages). 
-->

# measure_performance

A Dart library for measuring and analyzing performance metrics of code execution. This package provides tools to measure execution time and memory usage of your Dart code, helping you identify performance bottlenecks and optimize your applications.

## Features

- Measure execution time with high precision
- Track memory usage before, during, and after code execution
- Calculate memory usage statistics (min, max, average)
- Support for both synchronous and asynchronous operations
- Configurable sampling frequency for memory usage tracking
- JSON export of performance metrics

## Getting started

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  measure_performance: ^1.0.0
```

Then run:

```bash
dart pub get
```

## Usage

### Basic Usage

```dart
import 'package:measure_performance/measure_performance.dart';

void main() async {
  final measure = MeasurePerformance();
  
  // Start measurement
  measure.start();
  
  // Your code to measure
  final list = List<int>.filled(1000000, 0);
  
  // Stop measurement and get report
  measure.stop();
  final report = measure.getReport();
  
  print('Elapsed time: ${report.elapsed}');
  print('Memory usage: ${PerformanceReport.bytesToMb(report.averageMemoryUsageBytes)} MB');
  
  // Clean up
  measure.dispose();
}
```

### Using the run method

For simpler usage, you can use the `run` method which handles starting and stopping automatically:

```dart
void main() async {
  final measure = MeasurePerformance();
  
  final report = await measure.run(() async {
    // Your code to measure
    final list = List<int>.filled(1000000, 0);
    await Future.delayed(const Duration(milliseconds: 100));
  });
  
  print('Performance Report:');
  print('- Elapsed time: ${report.elapsed}');
  print('- Max memory: ${PerformanceReport.bytesToMb(report.maxMemoryUsageBytes)} MB');
  print('- Min memory: ${PerformanceReport.bytesToMb(report.minMemoryUsageBytes)} MB');
  print('- Average memory: ${PerformanceReport.bytesToMb(report.averageMemoryUsageBytes)} MB');
  
  measure.dispose();
}
```

### Customizing Sampling Frequency

You can adjust how often memory usage is sampled:

```dart
final measure = MeasurePerformance(
  samplingFrequency: const Duration(milliseconds: 100), // Sample every 100ms
);
```

## Performance Report

The `PerformanceReport` class provides the following metrics:

- `elapsed`: Total execution time
- `memoryUsageBeforeMeasurementBytes`: Memory usage before measurement
- `memoryUsageAfterMeasurementBytes`: Memory usage after measurement
- `memoryUsageBytes`: List of memory usage samples
- `maxMemoryUsageBytes`: Maximum memory usage during measurement
- `minMemoryUsageBytes`: Minimum memory usage during measurement
- `averageMemoryUsageBytes`: Average memory usage during measurement

## Additional information

### Best Practices

1. Always call `dispose()` when you're done with the measurement instance
2. Use the `run` method for simpler, more reliable measurements
3. Consider increasing sampling frequency for shorter operations
4. Be aware that memory measurements may vary between runs due to garbage collection

### Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Issues and Feedback

Please file feature requests and bugs at the [issue tracker](https://github.com/yourusername/measure_performance/issues).
