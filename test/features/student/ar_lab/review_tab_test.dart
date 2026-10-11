import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ar_science_explorer/core/services/access_code_service.dart';
import 'package:ar_science_explorer/core/services/quiz_attempt_service.dart';
import 'package:ar_science_explorer/features/student/ar_lab/ar_lab_providers.dart';
import 'package:ar_science_explorer/features/student/ar_lab/review_tab.dart';

ArLabViewModel _buildViewModel({
  bool hasPostTest = true,
  required bool postTestEligible,
  String? postTestReason,
  void Function()? onStartPostTest,
}) {
  final firestore = FakeFirebaseFirestore();
  final quizAttemptService = QuizAttemptService(firestore: firestore);
  final accessCodeService = AccessCodeService(
    firestore: firestore,
    quizAttemptService: quizAttemptService,
  );

  return ArLabViewModel(
    lessonId: 'q1w1',
    title: 'Some lesson title',
    summary: 'Some lesson summary',
    hasAR: false,
    markerIndex: null,
    isRead: true,
    hasPreTest: true,
    hasPostTest: hasPostTest,
    postTestEligible: postTestEligible,
    postTestReason: postTestReason,
    studentId: '111111',
    accessCodeService: accessCodeService,
    onMarkAsRead: () async {},
    onStartPreTest: () {},
    onStartPostTest: onStartPostTest ?? () {},
  );
}

Widget _wrap(Widget child) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(body: child),
      ),
      GoRoute(
        path: '/quiz/:lessonId/:phase',
        builder: (context, state) => const Scaffold(body: Text('Quiz screen')),
      ),
      GoRoute(
        path: '/progress',
        builder: (context, state) =>
            const Scaffold(body: Text('Progress screen')),
      ),
    ],
  );
  // ShadApp, not MaterialApp: ReviewTab reads ShadTheme.of(context).
  return ShadApp.router(routerConfig: router);
}

void main() {
  testWidgets(
    'enables the Start Post-Test button and shows its label when postTestEligible is true',
    (tester) async {
      var startPostTestCalled = false;
      final vm = _buildViewModel(
        postTestEligible: true,
        onStartPostTest: () {
          startPostTestCalled = true;
        },
      );

      await tester.pumpWidget(_wrap(ReviewTab(vm: vm)));

      final buttonFinder = find.widgetWithText(
        ShadButton,
        'Start Post-Test',
      );
      expect(buttonFinder, findsOneWidget);

      final button = tester.widget<ShadButton>(buttonFinder);
      expect(button.onPressed, isNotNull);

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(startPostTestCalled, isTrue);
      expect(find.text('Quiz screen'), findsOneWidget);
    },
  );

  testWidgets(
    'disables the button and shows postTestReason when postTestEligible is false',
    (tester) async {
      const reason = 'Complete the lesson first.';
      final vm = _buildViewModel(
        postTestEligible: false,
        postTestReason: reason,
      );

      await tester.pumpWidget(_wrap(ReviewTab(vm: vm)));

      expect(find.text('Start Post-Test'), findsNothing);
      final buttonFinder = find.widgetWithText(ShadButton, reason);
      expect(buttonFinder, findsOneWidget);

      final button = tester.widget<ShadButton>(buttonFinder);
      expect(button.onPressed, isNull);
    },
  );

  testWidgets(
    'disables the button and shows "No Post-Test for this lesson" when hasPostTest is false, '
    'even though postTestEligible is true',
    (tester) async {
      final vm = _buildViewModel(hasPostTest: false, postTestEligible: true);

      await tester.pumpWidget(_wrap(ReviewTab(vm: vm)));

      expect(find.text('Start Post-Test'), findsNothing);
      final buttonFinder = find.widgetWithText(
        ShadButton,
        'No Post-Test for this lesson',
      );
      expect(buttonFinder, findsOneWidget);

      final button = tester.widget<ShadButton>(buttonFinder);
      expect(button.onPressed, isNull);
    },
  );

  testWidgets(
    'always shows a Go to Progress button that navigates to /progress',
    (tester) async {
      final vm = _buildViewModel(postTestEligible: true);

      await tester.pumpWidget(_wrap(ReviewTab(vm: vm)));

      final buttonFinder = find.widgetWithText(ShadButton, 'Go to Progress');
      expect(buttonFinder, findsOneWidget);

      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      expect(find.text('Progress screen'), findsOneWidget);
    },
  );
}
