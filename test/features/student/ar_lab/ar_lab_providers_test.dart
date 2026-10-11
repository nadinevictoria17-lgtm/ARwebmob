import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ar_science_explorer/core/models/ar_payload.dart';
import 'package:ar_science_explorer/core/models/student_record.dart';
import 'package:ar_science_explorer/core/models/subject_key.dart';
import 'package:ar_science_explorer/core/models/teacher_lesson.dart';
import 'package:ar_science_explorer/core/services/access_code_service.dart';
import 'package:ar_science_explorer/core/services/lesson_repository.dart';
import 'package:ar_science_explorer/core/services/quiz_attempt_service.dart';
import 'package:ar_science_explorer/core/services/student_repository.dart';
import 'package:ar_science_explorer/features/student/ar_lab/ar_lab_providers.dart';

StudentRecord _sampleStudent() => StudentRecord.fromJson(const {
  'id': '111111',
  'studentId': '111111',
  'name': 'Juan Dela Cruz',
  'grade': '7',
  'section': 'Rizal',
  'scores': {'chemistry': null, 'biology': null, 'physics': null},
  'completedLessonIds': <String>[],
  'completedLabExperimentIds': <String>[],
  'completedQuizIds': <String>[],
  'unlockedLessonIds': <String>[],
  'unlockedQuizIds': <String>[],
  'quizAttempts': <Map<String, dynamic>>[],
  'isArchived': false,
});

Future<ArLabViewModel> _buildViewModel(
  String lessonId, {
  FakeFirebaseFirestore? firestore,
  Set<String> postTestLessonIds = const {},
}) async {
  final fs = firestore ?? FakeFirebaseFirestore();
  final studentRepository = StudentRepository(firestore: fs);
  final lessonRepository = LessonRepository(firestore: fs);
  final quizAttemptService = QuizAttemptService(firestore: fs);
  final accessCodeService = AccessCodeService(
    firestore: fs,
    quizAttemptService: quizAttemptService,
  );
  await studentRepository.saveStudent(_sampleStudent());

  return buildArLabViewModel(
    studentId: '111111',
    lessonId: lessonId,
    lessonRepository: lessonRepository,
    studentRepository: studentRepository,
    quizAttemptService: quizAttemptService,
    accessCodeService: accessCodeService,
    preTestLessonIds: const {},
    postTestLessonIds: postTestLessonIds,
    onStartPreTest: () {},
    onStartPostTest: () {},
  ).first;
}

void main() {
  test('q1w1 has AR content with its own marker index and title', () async {
    final viewModel = await _buildViewModel('q1w1');

    expect(viewModel.hasAR, true);
    expect(viewModel.markerIndex, 0);
    expect(
      viewModel.title,
      'Scientific Models and the Particle Model of Matter',
    );
  });

  test('q1w5 has no AR content', () async {
    final viewModel = await _buildViewModel('q1w5');

    expect(viewModel.hasAR, false);
    expect(viewModel.markerIndex, isNull);
  });

  test(
    'a teacher lesson with linkedQuizId reports hasPostTest true even with no built-in bank',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('lessons')
          .doc('teacher-linked-1')
          .set(
            const TeacherLesson(
              id: 'teacher-linked-1',
              title: 'Teacher Lesson With Quiz',
              subject: SubjectKey.biology,
              linkedQuizId: 'quiz-123',
            ).toJson(),
          );

      final viewModel = await _buildViewModel(
        'teacher-linked-1',
        firestore: firestore,
      );

      expect(viewModel.hasPostTest, isTrue);
    },
  );

  test(
    'a teacher lesson with no linkedQuizId and no built-in bank reports hasPostTest false',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('lessons')
          .doc('teacher-unlinked-1')
          .set(
            const TeacherLesson(
              id: 'teacher-unlinked-1',
              title: 'Teacher Lesson Without Quiz',
              subject: SubjectKey.biology,
            ).toJson(),
          );

      final viewModel = await _buildViewModel(
        'teacher-unlinked-1',
        firestore: firestore,
      );

      expect(viewModel.hasPostTest, isFalse);
    },
  );

  test(
    'REGRESSION: a built-in lesson with a populated postTestLessonIds bank still reports hasPostTest true',
    () async {
      final viewModel = await _buildViewModel(
        'q1w1',
        postTestLessonIds: {'q1w1'},
      );

      expect(viewModel.hasPostTest, isTrue);
    },
  );

  test(
    'markerImage is populated from a teacher lesson\'s arPayload.markerImage',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('lessons')
          .doc('teacher-marker-1')
          .set(
            const TeacherLesson(
              id: 'teacher-marker-1',
              title: 'Teacher Lesson With Marker',
              subject: SubjectKey.biology,
              arPayload: ARPayload(
                modelIndex: 0,
                detectionMode: 'marker',
                anchorHint: 'Scan the lesson marker.',
                lessonSteps: ['View the 3D model'],
                markerImage:
                    'https://fake-storage.example/lessons/teacher-marker-1/marker.png',
              ),
            ).toJson(),
          );

      final viewModel = await _buildViewModel(
        'teacher-marker-1',
        firestore: firestore,
      );

      expect(
        viewModel.markerImage,
        'https://fake-storage.example/lessons/teacher-marker-1/marker.png',
      );
    },
  );

  test(
    'markerImage is null for a lesson with no marker image on file',
    () async {
      final viewModel = await _buildViewModel('q1w5');

      expect(viewModel.markerImage, isNull);
    },
  );

  test(
    'activeLessonFragment builds "Q<quarter>W<week>" from the lesson\'s curriculum placement',
    () async {
      final viewModel = await _buildViewModel('q1w1');

      expect(viewModel.quarter, 1);
      expect(viewModel.week, 1);
      expect(viewModel.activeLessonFragment, 'Q1W1');
    },
  );

  test(
    'activeLessonFragment is null for a lesson with no curriculum placement',
    () async {
      final firestore = FakeFirebaseFirestore();
      await firestore
          .collection('lessons')
          .doc('teacher-no-placement')
          .set(
            const TeacherLesson(
              id: 'teacher-no-placement',
              title: 'Teacher Lesson Without Quarter/Week',
              subject: SubjectKey.biology,
            ).toJson(),
          );

      final viewModel = await _buildViewModel(
        'teacher-no-placement',
        firestore: firestore,
      );

      expect(viewModel.quarter, isNull);
      expect(viewModel.week, isNull);
      expect(viewModel.activeLessonFragment, isNull);
    },
  );

  test(
    'onMarkerFound/onMarkerLost track the currently detected lesson',
    () async {
      final viewModel = await _buildViewModel('q1w1');

      expect(viewModel.detectedLesson, isNull);

      viewModel.onMarkerFound('DemocritusAtomQ1W1');
      expect(viewModel.detectedLesson?.id, 'q1w1');

      viewModel.onMarkerFound('NameWithNoPattern');
      expect(viewModel.detectedLesson, isNull);
    },
  );

  test(
    'onMarkerLost keeps the detected lesson so the card stays with the model',
    () async {
      final viewModel = await _buildViewModel('q1w1');

      viewModel.onMarkerFound('DemocritusAtomQ1W1');
      expect(viewModel.detectedLesson?.id, 'q1w1');

      viewModel.onMarkerLost('DemocritusAtomQ1W1');
      expect(viewModel.detectedLesson?.id, 'q1w1');
    },
  );
}
