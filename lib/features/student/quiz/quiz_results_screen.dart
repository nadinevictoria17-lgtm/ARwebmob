import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/services/access_code_service.dart';
import '../access_code/access_code_sheet.dart';

const _autoContinueSeconds = 4;

/// Part 7.4: pass shows a visibly cancelable auto-continue countdown; fail
/// never auto-redirects and states the retry rule plainly.
class QuizResultsScreen extends StatefulWidget {
  const QuizResultsScreen({
    super.key,
    required this.score,
    required this.isPreTest,
    this.lessonId,
    this.studentId,
    this.accessCodeService,
  });
  final int score;

  /// Which retry-rule copy to show on fail: pre-tests retry anytime with no
  /// code, post-tests require a teacher-issued retake code.
  final bool isPreTest;

  /// These three are only needed to show the retake-code entry button on a
  /// failed post-test — every other case (pre-test, or a pass) leaves them
  /// null. Nullable (rather than required) so this screen stays trivially
  /// constructible in tests/other call sites that don't exercise the retake
  /// path.
  final String? lessonId;
  final String? studentId;
  final AccessCodeService? accessCodeService;

  @override
  State<QuizResultsScreen> createState() => _QuizResultsScreenState();
}

class _QuizResultsScreenState extends State<QuizResultsScreen> {
  late int _secondsLeft = _passed ? _autoContinueSeconds : 0;
  Timer? _timer;
  bool get _passed => widget.score >= 50;

  @override
  void initState() {
    super.initState();
    if (_passed) _scheduleTick();
  }

  void _scheduleTick() {
    _timer = Timer(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        context.go('/progress');
        return;
      }
      setState(() => _secondsLeft -= 1);
      _scheduleTick();
    });
  }

  void _cancelAutoContinue() {
    _timer?.cancel();
    setState(() => _secondsLeft = -1);
  }

  bool get _canEnterRetakeCode =>
      widget.lessonId != null &&
      widget.studentId != null &&
      widget.accessCodeService != null;

  // Previously there was no UI anywhere in the student app for a student to
  // actually redeem a quiz-retake code — quiz_results_screen.dart told them
  // to "ask your teacher for a retake code" but gave no field to type it
  // into. Reuses the same shared `AccessCodeSheet` every other redemption
  // point (locked lesson card, Home's generic box) already goes through,
  // scoped with `AccessCodeTarget.quiz` + this lesson's id, matching how
  // `AccessCodeService.redeem`'s quiz-retake branches expect `targetId` to
  // be the lesson id (they build the actual quiz id internally via
  // `builtinQuizId`). On a successful redemption, send the student back to
  // the lesson so they can retry through the normal "Start Post-Test" flow
  // (see student router.dart's `invalidateQuizSession`) rather than trying
  // to reset this already-`isComplete` session in place.
  Future<void> _enterRetakeCode() async {
    await showAccessCodeSheet(
      context,
      studentId: widget.studentId!,
      accessCodeService: widget.accessCodeService!,
      targetId: widget.lessonId,
      targetType: AccessCodeTarget.quiz,
      title: 'Enter retake code',
    );
    if (!mounted) return;
    context.go('/lesson/${widget.lessonId}');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    final textTheme = ShadTheme.of(context).textTheme;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _passed ? LucideIcons.partyPopper : LucideIcons.refreshCcw,
                size: 48,
                color: _passed ? scheme.primary : scheme.mutedForeground,
              ),
              const SizedBox(height: 12),
              Text(
                _passed ? 'Nice work!' : 'Not quite there yet',
                style: textTheme.h2,
              ),
              const SizedBox(height: 4),
              Text('${widget.score}%', style: textTheme.h1),
              if (!_passed)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    widget.isPreTest
                        ? "This is a pre-test — you can retry it anytime, no code needed."
                        : 'Ask your teacher for a retake code to try this test again.',
                    textAlign: TextAlign.center,
                    style: textTheme.muted.copyWith(
                      color: scheme.mutedForeground,
                    ),
                  ),
                ),
              if (!_passed && !widget.isPreTest && _canEnterRetakeCode)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ShadButton.outline(
                    onPressed: _enterRetakeCode,
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.keyRound, size: 16),
                        SizedBox(width: 8),
                        Text('Enter retake code'),
                      ],
                    ),
                  ),
                ),
              ShadButton(
                onPressed: () => context.go('/progress'),
                child: const Text('View My Progress'),
              ),
              if (_passed && _secondsLeft > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ShadButton.link(
                    onPressed: _cancelAutoContinue,
                    child: Text(
                      'Continuing in $_secondsLeft s — tap to stay here',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
