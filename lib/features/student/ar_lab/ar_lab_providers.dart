import 'package:flutter/foundation.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../core/ar/marker_mapping.dart';
import '../../../core/data/curriculum_data.dart';
import '../../../core/quiz_id.dart';
import '../../../core/models/lesson.dart';
import '../../../core/models/quiz_phase.dart';
import '../../../core/services/access_code_service.dart';
import '../../../core/services/lesson_repository.dart';
import '../../../core/services/quiz_attempt_service.dart';
import '../../../core/services/student_repository.dart';

class ArLabViewModel extends ChangeNotifier {
  ArLabViewModel({
    required this.lessonId,
    required this.title,
    required this.summary,
    required this.hasAR,
    required this.markerIndex,
    this.markerImage,
    this.quarter,
    this.week,
    this.contentImageUrls,
    this.contentStatus,
    required this.isRead,
    required this.hasPreTest,
    required this.hasPostTest,
    required this.postTestEligible,
    required this.postTestReason,
    required this.studentId,
    required this.accessCodeService,
    required this.onMarkAsRead,
    required this.onStartPreTest,
    required this.onStartPostTest,
  });

  final String lessonId;
  final String title;
  final String summary;
  final bool hasAR;

  /// This lesson's own `arPayload?.modelIndex` — the marker the AR camera
  /// should be looking for while this lesson's lab is open. `null` when
  /// `hasAR` is false.
  final int? markerIndex;

  /// URL of the printable/reference marker image the teacher uploaded for
  /// this lesson (`arPayload.markerImage`) — shown to the student in the
  /// Scan tab's instruction overlay so they know what to point the camera
  /// at *before* the AR camera has recognized anything. `null` when the
  /// lesson has no marker image on file.
  final String? markerImage;

  /// This lesson's curriculum placement — used to build the "Q<quarter>W<week>"
  /// fragment sent to Unity (`ARSessionManager.SetActiveLesson`) so the
  /// scanner only accepts this lesson's own marker while its Scan tab is
  /// open. `null` for a lesson with no curriculum placement (e.g. some
  /// teacher-authored lessons), in which case no restriction is applied.
  final int? quarter;
  final int? week;

  /// The fragment to send Unity for the per-lesson scan restriction, or
  /// `null` when this lesson has no curriculum placement (no restriction
  /// applied — every marker scans normally, same as today).
  String? get activeLessonFragment =>
      (quarter != null && week != null) ? 'Q${quarter}W$week' : null;

  /// This lesson's uploaded slide content, if any — only ever non-null for
  /// a teacher-authored lesson whose merged [Lesson] carries these fields;
  /// a built-in curriculum lesson never sets them, so they stay null.
  final List<String>? contentImageUrls;

  /// `'processing'` while a just-uploaded PPTX is still being converted to
  /// slide images server-side, `'ready'` once [contentImageUrls] holds
  /// viewable slide images, or `null` for the legacy/no-conversion-needed
  /// case (a single already-viewable image/PDF URL) or when there's no
  /// content at all.
  final String? contentStatus;

  final bool isRead;
  final bool hasPreTest;

  /// True if a post-test is available for this lesson at all — either a
  /// built-in bank (`kPostTestQuestionsByLesson`) or a teacher-authored
  /// lesson with `linkedQuizId` set. Independent of [postTestEligible],
  /// which is about retake locking, not availability: a lesson can have a
  /// post-test that exists but is currently locked, or (this field's whole
  /// point) no post-test at all, in which case the Post-Test button must
  /// stay disabled regardless of eligibility.
  final bool hasPostTest;
  final bool postTestEligible;
  final String? postTestReason;

  final String studentId;
  final AccessCodeService accessCodeService;

  final Future<void> Function() onMarkAsRead;
  final void Function() onStartPreTest;
  final void Function() onStartPostTest;

  /// The lesson currently recognized by the AR camera, if any — distinct
  /// from [markerIndex] (this screen's own lesson), since a camera scan can
  /// detect any marker in the curriculum, not just this lesson's.
  Lesson? detectedLesson;

  void onMarkerFound(String trackableName) {
    detectedLesson = lessonForTrackableName(kBuiltInLessons, trackableName);
    notifyListeners();
  }

  /// Called when Unity loses tracking of a marker. Unity keeps the model
  /// pinned to the screen center after a scan, so the lesson stays detected
  /// (and its description card visible) until a different marker is scanned.
  void onMarkerLost(String trackableName) {}
}

final arLabViewModelProvider = StreamProvider.autoDispose
    .family<ArLabViewModel, String>((ref, lessonId) {
      throw UnimplementedError(
        'arLabViewModelProvider must be overridden at app startup with a '
        'real stream for the given lessonId.',
      );
    });

Stream<ArLabViewModel> buildArLabViewModel({
  required String studentId,
  required String lessonId,
  required LessonRepository lessonRepository,
  required StudentRepository studentRepository,
  required QuizAttemptService quizAttemptService,
  required AccessCodeService accessCodeService,
  required Set<String> preTestLessonIds,
  required Set<String> postTestLessonIds,
  required void Function() onStartPreTest,
  required void Function() onStartPostTest,
}) {
  return studentRepository.watchStudent(studentId).asyncMap((student) async {
    final teacherLessons = await lessonRepository.fetchTeacherLessons();
    final merged = lessonRepository.mergedLessons(teacherLessons);

    Lesson? lesson;
    for (final candidate in merged) {
      if (candidate.id == lessonId) {
        lesson = candidate;
        break;
      }
    }
    if (lesson == null) {
      throw StateError('Lesson "$lessonId" could not be found.');
    }

    final isRead = student?.completedLessonIds.contains(lessonId) ?? false;
    final postQuizId = builtinQuizId(lessonId, QuizPhase.post);
    final eligibility = await quizAttemptService.checkEligibility(
      studentId,
      postQuizId,
    );

    return ArLabViewModel(
      lessonId: lessonId,
      title: lesson.title,
      summary: lesson.summary,
      hasAR: lesson.hasAR,
      markerIndex: lesson.arPayload?.modelIndex,
      markerImage: lesson.arPayload?.markerImage,
      quarter: lesson.quarter,
      week: lesson.week,
      contentImageUrls: lesson.contentImageUrls,
      contentStatus: lesson.contentStatus,
      isRead: isRead,
      hasPreTest: preTestLessonIds.contains(lessonId),
      hasPostTest:
          postTestLessonIds.contains(lessonId) || lesson.linkedQuizId != null,
      postTestEligible: eligibility.canTake,
      postTestReason: eligibility.reason,
      studentId: studentId,
      accessCodeService: accessCodeService,
      onMarkAsRead: student == null
          ? () async {}
          : () => studentRepository.saveStudent(
              student.copyWith(
                completedLessonIds: {
                  ...student.completedLessonIds,
                  lessonId,
                }.toList(),
              ),
            ),
      onStartPreTest: onStartPreTest,
      onStartPostTest: onStartPostTest,
    );
  });
}
