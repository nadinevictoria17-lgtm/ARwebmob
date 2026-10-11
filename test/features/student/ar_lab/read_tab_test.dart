import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ar_science_explorer/core/services/access_code_service.dart';
import 'package:ar_science_explorer/core/services/quiz_attempt_service.dart';
import 'package:ar_science_explorer/features/student/ar_lab/ar_lab_providers.dart';
import 'package:ar_science_explorer/features/student/ar_lab/content_viewer.dart';
import 'package:ar_science_explorer/features/student/ar_lab/read_tab.dart';

ArLabViewModel _buildViewModel({
  required bool isRead,
  Future<void> Function()? onMarkAsRead,
  List<String>? contentImageUrls,
  String? contentStatus,
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
    contentImageUrls: contentImageUrls,
    contentStatus: contentStatus,
    isRead: isRead,
    hasPreTest: true,
    hasPostTest: true,
    postTestEligible: true,
    postTestReason: null,
    studentId: '111111',
    accessCodeService: accessCodeService,
    onMarkAsRead: onMarkAsRead ?? () async {},
    onStartPreTest: () {},
    onStartPostTest: () {},
  );
}

// ShadApp, not MaterialApp: ReadTab reads ShadTheme.of(context).
Widget _wrap(Widget child) => ShadApp(home: Scaffold(body: child));

void main() {
  testWidgets(
    'shows "Mark as Read" button when isRead is false and calls onMarkAsRead when tapped',
    (tester) async {
      var markAsReadCalled = false;
      final vm = _buildViewModel(
        isRead: false,
        onMarkAsRead: () async {
          markAsReadCalled = true;
        },
      );

      await tester.pumpWidget(_wrap(ReadTab(vm: vm)));

      expect(find.text(vm.title), findsOneWidget);
      expect(find.text(vm.summary), findsOneWidget);
      expect(find.widgetWithText(ShadButton, 'Mark as Read'), findsOneWidget);
      expect(find.text('Read'), findsNothing);

      await tester.tap(find.widgetWithText(ShadButton, 'Mark as Read'));
      await tester.pump();

      expect(markAsReadCalled, isTrue);
    },
  );

  testWidgets('shows "Read" chip instead of the button when isRead is true', (
    tester,
  ) async {
    final vm = _buildViewModel(isRead: true);

    await tester.pumpWidget(_wrap(ReadTab(vm: vm)));

    expect(find.text('Read'), findsOneWidget);
    expect(find.byType(ShadButton), findsNothing);
    expect(find.byType(ShadBadge), findsOneWidget);
  });

  testWidgets(
    'renders uploaded lesson content via ContentViewer when present',
    (tester) async {
      final vm = _buildViewModel(
        isRead: false,
        contentImageUrls: [
          'https://example.com/slide1.png',
          'https://example.com/slide2.png',
        ],
        contentStatus: 'ready',
      );

      await tester.pumpWidget(_wrap(ReadTab(vm: vm)));

      expect(find.byType(ContentViewer), findsOneWidget);
      expect(find.textContaining('1 / 2'), findsOneWidget);
    },
  );
}
