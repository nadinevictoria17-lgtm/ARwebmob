import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ar_science_explorer/core/data/curriculum_data.dart';
import 'package:ar_science_explorer/core/models/quiz_attempt.dart';
import 'package:ar_science_explorer/core/models/student_record.dart';
import 'package:ar_science_explorer/core/models/subject_key.dart';
import 'package:ar_science_explorer/core/services/lesson_repository.dart';
import 'package:ar_science_explorer/core/services/student_repository.dart';
import 'package:ar_science_explorer/core/theme/app_theme.dart';
import 'package:ar_science_explorer/features/student/progress/progress_providers.dart';
import 'package:ar_science_explorer/features/student/progress/progress_screen.dart';

StudentRecord _sampleStudent({required List<QuizAttempt> quizAttempts}) =>
    StudentRecord(
      id: '123456',
      studentId: '123456',
      name: 'Juan Dela Cruz',
      grade: '7',
      section: 'Rizal',
      scores: const {'chemistry': 80, 'biology': null, 'physics': null},
      completedLessonIds: const ['q1w1'],
      completedLabExperimentIds: const [],
      completedQuizIds: const [],
      unlockedLessonIds: const ['q1w1', 'q1w2'],
      unlockedQuizIds: const [],
      quizAttempts: quizAttempts,
    );

void main() {
  testWidgets('question correctness has a text label, not just a color', (
    tester,
  ) async {
    final viewModel = ProgressViewModel(
      subjectSections: [
        SubjectProgressSection(
          subject: SubjectKey.chemistry,
          lessons: [
            LessonProgressRow(
              lessonId: 'q1w1',
              title: 'Scientific Models',
              isCompleted: true,
            ),
          ],
          quizAttempts: [
            QuizAttemptRow(
              quizId: 'builtin-q1w1-post',
              bestScore: 80,
              latestScore: 80,
              perQuestionCorrect: const [true, false, true],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressViewModelProvider.overrideWith(
            (ref) => Stream.value(viewModel),
          ),
        ],
        child: ShadApp(theme: appShadTheme, home: const ProgressScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Each chip carries its 1-based item number alongside the word, so a
    // student can see *which* question they missed rather than counting
    // chip positions. The accessibility point this test was written for
    // still holds: the state is conveyed in text, never by colour alone.
    expect(find.text('1. Correct'), findsOneWidget);
    expect(find.text('2. Incorrect'), findsOneWidget);
    expect(find.text('3. Correct'), findsOneWidget);

    // And the card states the totals outright, so neither student nor
    // teacher has to tally the chips by hand.
    expect(find.text('2 correct · 1 incorrect (out of 3)'), findsOneWidget);
  });

  group('buildProgressViewModel per-question correctness', () {
    test(
      'resolves real correctness against the built-in question bank, not a placeholder',
      () async {
        // q1w1's post-test correctIndex sequence is [0,0,0,1,0,0,1,0,3,0].
        final postQuestions = kPostTestQuestionsByLesson['q1w1']!;
        expect(postQuestions.map((q) => q.correctIndex).toList(), [
          0,
          0,
          0,
          1,
          0,
          0,
          1,
          0,
          3,
          0,
        ]);

        // Chosen answers deliberately mix right and wrong picks, so the test
        // fails if perQuestionCorrect were ever computed as all-false (the
        // brief's original placeholder) or all-true.
        const answers = [0, 1, 0, 1, 1, 0, 0, 0, 3, 1];
        const expectedCorrectness = [
          true,
          false,
          true,
          true,
          false,
          true,
          false,
          true,
          true,
          false,
        ];
        expect(expectedCorrectness.contains(true), isTrue);
        expect(expectedCorrectness.contains(false), isTrue);

        final firestore = FakeFirebaseFirestore();
        final studentRepository = StudentRepository(firestore: firestore);
        final lessonRepository = LessonRepository(firestore: firestore);

        final attempt = QuizAttempt(
          id: 'attempt-1',
          quizId: 'builtin-q1w1-post',
          studentId: '123456',
          attemptNumber: 1,
          score: 60,
          totalQuestions: 10,
          correctAnswers: 6,
          answers: answers,
          timestamp: '2026-08-20T10:00:00.000Z',
          locked: true,
        );
        await studentRepository.saveStudent(
          _sampleStudent(quizAttempts: [attempt]),
        );

        final vm = await buildProgressViewModel(
          studentId: '123456',
          lessonRepository: lessonRepository,
          studentRepository: studentRepository,
        ).first;

        final chemistrySection = vm.subjectSections.firstWhere(
          (s) => s.subject == SubjectKey.chemistry,
        );
        final quizRow = chemistrySection.quizAttempts.firstWhere(
          (a) => a.quizId == 'builtin-q1w1-post',
        );

        expect(quizRow.perQuestionCorrect, expectedCorrectness);
      },
    );

    test(
      'falls back to false (never crashes) when no matching question bank exists',
      () async {
        final firestore = FakeFirebaseFirestore();
        final studentRepository = StudentRepository(firestore: firestore);
        final lessonRepository = LessonRepository(firestore: firestore);

        // A non-builtin (teacher-authored) quiz id — quizId still contains
        // 'q1w1' so it buckets into the chemistry section via the existing
        // `contains(l.id)` matching, but parseBuiltinId reports isBuiltin:
        // false, so there is no question bank to resolve against.
        final attempt = QuizAttempt(
          id: 'attempt-2',
          quizId: 'teacher-quiz-q1w1',
          studentId: '123456',
          attemptNumber: 1,
          score: 0,
          totalQuestions: 2,
          correctAnswers: 0,
          answers: const [0, 1],
          timestamp: '2026-08-20T10:00:00.000Z',
          locked: true,
        );

        await studentRepository.saveStudent(
          _sampleStudent(quizAttempts: [attempt]),
        );

        final vm = await buildProgressViewModel(
          studentId: '123456',
          lessonRepository: lessonRepository,
          studentRepository: studentRepository,
        ).first;

        final chemistrySection = vm.subjectSections.firstWhere(
          (s) => s.subject == SubjectKey.chemistry,
        );
        final quizRow = chemistrySection.quizAttempts.firstWhere(
          (a) => a.quizId == 'teacher-quiz-q1w1',
        );

        expect(quizRow.perQuestionCorrect, [false, false]);
      },
    );
  });
}
