import 'package:measure_performance/measure_performance.dart';

/// Computes the sum of reciprocals (1/n) for numbers in the given range.
///
/// Takes [start] and [end] parameters to define the range (inclusive).
/// Returns the sum of reciprocals as a double.
///
/// For example, computeReciprocalSum(1, 3) returns 1/1 + 1/2 + 1/3 = 1.833...
double computeAverageOfSumOfReciprocals(int start, int end) {
  if (start > end) {
    throw ArgumentError('Start must be less than or equal to end');
  }
  if (start <= 0) {
    throw ArgumentError('Range must contain only positive numbers');
  }

  double sum = 0.0;
  for (int i = start; i <= end; i++) {
    sum += 1 / i;
  }
  return sum / (end - start + 1);
}

void main() {
  final measure = MeasurePerformance();
  measure.start();
  computeAverageOfSumOfReciprocals(1, 100000000);
  measure.stop();
  final report = measure.getReport();
  print(
    'report: $report, diff: ${PerformanceReport.bytesToMb(report.maxMemoryUsageBytes - report.minMemoryUsageBytes)} MB',
  );
}
