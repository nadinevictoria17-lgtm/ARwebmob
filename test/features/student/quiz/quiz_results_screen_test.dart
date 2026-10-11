import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ar_science_explorer/core/services/access_code_service.dart';
import 'package:ar_science_explorer/core/services/quiz_attempt_service.dart';
import 'package:ar_science_explorer/features/student/access_code/access_code_sheet.dart';
import 'package:ar_science_explorer/features/student/quiz/quiz_results_screen.dart';

Widget _wrap(Widget child) {
  final router = GoRouter(
    initialLocation: '/results',
    routes: [
      GoRoute(path: '/results', builder: (context, state) => child),
      GoRoute(
        path: '/progress',
        builder: (context, state) => const Placeholder(),
      ),
      GoRoute(
        path: '/lesson/:lessonId',
        builder: (context, state) => const Placeholder(),
      ),
    ],
  );
  // ShadApp, not MaterialApp: QuizResultsScreen reads ShadTheme.of(context).
  return ShadApp.router(routerConfig: router);
}

void main() {
  testWidgets(
    'a failed pre-test tells the student they can retry anytime, no code needed',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const QuizResultsScreen(score: 30, isPreTest: true)),
      );
      await tester.pump();

      expect(
        find.textContaining('retry it anytime, no code needed'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Ask your teacher for a retake code'),
        findsNothing,
      );
    },
  );

  testWidgets(
    'a failed post-test tells the student to ask their teacher for a retake code',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const QuizResultsScreen(score: 30, isPreTest: false)),
      );
      await tester.pump();

      expect(
        find.textContaining('Ask your teacher for a retake code'),
        findsOneWidget,
      );
      expect(
        find.textContaining('retry it anytime, no code needed'),
        findsNothing,
      );
    },
  );

  testWidgets('a passed quiz shows no retry copy at all, regardless of phase', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const QuizResultsScreen(score: 90, isPreTest: false)),
    );
    await tester.pump();

    expect(
      find.textContaining('retry it anytime, no code needed'),
      findsNothing,
    );
    expect(
      find.textContaining('Ask your teacher for a retake code'),
      findsNothing,
    );

    // Cancel the pass-state auto-continue countdown so no Timer is left
    // pending when the test tears down.
    await tester.tap(find.textContaining('tap to stay here'));
    await tester.pump();
  });

  testWidgets(
    'a failed post-test with lessonId/studentId/accessCodeService set shows an '
    '"Enter retake code" button that opens the shared access-code sheet',
    (tester) async {
      final firestore = FakeFirebaseFirestore();
      final accessCodeService = AccessCodeService(
        firestore: firestore,
        quizAttemptService: QuizAttemptService(firestore: firestore),
      );

      await tester.pumpWidget(
        _wrap(
          QuizResultsScreen(
            score: 30,
            isPreTest: false,
            lessonId: 'q1w1',
            studentId: '111111',
            accessCodeService: accessCodeService,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Enter retake code'), findsOneWidget);

      await tester.tap(find.text('Enter retake code'));
      await tester.pumpAndSettle();

      expect(find.byType(AccessCodeSheet), findsOneWidget);
    },
  );

  testWidgets(
    'a failed post-test with no lessonId/studentId/accessCodeService shows no '
    'retake-code button (e.g. a teacher-authored quiz not resolvable to a lesson id)',
    (tester) async {
      await tester.pumpWidget(
        _wrap(const QuizResultsScreen(score: 30, isPreTest: false)),
      );
      await tester.pump();

      expect(find.text('Enter retake code'), findsNothing);
    },
  );

  testWidgets('a failed pre-test never shows the retake-code button', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final accessCodeService = AccessCodeService(
      firestore: firestore,
      quizAttemptService: QuizAttemptService(firestore: firestore),
    );

    await tester.pumpWidget(
      _wrap(
        QuizResultsScreen(
          score: 30,
          isPreTest: true,
          lessonId: 'q1w1',
          studentId: '111111',
          accessCodeService: accessCodeService,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Enter retake code'), findsNothing);
  });
}
