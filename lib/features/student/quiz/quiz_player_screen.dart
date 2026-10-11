import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/models/question_type.dart';
import '../../../core/quiz_id.dart';
import '../../../core/models/quiz_phase.dart';
import '../../../core/services/access_code_service.dart';
import 'quiz_session_controller.dart';
import 'quiz_results_screen.dart';

/// Renders whatever `QuizSessionController.state` says — all Part 7.3 rules
/// (hints, scoring, exit-submits-progress) live in the controller, tested
/// separately; this widget is presentation only.
class QuizPlayerScreen extends ConsumerWidget {
  const QuizPlayerScreen({
    super.key,
    required this.controllerProvider,
    this.studentId,
    this.accessCodeService,
  });

  final AutoDisposeStateNotifierProvider<
    QuizSessionController,
    QuizSessionState
  >
  controllerProvider;

  /// Passed straight through to `QuizResultsScreen` so a failed post-test can
  /// offer retake-code entry — see that screen's doc comment. Both null for
  /// callers/tests that don't exercise the retake path.
  final String? studentId;
  final AccessCodeService? accessCodeService;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(controllerProvider);
    final controller = ref.read(controllerProvider.notifier);
    final question = controller.currentQuestion;
    final isTrueFalse = question.type == QuestionType.tf;
    final visibleOptions = isTrueFalse
        ? question.options.sublist(0, 2)
        : question.options;
    final scheme = ShadTheme.of(context).colorScheme;

    if (state.isComplete) {
      final parsed = parseBuiltinId(controller.quizId);
      return QuizResultsScreen(
        score: state.finalScore ?? 0,
        isPreTest: parsed.phase == QuizPhase.pre,
        // Retake codes only ever apply to a failed *post*-test, and only
        // resolve to a real quiz id for a built-in lesson (see
        // AccessCodeService.redeem's quiz-retake branches, which build the
        // id via `builtinQuizId(lessonId, ...)`) — a teacher-authored quiz
        // reached via `linkedQuizId` isn't a builtin id, so `lessonId` is
        // null there and the retake button simply doesn't show.
        lessonId: parsed.phase == QuizPhase.post ? parsed.lessonId : null,
        studentId: studentId,
        accessCodeService: accessCodeService,
      );
    }

    final wasCorrect = state.selectedAnswer == question.correctIndex;

