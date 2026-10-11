import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ar_science_explorer/core/theme/app_theme.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:ar_science_explorer/core/models/student_record.dart';
import 'package:ar_science_explorer/core/services/access_code_service.dart';
import 'package:ar_science_explorer/core/services/lesson_repository.dart';
import 'package:ar_science_explorer/core/models/teacher_lesson.dart';
import 'package:ar_science_explorer/core/models/teacher_quiz.dart';
import 'package:ar_science_explorer/core/models/teacher_quiz_question.dart';
import 'package:ar_science_explorer/core/models/quiz_phase.dart';
import 'package:ar_science_explorer/core/models/subject_key.dart';
import 'package:ar_science_explorer/core/services/quiz_attempt_service.dart';
import 'package:ar_science_explorer/core/services/quiz_repository.dart';
import 'package:ar_science_explorer/core/services/student_repository.dart';
import 'package:ar_science_explorer/features/student/app/router.dart';
import 'package:ar_science_explorer/features/student/app/student_providers.dart';

void main() {
  testWidgets(
    'C3: /quiz/:lessonId/pre degrades gracefully for a lesson with no pre-test bank, instead of crashing',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final studentRepo = StudentRepository(firestore: firestore);
      await studentRepo.saveStudent(
        StudentRecord(
          id: '111111',
          name: 'Juan',
          studentId: '111111',
          grade: '7',
          section: 'A',
          scores: const {'chemistry': null, 'biology': null, 'physics': null},
          completedLessonIds: const [],
          completedLabExperimentIds: const [],
          completedQuizIds: const [],
          unlockedLessonIds: const [],
          unlockedQuizIds: const [],
          quizAttempts: const [],
        ),
      );
      final quizAttemptService = QuizAttemptService(firestore: firestore);
      final services = StudentServices(
        lessonRepository: LessonRepository(firestore: firestore),
        studentRepository: studentRepo,
        quizAttemptService: quizAttemptService,
        accessCodeService: AccessCodeService(
          firestore: firestore,
          quizAttemptService: quizAttemptService,
        ),
        quizRepository: QuizRepository(firestore: firestore),
      );
      final router = buildStudentRouter(services: services);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentStudentIdProvider.overrideWith(
              (ref) => Stream.value('111111'),
            ),
            ...studentProviderOverridesFor('111111', services: services),
          ],
          child: ShadApp.router(theme: appShadTheme, routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Every curriculum lesson (q1w1..q3w8) now carries a built-in pre-test
      // bank, so this case needs an id that is deliberately outside the
      // curriculum to exercise the missing-bank path.
      router.go('/quiz/q9w9/pre');
      await tester.pumpAndSettle();

      expect(find.text('Test unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'C4: /lesson/:lessonId resolves a teacher-authored lesson id without throwing',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final studentRepo = StudentRepository(firestore: firestore);
      await studentRepo.saveStudent(
        StudentRecord(
          id: '111111',
          name: 'Juan',
          studentId: '111111',
          grade: '7',
          section: 'A',
          scores: const {'chemistry': null, 'biology': null, 'physics': null},
          completedLessonIds: const [],
          completedLabExperimentIds: const [],
          completedQuizIds: const [],
          unlockedLessonIds: const [],
          unlockedQuizIds: const [],
          quizAttempts: const [],
        ),
      );
      await firestore.collection('lessons').doc('teacher-extra-1').set({
        'id': 'teacher-extra-1',
        'title': 'Extra Credit: Volcanoes',
        'subject': 'physics',
      });
      final quizAttemptService = QuizAttemptService(firestore: firestore);
      final services = StudentServices(
        lessonRepository: LessonRepository(firestore: firestore),
        studentRepository: studentRepo,
        quizAttemptService: quizAttemptService,
        accessCodeService: AccessCodeService(
          firestore: firestore,
          quizAttemptService: quizAttemptService,
        ),
        quizRepository: QuizRepository(firestore: firestore),
      );
      final router = buildStudentRouter(services: services);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentStudentIdProvider.overrideWith(
              (ref) => Stream.value('111111'),
            ),
            ...studentProviderOverridesFor('111111', services: services),
          ],
          child: ShadApp.router(theme: appShadTheme, routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      router.go('/lesson/teacher-extra-1');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Extra Credit: Volcanoes'), findsOneWidget);
    },
  );

  testWidgets(
    'a teacher lesson with linkedQuizId serves that TeacherQuiz\'s questions to a student post-test',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final studentRepo = StudentRepository(firestore: firestore);
      await studentRepo.saveStudent(
        StudentRecord(
          id: '111111',
          name: 'Juan',
          studentId: '111111',
          grade: '7',
          section: 'A',
          scores: const {'chemistry': null, 'biology': null, 'physics': null},
          completedLessonIds: const [],
          completedLabExperimentIds: const [],
          completedQuizIds: const [],
          unlockedLessonIds: const [],
          unlockedQuizIds: const [],
          quizAttempts: const [],
        ),
      );
      await firestore
          .collection('lessons')
          .doc('teacher-extra-2')
          .set(
            const TeacherLesson(
              id: 'teacher-extra-2',
              title: 'Extra Credit: Earthquakes',
              subject: SubjectKey.physics,
              linkedQuizId: 'quiz-eq-1',
            ).toJson(),
          );
      await firestore
          .collection('quizzes')
          .doc('quiz-eq-1')
          .set(
            TeacherQuiz(
              id: 'quiz-eq-1',
              title: 'Earthquakes Quiz',
              subject: SubjectKey.physics,
              createdAt: '2026-08-30T00:00:00.000Z',
              phase: QuizPhase.post,
              questions: const [
                TeacherQuizQuestion(
                  question: 'What causes most earthquakes?',
                  options: ['Tectonic plate movement', 'Rain', 'Wind', 'Tides'],
                  correctIndex: 0,
                  hint: 'Think about the Earth\'s crust.',
                ),
              ],
            ).toJson(),
          );

      final quizAttemptService = QuizAttemptService(firestore: firestore);
      final services = StudentServices(
        lessonRepository: LessonRepository(firestore: firestore),
        studentRepository: studentRepo,
        quizAttemptService: quizAttemptService,
        accessCodeService: AccessCodeService(
          firestore: firestore,
          quizAttemptService: quizAttemptService,
        ),
        quizRepository: QuizRepository(firestore: firestore),
      );
      final router = buildStudentRouter(services: services);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentStudentIdProvider.overrideWith(
              (ref) => Stream.value('111111'),
            ),
            ...studentProviderOverridesFor('111111', services: services),
          ],
          child: ShadApp.router(theme: appShadTheme, routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      router.go('/quiz/teacher-extra-2/post');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('What causes most earthquakes?'), findsOneWidget);
      expect(find.text('Test unavailable'), findsNothing);
    },
  );

  testWidgets(
    'a teacher lesson with no linkedQuizId and no built-in bank shows "Test unavailable", not a crash',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final studentRepo = StudentRepository(firestore: firestore);
      await studentRepo.saveStudent(
        StudentRecord(
          id: '111111',
          name: 'Juan',
          studentId: '111111',
          grade: '7',
          section: 'A',
          scores: const {'chemistry': null, 'biology': null, 'physics': null},
          completedLessonIds: const [],
          completedLabExperimentIds: const [],
          completedQuizIds: const [],
          unlockedLessonIds: const [],
          unlockedQuizIds: const [],
          quizAttempts: const [],
        ),
      );
      await firestore
          .collection('lessons')
          .doc('teacher-extra-3')
          .set(
            const TeacherLesson(
              id: 'teacher-extra-3',
              title: 'Extra Credit: No Quiz Here',
              subject: SubjectKey.biology,
            ).toJson(),
          );

      final quizAttemptService = QuizAttemptService(firestore: firestore);
      final services = StudentServices(
        lessonRepository: LessonRepository(firestore: firestore),
        studentRepository: studentRepo,
        quizAttemptService: quizAttemptService,
        accessCodeService: AccessCodeService(
          firestore: firestore,
          quizAttemptService: quizAttemptService,
        ),
        quizRepository: QuizRepository(firestore: firestore),
      );
      final router = buildStudentRouter(services: services);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentStudentIdProvider.overrideWith(
              (ref) => Stream.value('111111'),
            ),
            ...studentProviderOverridesFor('111111', services: services),
          ],
          child: ShadApp.router(theme: appShadTheme, routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      router.go('/quiz/teacher-extra-3/post');
      await tester.pumpAndSettle();

      expect(find.text('Test unavailable'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'REGRESSION: a built-in curriculum lesson\'s post-test still uses its built-in question bank, unaffected by linkedQuizId support',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final studentRepo = StudentRepository(firestore: firestore);
      await studentRepo.saveStudent(
        StudentRecord(
          id: '111111',
          name: 'Juan',
          studentId: '111111',
          grade: '7',
          section: 'A',
          scores: const {'chemistry': null, 'biology': null, 'physics': null},
          completedLessonIds: const [],
          completedLabExperimentIds: const [],
          completedQuizIds: const [],
          unlockedLessonIds: const [],
          unlockedQuizIds: const [],
          quizAttempts: const [],
        ),
      );
      final quizAttemptService = QuizAttemptService(firestore: firestore);
      final services = StudentServices(
        lessonRepository: LessonRepository(firestore: firestore),
        studentRepository: studentRepo,
        quizAttemptService: quizAttemptService,
        accessCodeService: AccessCodeService(
          firestore: firestore,
          quizAttemptService: quizAttemptService,
        ),
        quizRepository: QuizRepository(firestore: firestore),
      );
      final router = buildStudentRouter(services: services);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            currentStudentIdProvider.overrideWith(
              (ref) => Stream.value('111111'),
            ),
            ...studentProviderOverridesFor('111111', services: services),
          ],
          child: ShadApp.router(theme: appShadTheme, routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // q1w1 is a built-in curriculum lesson (never has linkedQuizId) with a
      // populated kPostTestQuestionsByLesson bank — its first post-test
      // question's exact text, unchanged since before this fix.
      router.go('/quiz/q1w1/post');
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text(
          'Scientists use scientific models because some objects are too small, too large, or too complex to observe directly.',
        ),
        findsOneWidget,
      );
      expect(find.text('Test unavailable'), findsNothing);
    },
  );
}
