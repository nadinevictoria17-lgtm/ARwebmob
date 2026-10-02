import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/data/curriculum_data.dart';
import '../../../core/models/quiz_phase.dart';
import '../../../core/quiz_id.dart';
import '../../../core/services/lesson_repository.dart';
import '../../../core/services/student_repository.dart';
import '../../../core/services/t_test_calculator.dart';

/// A lesson eligible for a pre/post-test report — one with at least one
/// question in both the pre-test and post-test banks (PROJECT_FLOW.md Part
/// 7.5's statistical-reporting ask has no meaning for a lesson with only
/// one phase).
class ReportableLesson {
  const ReportableLesson({required this.lessonId, required this.title});

  final String lessonId;
  final String title;
}

class ReportsViewModel {
  const ReportsViewModel({
    required this.lessons,
    required this.selectedLessonId,
    required this.preScores,
    required this.postScores,
    required this.tTestResult,
  });

  final List<ReportableLesson> lessons;

  /// Never null when [lessons] is non-empty — defaults to the first
  /// eligible lesson until the teacher picks one explicitly.
  final String? selectedLessonId;

  /// Matched pre/post scores (index-aligned, one pair per student who has
  /// attempted both phases of [selectedLessonId]).
  final List<num> preScores;
  final List<num> postScores;

  /// Null when there are fewer than 2 matched pairs — too little data for
  /// a t-test (see `computePairedTTest`).
  final PairedTTestResult? tTestResult;
}

/// Selected lesson id, set by the report screen's dropdown. Null means "no
/// explicit choice yet" — `buildReportsViewModel` falls back to the first
/// eligible lesson in that case, the same `StateProvider` + fallback
/// pattern as `studentsIncludeArchivedProvider`.
final reportsSelectedLessonProvider = StateProvider<String?>((ref) => null);

final reportsViewModelProvider = StreamProvider.autoDispose<ReportsViewModel>(
  (ref) {
    throw UnimplementedError(
      'reportsViewModelProvider must be overridden at app startup — see '
      'teacherProviderOverridesFor.',
    );
  },
);

Stream<ReportsViewModel> buildReportsViewModel({
  required LessonRepository lessonRepository,
  required StudentRepository studentRepository,
  required String? selectedLessonId,
}) async* {
  final teacherLessons = await lessonRepository.fetchTeacherLessons();
  final mergedLessons = lessonRepository.mergedLessons(teacherLessons);
  final titleById = {for (final lesson in mergedLessons) lesson.id: lesson.title};

  final eligibleIds =
      kPreTestQuestionsByLesson.entries
          .where((entry) => entry.value.isNotEmpty)
          .map((entry) => entry.key)
          .where(
            (lessonId) =>
                (kPostTestQuestionsByLesson[lessonId] ?? const []).isNotEmpty,
          )
          .toList()
        ..sort();

  final lessons = [
    for (final lessonId in eligibleIds)
      ReportableLesson(
        lessonId: lessonId,
        title: titleById[lessonId] ?? lessonId,
      ),
  ];

  final effectiveLessonId = selectedLessonId ?? (lessons.isEmpty ? null : lessons.first.lessonId);

  yield* studentRepository.watchAllStudents(includeArchived: true).map((
    students,
  ) {
    if (effectiveLessonId == null) {
      return ReportsViewModel(
        lessons: lessons,
        selectedLessonId: null,
        preScores: const [],
        postScores: const [],
        tTestResult: null,
      );
    }

    final preQuizId = builtinQuizId(effectiveLessonId, QuizPhase.pre);
    final postQuizId = builtinQuizId(effectiveLessonId, QuizPhase.post);

    final preScores = <num>[];
    final postScores = <num>[];
    for (final student in students) {
      num? preScore;
      num? postScore;
      for (final attempt in student.quizAttempts) {
        if (attempt.quizId == preQuizId) preScore = attempt.score;
        if (attempt.quizId == postQuizId) postScore = attempt.score;
      }
      if (preScore != null && postScore != null) {
        preScores.add(preScore);
        postScores.add(postScore);
      }
    }

    return ReportsViewModel(
      lessons: lessons,
      selectedLessonId: effectiveLessonId,
      preScores: preScores,
      postScores: postScores,
      tTestResult: computePairedTTest(
        preScores: preScores,
        postScores: postScores,
      ),
    );
  });
}