    return PopScope(
      // The hardware/gesture back button used to pop this route directly,
      // bypassing the exit confirmation entirely: the autoDispose session
      // was thrown away with every answer in it, nothing was recorded, and
      // the student got no warning. Both exits now go through the same
      // confirmation.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmExit(context, controller);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Question ${state.questionIndex + 1} of ${controller.questions.length}',
          ),
          leading: ShadIconButton.ghost(
            icon: const Icon(LucideIcons.x),
            onPressed: () => _confirmExit(context, controller),
          ),
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              child: LinearProgressIndicator(
                value: (state.questionIndex + 1) / controller.questions.length,
                minHeight: 4,
                color: scheme.primary,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      question.question,
                      style: ShadTheme.of(context).textTheme.h3,
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < visibleOptions.length; i++)
                      _AnswerOption(
                        index: i,
                        label: visibleOptions[i],
                        selected: state.selectedAnswer == i,
                        // Reveal the correct answer once the result is shown,
                        // not just the one the student picked — this is the
                        // one place the product's "never punitive at failure
                        // moments" principle actually gets tested, and a bare
                        // "Incorrect" text with no visual answer-reveal fell
                        // short of it.
                        isCorrectAnswer:
                            state.showResult && i == question.correctIndex,
                        showResult: state.showResult,
                        // Auto-advance: selecting an option immediately submits it
                        // (shows the Correct/Incorrect feedback right away, per
                        // PROJECT_FLOW.md Part 7.3's "immediate feedback... before
                        // advancing" requirement) and, after a brief pause so the
                        // feedback is actually readable, moves on by itself — no
                        // separate "Submit"/"Next" tap needed. `nextQuestion()` is a
                        // no-op on the last question (isComplete is already set by
                        // submitAnswer's persist call, which flips this screen over
                        // to QuizResultsScreen before the delay even elapses).
                        onTap: state.showResult
                            ? null
                            : () async {
                                controller.selectAnswer(i);
                                await controller.submitAnswer();
                                await Future.delayed(
                                  const Duration(milliseconds: 900),
                                );
                                if (!context.mounted) return;
                                controller.nextQuestion();
                              },
                      ),
                    if (!state.showResult)
                      ShadButton.ghost(
                        onPressed:
                            state.hintsUsed < 3 &&
                                !state.hintedQuestionIndices.contains(
                                  state.questionIndex,
                                )
                            ? controller.useHint
                            : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.lightbulb, size: 16),
                            const SizedBox(width: 8),
                            Text('Hint (${3 - state.hintsUsed} left)'),
                          ],
                        ),
                      ),
                    if (state.hintedQuestionIndices.contains(
                          state.questionIndex,
                        ) &&
                        !state.showResult)
                      Text(
                        'Hint: ${question.hint}',
                        style: ShadTheme.of(
                          context,
                        ).textTheme.muted.copyWith(color: scheme.mutedForeground),
                      ),
                    // The only feedback signal during the brief auto-advance pause
                    // (see _AnswerOption's onTap above) -- sized up so it's
                    // actually readable in the ~900ms window before the screen
                    // moves on by itself. Never a raw "Incorrect" — the correct
                    // option is already visually highlighted above, so this reads
                    // as "here's the right one" rather than a bare failure stamp.
                    if (state.showResult)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          children: [
                            Icon(
                              wasCorrect
                                  ? LucideIcons.circleCheckBig
                                  : LucideIcons.info,
                              color: wasCorrect
                                  ? scheme.primary
                                  : scheme.destructive,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              wasCorrect
                                  ? 'Correct!'
                                  : 'Not quite — here\'s the answer',
                              style: ShadTheme.of(context).textTheme.h4
                                  .copyWith(
                                    color: wasCorrect
                                        ? scheme.primary
                                        : scheme.destructive,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    // Saving state and failure recovery. Without these, a
                    // failed save on the final question left the student on a
                    // frozen screen: options disabled, no Next/Submit button
                    // (auto-advance is the only forward path), and
                    // `isComplete` never set — so the results screen never
                    // arrived and the whole attempt was lost, unrecorded.
                    if (state.isSaving)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Saving your answers...',
                              style: ShadTheme.of(context).textTheme.muted
                                  .copyWith(color: scheme.mutedForeground),
                            ),
                          ],
                        ),
                      ),
                    if (state.saveError != null && !state.isSaving)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              state.saveError!,
                              style: ShadTheme.of(
                                context,
                              ).textTheme.p.copyWith(color: scheme.destructive),
                            ),
                            const SizedBox(height: 8),
                            ShadButton(
                              key: const Key('quiz-save-retry'),
                              onPressed: controller.retrySave,
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.refreshCw, size: 16),
                                  SizedBox(width: 8),
                                  Text('Try again'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmExit(
    BuildContext context,
    QuizSessionController controller,
  ) async {
    // A post-test locks on submission and then needs a teacher-issued code
    // to reopen, so "Submit & Exit" here is far more consequential than the
    // old copy ("Going back will submit your test with your current
    // answers.") implied — a student who opened the test just to look at it
    // could tap through this dialog and end up with a locked 0% attempt.
    final isPostTest = !controller.quizId.endsWith('-pre');
    final scheme = ShadTheme.of(context).colorScheme;
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (context) => ShadDialog(
        title: const Text('Exit Test?'),
        description: Text(
          isPostTest
              ? 'Submitting now scores this test using only what you have '
                    'answered so far. You will need a code from your teacher '
                    'before you can take it again.'
              : 'Going back will submit your test with your current answers.',
        ),
        actions: [
          ShadButton.outline(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continue Quiz'),
          ),
          ShadButton(
            backgroundColor: isPostTest ? scheme.destructive : null,
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit & Exit'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final saved = await controller.submitAndExit();
    if (!context.mounted) return;
    if (saved) {
      context.pop();
      return;
    }
    // The save failed. Staying put keeps the answers in memory so the
    // student can retry from the banner on the quiz screen — popping here
    // would discard the attempt entirely, which is exactly what the old
    // unconditional `context.pop()` did.
    ShadToaster.of(context).show(
      const ShadToast.destructive(
        description: Text(
          "Couldn't save your answers — you're still in the test. Check your "
          'connection and tap Try again.',
        ),
      ),
    );
  }
}

/// Replaces the previous plain `RadioListTile` with a tappable card that can
/// also carry the result-reveal highlight (correct answer in success-green,
/// the student's own wrong pick in a soft amber, never harsh red) — a radio
/// button alone had no way to show that once `showResult` flips true.
class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.index,
    required this.label,
    required this.selected,
    required this.isCorrectAnswer,
    required this.showResult,
    required this.onTap,
  });

  final int index;
  final String label;
  final bool selected;
  final bool isCorrectAnswer;
  final bool showResult;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    Color? background;
    Color? borderColor;
    IconData? trailingIcon;
    Color? trailingColor;

    if (showResult) {
      if (isCorrectAnswer) {
        background = scheme.primary.withValues(alpha: 0.10);
        borderColor = scheme.primary;
        trailingIcon = LucideIcons.circleCheckBig;
        trailingColor = scheme.primary;
      } else if (selected) {
        background = scheme.destructive.withValues(alpha: 0.10);
        borderColor = scheme.destructive;
        trailingIcon = LucideIcons.circle;
        trailingColor = scheme.destructive;
      }
    } else if (selected) {
      background = scheme.primary.withValues(alpha: 0.08);
      borderColor = scheme.primary;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: background ?? scheme.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor ?? scheme.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(label, style: ShadTheme.of(context).textTheme.p),
                ),
                if (trailingIcon != null)
                  Icon(trailingIcon, size: 20, color: trailingColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
