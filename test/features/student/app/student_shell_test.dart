import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ar_science_explorer/core/services/access_code_service.dart';
import 'package:ar_science_explorer/core/services/lesson_repository.dart';
import 'package:ar_science_explorer/core/services/quiz_attempt_service.dart';
import 'package:ar_science_explorer/core/services/quiz_repository.dart';
import 'package:ar_science_explorer/core/services/student_repository.dart';
import 'package:ar_science_explorer/core/theme/app_theme.dart';
import 'package:ar_science_explorer/features/student/app/router.dart';
import 'package:ar_science_explorer/features/student/app/student_providers.dart';

void main() {
  testWidgets('student router starts on Home and can navigate to Learn', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final quizAttemptService = QuizAttemptService(firestore: firestore);
    final services = StudentServices(
      lessonRepository: LessonRepository(firestore: firestore),
      studentRepository: StudentRepository(firestore: firestore),
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
        child: ShadApp.router(theme: appShadTheme, routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Home'), findsWidgets);

    router.go('/learn');
    await tester.pumpAndSettle();
    expect(find.text('Learn'), findsWidgets);
  });
}
