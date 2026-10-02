import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/services/t_test_calculator.dart';
import '../widgets/error_state.dart';
import 'reports_providers.dart';

const _kCompactBreakpoint = 720.0;

/// Reports tab (teacher_shell.dart rail) — pre-test vs. post-test score
/// comparison for a chosen lesson, plus a paired t-test so a teacher can
/// state whether the improvement is statistically significant, not just
/// "the average went up."
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncViewModel = ref.watch(reportsViewModelProvider);
    final isCompact = MediaQuery.sizeOf(context).width < _kCompactBreakpoint;

    return Scaffold(
      body: Padding(
        padding: EdgeInsets.all(isCompact ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Reports',
              style: ShadTheme.of(context).textTheme.h2,
            ).animate().fadeIn(duration: 220.ms),
            const SizedBox(height: 4),
            Text(
              'Pre-test vs. post-test performance, with statistical '
              'significance.',
              style: ShadTheme.of(context).textTheme.muted,
            ).animate().fadeIn(duration: 220.ms, delay: 40.ms),
            const SizedBox(height: 20),
            Expanded(
              child: asyncViewModel.when(
                loading: () => const _ReportsSkeleton(),
                error: (error, stack) => ErrorState(
                  message: humanizeLoadError(error, subjectLabel: 'reports'),
                  onRetry: () => ref.invalidate(reportsViewModelProvider),
                ),
                data: (vm) {
                  if (vm.lessons.isEmpty) {
                    return const _NoEligibleLessonsState();
                  }
                  return ListView(
                    children: [
                      _LessonPicker(
                        lessons: vm.lessons,
                        selectedLessonId: vm.selectedLessonId,
                        onSelected: (id) => ref
                            .read(reportsSelectedLessonProvider.notifier)
                            .state = id,
                      ),
                      const SizedBox(height: 20),
                      if (vm.tTestResult == null)
                        _NotEnoughDataState(matchedPairs: vm.preScores.length)
                      else ...[
                        _ScoreComparisonCard(
                          preScores: vm.preScores,
                          postScores: vm.postScores,
                          isCompact: isCompact,
                        ).animate().fadeIn(duration: 240.ms).slideY(
                          begin: 0.04,
                          end: 0,
                          duration: 240.ms,
                        ),
                        const SizedBox(height: 16),
                        _TTestCard(
                          result: vm.tTestResult!,
                        ).animate().fadeIn(duration: 240.ms, delay: 60.ms),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonPicker extends StatelessWidget {
  const _LessonPicker({
    required this.lessons,
    required this.selectedLessonId,
    required this.onSelected,
  });

  final List<ReportableLesson> lessons;
  final String? selectedLessonId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final selected = lessons.firstWhere(
      (l) => l.lessonId == selectedLessonId,
      orElse: () => lessons.first,
    );
    return ShadSelect<String>(
      initialValue: selected.lessonId,
      minWidth: 280,
      options: [
        for (final lesson in lessons)
          ShadOption(value: lesson.lessonId, child: Text(lesson.title)),
      ],
      selectedOptionBuilder: (context, value) => Text(
        lessons.firstWhere((l) => l.lessonId == value).title,
      ),
      onChanged: (value) {
        if (value != null) onSelected(value);
      },
    );
  }
}

class _ScoreComparisonCard extends StatelessWidget {
  const _ScoreComparisonCard({
    required this.preScores,
    required this.postScores,
    required this.isCompact,
  });

  final List<num> preScores;
  final List<num> postScores;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    final chemistryAccent = _accent(context, 'chemistry');
    final physicsAccent = _accent(context, 'physics');

    return ShadCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.barChart3, size: 18, color: scheme.mutedForeground),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Class average: pre-test vs. post-test',
                  style: ShadTheme.of(context).textTheme.h4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${preScores.length} matched '
            '${preScores.length == 1 ? 'student' : 'students'}',
            style: ShadTheme.of(
              context,
            ).textTheme.small.copyWith(color: scheme.mutedForeground),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: isCompact ? 200 : 260,
            child: BarChart(
              BarChartData(
                maxY: 100,
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: _average(preScores),
                        color: chemistryAccent,
                        width: 40,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: _average(postScores),
                        color: physicsAccent,
                        width: 40,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ],
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final label = value == 0 ? 'Pre-test' : 'Post-test';
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.mutedForeground,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 36,
                      interval: 20,
                      getTitlesWidget: (value, meta) => Text(
                        '${value.round()}%',
                        style: TextStyle(
                          fontSize: 10,
                          color: scheme.mutedForeground,
                        ),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: scheme.border, strokeWidth: 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _average(List<num> values) =>
      values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

  Color _accent(BuildContext context, String key) {
    final custom = ShadTheme.of(context).colorScheme.custom;
    return custom[key] ?? ShadTheme.of(context).colorScheme.primary;
  }
}

class _TTestCard extends StatelessWidget {
  const _TTestCard({required this.result});

  final PairedTTestResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    final significant = result.isSignificant;
    final pValue = result.pValue;

    return ShadCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.calculator,
                size: 18,
                color: scheme.mutedForeground,
              ),
              const SizedBox(width: 8),
              Text(
                'Paired t-test',
                style: ShadTheme.of(context).textTheme.h4,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 32,
            runSpacing: 12,
            children: [
              _StatColumn(label: 'n', value: '${result.sampleSize}'),
              _StatColumn(
                label: 'Mean difference',
                value:
                    '${result.meanDifference >= 0 ? '+' : ''}'
                    '${result.meanDifference.toStringAsFixed(1)} pts',
              ),
              _StatColumn(
                label: 't-statistic',
                value: result.tStatistic.toStringAsFixed(3),
              ),
              _StatColumn(
                label: 'df',
                value: '${result.degreesOfFreedom}',
              ),
              _StatColumn(
                label: 'p-value',
                value: pValue < 0.001 ? '< 0.001' : pValue.toStringAsFixed(3),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ShadBadge(
            backgroundColor: significant
                ? scheme.primary.withValues(alpha: 0.12)
                : scheme.muted,
            foregroundColor: significant
                ? scheme.primary
                : scheme.mutedForeground,
            child: Text(
              significant
                  ? 'Statistically significant improvement (p < 0.05)'
                  : 'Not yet statistically significant (p ≥ 0.05)',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: ShadTheme.of(
            context,
          ).textTheme.small.copyWith(color: scheme.mutedForeground),
        ),
        Text(value, style: ShadTheme.of(context).textTheme.h4),
      ],
    );
  }
}

class _NotEnoughDataState extends StatelessWidget {
  const _NotEnoughDataState({required this.matchedPairs});

  final int matchedPairs;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return ShadCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.muted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.lineChart,
                  size: 28,
                  color: scheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 16),
              Text('Not enough data yet', style: ShadTheme.of(context).textTheme.h4),
              const SizedBox(height: 4),
              Text(
                matchedPairs == 0
                    ? 'No students have completed both the pre-test and '
                          'post-test for this lesson yet.'
                    : 'Only $matchedPairs matched ${matchedPairs == 1 ? 'student' : 'students'} '
                          'so far — at least 2 are needed for a t-test.',
                textAlign: TextAlign.center,
                style: ShadTheme.of(
                  context,
                ).textTheme.muted.copyWith(color: scheme.mutedForeground),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }
}

class _NoEligibleLessonsState extends StatelessWidget {
  const _NoEligibleLessonsState();

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return ShadCard(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.bookOpen, size: 28, color: scheme.mutedForeground),
              const SizedBox(height: 16),
              Text(
                'No lessons with both a pre-test and post-test yet',
                style: ShadTheme.of(context).textTheme.h4,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportsSkeleton extends StatelessWidget {
  const _ReportsSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: ColoredBox(color: scheme.muted),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeIn(duration: 700.ms, begin: 0.5);
  }
}
