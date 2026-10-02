// test/features/teacher/reports/reports_screen_test.dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:ar_science_explorer/core/services/t_test_calculator.dart';
import 'package:ar_science_explorer/features/teacher/reports/reports_providers.dart';
import 'package:ar_science_explorer/features/teacher/reports/reports_screen.dart';

void main() {
  testWidgets('shows the t-test stats and significance badge', (
    tester,
  ) async {
    final result = computePairedTTest(
      preScores: [60, 70, 65, 55, 80],
      postScores: [75, 85, 70, 65, 90],
    )!;

    final vm = ReportsViewModel(
      lessons: const [
        ReportableLesson(lessonId: 'q1w1', title: 'Q1W1 · Democritus Atom'),
      ],
      selectedLessonId: 'q1w1',
      preScores: const [60, 70, 65, 55, 80],
      postScores: const [75, 85, 70, 65, 90],
      tTestResult: result,
    );

    addTearDown(tester.view.resetPhysicalSize);
    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reportsViewModelProvider.overrideWith(
            (ref) => Stream.value(vm),
          ),
        ],
        child: const ShadApp(home: ReportsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Paired t-test'), findsOneWidget);
    expect(find.textContaining('5'), findsWidgets); // sample size n
    expect(find.textContaining('Statistically significant'), findsOneWidget);
  });

  testWidgets('shows not-enough-data state with fewer than 2 pairs', (
    tester,
  ) async {
    const vm = ReportsViewModel(
      lessons: [ReportableLesson(lessonId: 'q1w1', title: 'Q1W1')],
      selectedLessonId: 'q1w1',
      preScores: [60],
      postScores: [75],
      tTestResult: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reportsViewModelProvider.overrideWith(
            (ref) => Stream.value(vm),
          ),
        ],
        child: const ShadApp(home: ReportsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Not enough data'), findsOneWidget);
  });

  testWidgets('shows empty state when no lesson has both test phases', (
    tester,
  ) async {
    const vm = ReportsViewModel(
      lessons: [],
      selectedLessonId: null,
      preScores: [],
      postScores: [],
      tTestResult: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          reportsViewModelProvider.overrideWith(
            (ref) => Stream.value(vm),
          ),
        ],
        child: const ShadApp(home: ReportsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('No lessons with both a pre-test and post-test'),
      findsOneWidget,
    );
  });
}
