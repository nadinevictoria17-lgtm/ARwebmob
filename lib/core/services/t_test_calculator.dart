import 'dart:math';

/// Result of a paired-samples t-test comparing matched pre-test and
/// post-test scores (one pair per student) for a single lesson.
class PairedTTestResult {
  const PairedTTestResult({
    required this.sampleSize,
    required this.preMean,
    required this.postMean,
    required this.meanDifference,
    required this.tStatistic,
    required this.degreesOfFreedom,
    required this.pValue,
  });

  final int sampleSize;
  final double preMean;
  final double postMean;

  /// `postMean - preMean`; positive means scores improved on average.
  final double meanDifference;
  final double tStatistic;
  final int degreesOfFreedom;

  /// Two-tailed p-value.
  final double pValue;

  /// Conventional 0.05 significance threshold.
  bool get isSignificant => pValue < 0.05;
}

/// Computes a paired-samples t-test from matched pre/post score lists —
/// `preScores[i]` and `postScores[i]` must be the same student's attempts.
///
/// Returns null when there are fewer than 2 matched pairs, since a t-test
/// is undefined below that (no variance to estimate).
PairedTTestResult? computePairedTTest({
  required List<num> preScores,
  required List<num> postScores,
}) {
  if (preScores.length != postScores.length) {
    throw ArgumentError('preScores and postScores must be the same length');
  }
  final n = preScores.length;
  if (n < 2) return null;

  final diffs = [
    for (var i = 0; i < n; i++) postScores[i].toDouble() - preScores[i],
  ];
  final meanDiff = diffs.reduce((a, b) => a + b) / n;
  final variance =
      diffs.map((d) => (d - meanDiff) * (d - meanDiff)).reduce((a, b) => a + b) /
      (n - 1);
  final standardError = sqrt(variance / n);
  final tStatistic = standardError == 0 ? 0.0 : meanDiff / standardError;
  final df = n - 1;

  return PairedTTestResult(
    sampleSize: n,
    preMean: preScores.map((e) => e.toDouble()).reduce((a, b) => a + b) / n,
    postMean: postScores.map((e) => e.toDouble()).reduce((a, b) => a + b) / n,
    meanDifference: meanDiff,
    tStatistic: tStatistic,
    degreesOfFreedom: df,
    pValue: _twoTailedPValue(tStatistic.abs(), df),
  );
}

/// Two-tailed p-value for Student's t-distribution: `P(|T| > |t|)` with
/// `df` degrees of freedom, via the regularized incomplete beta function —
/// the standard closed-form relation `p = I_x(df/2, 1/2)` where
/// `x = df / (df + t^2)`.
double _twoTailedPValue(double absT, int df) {
  if (df <= 0) return 1.0;
  final x = df / (df + absT * absT);
  return _regularizedIncompleteBeta(df / 2.0, 0.5, x).clamp(0.0, 1.0);
}

/// Regularized incomplete beta function I_x(a, b), via the continued
/// fraction expansion (Numerical Recipes §6.4) — a standard, well-tested
/// algorithm, not something bespoke to this file.
double _regularizedIncompleteBeta(double a, double b, double x) {
  if (x <= 0) return 0.0;
  if (x >= 1) return 1.0;

  final logBeta =
      _logGamma(a) + _logGamma(b) - _logGamma(a + b) + a * log(x) + b * log(1 - x);
  final front = exp(logBeta);

  // The continued fraction converges faster on one side of the symmetry
  // point; swap and reflect when needed.
  if (x < (a + 1) / (a + b + 2)) {
    return front * _betaContinuedFraction(a, b, x) / a;
  } else {
    return 1.0 - front * _betaContinuedFraction(b, a, 1 - x) / b;
  }
}

double _betaContinuedFraction(double a, double b, double x) {
  const maxIterations = 200;
  const epsilon = 1e-12;
  const tiny = 1e-300;

  final qab = a + b;
  final qap = a + 1;
  final qam = a - 1;

  var c = 1.0;
  var d = 1 - qab * x / qap;
  if (d.abs() < tiny) d = tiny;
  d = 1 / d;
  var h = d;

  for (var m = 1; m <= maxIterations; m++) {
    final m2 = 2 * m;

    final aEven = m * (b - m) * x / ((qam + m2) * (a + m2));
    d = 1 + aEven * d;
    if (d.abs() < tiny) d = tiny;
    c = 1 + aEven / c;
    if (c.abs() < tiny) c = tiny;
    d = 1 / d;
    h *= d * c;

    final aOdd = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2));
    d = 1 + aOdd * d;
    if (d.abs() < tiny) d = tiny;
    c = 1 + aOdd / c;
    if (c.abs() < tiny) c = tiny;
    d = 1 / d;
    final delta = d * c;
    h *= delta;

    if ((delta - 1).abs() < epsilon) break;
  }

  return h;
}

/// Natural log of the gamma function via the Lanczos approximation —
/// standard numerical-methods boilerplate, accurate to ~15 significant
/// digits over the positive reals this file ever calls it with.
double _logGamma(double x) {
  const g = 7;
  const coefficients = [
    0.99999999999980993,
    676.5203681218851,
    -1259.1392167224028,
    771.32342877765313,
    -176.61502916214059,
    12.507343278686905,
    -0.13857109526572012,
    9.9843695780195716e-6,
    1.5056327351493116e-7,
  ];

  if (x < 0.5) {
    // Reflection formula.
    return log(pi / sin(pi * x)) - _logGamma(1 - x);
  }

  final xShifted = x - 1;
  var a = coefficients[0];
  final t = xShifted + g + 0.5;
  for (var i = 1; i < g + 2; i++) {
    a += coefficients[i] / (xShifted + i);
  }
  return 0.5 * log(2 * pi) + (xShifted + 0.5) * log(t) - t + log(a);
}
