import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/theme/app_theme.dart';
import 'progress_providers.dart';

class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncViewModel = ref.watch(progressViewModelProvider);

    return Scaffold(
      body: asyncViewModel.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _ProgressError(error: error),
        data: (vm) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            for (var i = 0; i < vm.subjectSections.length; i++)
              _SubjectSection(
                section: vm.subjectSections[i],
                delay: (i * 60).ms,
              ),
          ],
        ),
      ),
    );
  }
}

class _ProgressError extends StatelessWidget {
  const _ProgressError({required this.error});
  final Object error;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.cloudOff, size: 40, color: scheme.mutedForeground),
            const SizedBox(height: 12),
            Text(
              "Couldn't load your progress",
              style: ShadTheme.of(context).textTheme.h4,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectSection extends StatelessWidget {
  const _SubjectSection({required this.section, required this.delay});

  final SubjectProgressSection section;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    final accent = section.subject.accentColor;
    final label =
        '${section.subject.name[0].toUpperCase()}${section.subject.name.substring(1)}';
    final completedCount = section.lessons.where((l) => l.isCompleted).length;

    return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(label, style: ShadTheme.of(context).textTheme.h4),
                  const SizedBox(width: 8),
                  if (section.lessons.isNotEmpty)
                    Text(
                      '$completedCount/${section.lessons.length}',
                      style: ShadTheme.of(context).textTheme.small.copyWith(
                        color: scheme.mutedForeground,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              if (section.lessons.isEmpty)
                ShadCard(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'No lessons in this subject yet.',
                    style: ShadTheme.of(context).textTheme.muted,
                  ),
                )
              else
                ShadCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < section.lessons.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: scheme.border),
                        _LessonRow(lesson: section.lessons[i], accent: accent),
                      ],
                    ],
                  ),
                ),
              if (section.quizAttempts.isNotEmpty) ...[
                const SizedBox(height: 10),
                for (final attempt in section.quizAttempts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _QuizAttemptCard(attempt: attempt, accent: accent),
                  ),
              ],
            ],
          ),
        )
        .animate()
        .fadeIn(duration: 260.ms, delay: delay, curve: Curves.easeOut)
        .slideY(
          begin: 0.03,
          end: 0,
          duration: 260.ms,
          delay: delay,
          curve: Curves.easeOut,
        );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({required this.lesson, required this.accent});

  final LessonProgressRow lesson;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            lesson.isCompleted ? LucideIcons.circleCheck : LucideIcons.circle,
            color: lesson.isCompleted ? AppColors.success : scheme.mutedForeground,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(lesson.title, style: ShadTheme.of(context).textTheme.p),
          ),
          lesson.isCompleted
              ? ShadBadge(
                  backgroundColor: AppColors.success.withValues(alpha: 0.12),
                  foregroundColor: AppColors.success,
                  child: const Text('Completed'),
                )
              : Text(
                  'Not yet',
                  style: ShadTheme.of(
                    context,
                  ).textTheme.small.copyWith(color: scheme.mutedForeground),
                ),
        ],
      ),
    );
  }
}

class _QuizAttemptCard extends StatelessWidget {
  const _QuizAttemptCard({required this.attempt, required this.accent});

  final QuizAttemptRow attempt;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return ShadCard(
      backgroundColor: accent.withValues(alpha: 0.05),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(attempt.quizId, style: ShadTheme.of(context).textTheme.h4),
          const SizedBox(height: 2),
          Text(
            'Best: ${attempt.bestScore}% · Latest: ${attempt.latestScore}%',
            style: ShadTheme.of(
              context,
            ).textTheme.small.copyWith(color: scheme.mutedForeground),
          ),
          const SizedBox(height: 6),
          // Running totals (client request): the per-question chips below
          // show *which* items were right, but a student/teacher scanning
          // the card had to count the chips by hand to answer "how many
          // did I get right?" — this states it outright.
          Builder(
            builder: (context) {
              final correctCount = attempt.perQuestionCorrect
                  .where((isCorrect) => isCorrect)
                  .length;
              final incorrectCount =
                  attempt.perQuestionCorrect.length - correctCount;
              return Text(
                '$correctCount correct · $incorrectCount incorrect '
                '(out of ${attempt.perQuestionCorrect.length})',
                style: ShadTheme.of(
                  context,
                ).textTheme.small.copyWith(fontWeight: FontWeight.w700),
              );
            },
          ),
          const SizedBox(height: 10),
          // Accessible per-question indicator: icon + text label together
          // (Part 10.3) — never color-only, never tooltip/hover-only.
          // Kept exactly that shape here, just colored to match its
          // meaning instead of the flat default chip. Each chip is now
          // numbered too, so "item 3 was wrong" is readable straight off
          // the card instead of counting chip positions.
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < attempt.perQuestionCorrect.length; i++)
                _QuestionChip(
                  questionNumber: i + 1,
                  correct: attempt.perQuestionCorrect[i],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuestionChip extends StatelessWidget {
  const _QuestionChip({required this.questionNumber, required this.correct});

  /// 1-based item number, shown on the chip so a student can tell *which*
  /// question each result belongs to without counting positions.
  final int questionNumber;
  final bool correct;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    final color = correct ? AppColors.success : scheme.destructive;
    return ShadBadge(
      backgroundColor: color.withValues(alpha: 0.12),
      foregroundColor: color,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(correct ? LucideIcons.check : LucideIcons.x, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            '$questionNumber. ${correct ? 'Correct' : 'Incorrect'}',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
