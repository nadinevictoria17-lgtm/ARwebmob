import 'package:ar_science_explorer/core/services/t_test_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computePairedTTest', () {
    test('returns null with fewer than 2 matched pairs', () {
      expect(computePairedTTest(preScores: [], postScores: []), isNull);
      expect(computePairedTTest(preScores: [10], postScores: [12]), isNull);
    });

    test('computes means and mean difference correctly', () {
      final result = computePairedTTest(
        preScores: [60, 70, 65, 55, 80],
        postScores: [75, 85, 70, 65, 90],
      );
      expect(result, isNotNull);
      expect(result!.sampleSize, 5);
      expect(result.preMean, closeTo(66.0, 0.001));
      expect(result.postMean, closeTo(77.0, 0.001));
      expect(result.meanDifference, closeTo(11.0, 0.001));
      expect(result.degreesOfFreedom, 4);
    });

    test('identical pre/post scores yield zero t-statistic and p = 1', () {
      final result = computePairedTTest(
        preScores: [50, 60, 70, 80],
        postScores: [50, 60, 70, 80],
      );
      expect(result!.tStatistic, closeTo(0.0, 1e-9));
      expect(result.pValue, closeTo(1.0, 1e-6));
      expect(result.isSignificant, isFalse);
    });

    // Hand-computed reference: diffs = [-4,-2,0,2,4,-4,-2,0,2,4] (n=10) have
    // mean 6 (post - pre), sample sd sqrt(80/9) ≈ 2.9814, so
    // t = 6 / (2.9814/sqrt(10)) ≈ 6.364 — checked against that independent
    // hand calculation, not just internal consistency.
    test('t-statistic matches hand-calculated value', () {
      final pre = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0].map((e) => e.toDouble());
      final post = const [2, 4, 6, 8, 10, 2, 4, 6, 8, 10].map(
        (e) => e.toDouble(),
      );
      final result = computePairedTTest(
        preScores: pre.toList(),
        postScores: post.toList(),
      );
      expect(result!.degreesOfFreedom, 9);
      expect(result.meanDifference, closeTo(6.0, 0.001));
      expect(result.tStatistic, closeTo(6.364, 0.01));
      // A t-statistic this large at df=9 is far beyond the 0.05 critical
      // value of 2.262, so the two-tailed p-value must be small.
      expect(result.pValue, lessThan(0.001));
      expect(result.isSignificant, isTrue);
    });

    test('p-value decreases as the mean difference grows', () {
      final small = computePairedTTest(
        preScores: [50, 52, 48, 51, 49, 50],
        postScores: [51, 53, 49, 52, 50, 51],
      )!;
      final large = computePairedTTest(
        preScores: [50, 52, 48, 51, 49, 50],
        postScores: [70, 73, 69, 72, 70, 71],
      )!;
      expect(large.pValue, lessThan(small.pValue));
      expect(large.isSignificant, isTrue);
    });

    test('throws when pre/post lengths differ', () {
      expect(
        () => computePairedTTest(preScores: [1, 2], postScores: [1]),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
