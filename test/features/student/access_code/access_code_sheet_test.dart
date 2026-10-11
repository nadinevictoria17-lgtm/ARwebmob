import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ar_science_explorer/core/models/student_record.dart';
import 'package:ar_science_explorer/core/services/access_code_service.dart';
import 'package:ar_science_explorer/core/services/quiz_attempt_service.dart';
import 'package:ar_science_explorer/core/services/student_repository.dart';
import 'package:ar_science_explorer/core/theme/app_theme.dart';
import 'package:ar_science_explorer/features/student/access_code/access_code_sheet.dart';

StudentRecord _blankStudent(String id) => StudentRecord(
  id: id,
  name: 'Test Student',
  studentId: id,
  grade: '7',
  section: 'Rizal',
  scores: const {'chemistry': null, 'biology': null, 'physics': null},
  completedLessonIds: const [],
  completedLabExperimentIds: const [],
  completedQuizIds: const [],
  unlockedLessonIds: const [],
  unlockedQuizIds: const [],
  quizAttempts: const [],
);

void main() {
  testWidgets(
    'submitting a valid code calls AccessCodeService.redeem with the given target and shows the result',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final studentRepo = StudentRepository(firestore: firestore);
      await studentRepo.saveStudent(_blankStudent('111111'));
      await firestore.collection('unlockCodes').doc('ONELESSON').set({
        'type': 'lesson',
        'targetId': 'q2w2',
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
      });
      final accessCodeService = AccessCodeService(
        firestore: firestore,
        quizAttemptService: QuizAttemptService(firestore: firestore),
      );

      await tester.pumpWidget(
        ShadApp(
          theme: appShadTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showAccessCodeSheet(
                  context,
                  studentId: '111111',
                  accessCodeService: accessCodeService,
                  targetId: 'q2w2',
                  targetType: AccessCodeTarget.lesson,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(ShadInput), 'onelesson');
      await tester.tap(find.text('Apply Code'));
      await tester.pumpAndSettle();

      // The result message from AccessCodeService.redeem is surfaced back to
      // the student — not a silent no-op.
      expect(find.textContaining('unlocked'), findsOneWidget);

      // And redeem() actually ran with the right target: q2w2 is now
      // unlocked for this student, proving the sheet passed the exact
      // targetId/targetType through rather than a targetless redemption.
      final student = await studentRepo.getStudent('111111');
      expect(student!.unlockedLessonIds, ['q2w2']);
    },
  );

  testWidgets(
    'an invalid code echoes the exact code typed and does not unlock anything',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final studentRepo = StudentRepository(firestore: firestore);
      await studentRepo.saveStudent(_blankStudent('111111'));
      final accessCodeService = AccessCodeService(
        firestore: firestore,
        quizAttemptService: QuizAttemptService(firestore: firestore),
      );

      await tester.pumpWidget(
        ShadApp(
          theme: appShadTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showAccessCodeSheet(
                  context,
                  studentId: '111111',
                  accessCodeService: accessCodeService,
                  targetId: 'q2w2',
                  targetType: AccessCodeTarget.lesson,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(ShadInput), 'bogus');
      await tester.tap(find.text('Apply Code'));
      await tester.pumpAndSettle();

      expect(find.textContaining('"BOGUS"'), findsOneWidget);

      final student = await studentRepo.getStudent('111111');
      expect(student!.unlockedLessonIds, isEmpty);
    },
  );
}
