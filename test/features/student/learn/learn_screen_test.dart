// test/features/student/learn/learn_screen_test.dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ar_science_explorer/core/models/subject_key.dart';
import 'package:ar_science_explorer/core/services/access_code_service.dart';
import 'package:ar_science_explorer/core/services/quiz_attempt_service.dart';
import 'package:ar_science_explorer/core/theme/app_theme.dart';
import 'package:ar_science_explorer/features/student/learn/learn_providers.dart';
import 'package:ar_science_explorer/features/student/learn/learn_screen.dart';

AccessCodeService _fakeAccessCodeService() {
  final firestore = FakeFirebaseFirestore();
  return AccessCodeService(
    firestore: firestore,
    quizAttemptService: QuizAttemptService(firestore: firestore),
  );
}

LearnViewModel _viewModel({
  required SubjectKey activeSubject,
  required List<LessonCardData> cards,
  ValueChanged<SubjectKey>? onSelectSubject,
}) => LearnViewModel(
  activeSubject: activeSubject,
  cards: cards,
  onSelectSubject: onSelectSubject ?? (_) {},
  studentId: '111111',
  accessCodeService: _fakeAccessCodeService(),
);

void main() {
  testWidgets(
    'locked lesson still shows its title and summary, with an unlock CTA',
    (tester) async {
      final viewModel = _viewModel(
        activeSubject: SubjectKey.chemistry,
        cards: [
          LessonCardData(
            lessonId: 'q1w5',
            title: 'Planning and Recording Scientific Investigations',
            week: 5,
            summary: 'summary text',
            isUnlocked: false,
            hasPreTest: true,
            isCompleted: false,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            learnViewModelProvider.overrideWith(
              (ref) => Stream.value(viewModel),
            ),
          ],
          child: ShadApp(theme: appShadTheme, home: const LearnScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Not fully hidden/grayed — the title and summary must still be readable.
      expect(
        find.text('Planning and Recording Scientific Investigations'),
        findsOneWidget,
      );
      expect(find.text('summary text'), findsOneWidget);
      // The punitive "locked" framing is explicitly disallowed (Part 10.2) —
      // assert the actual, non-punitive copy instead.
      expect(find.textContaining('Unlock with your teacher'), findsOneWidget);
      expect(find.textContaining('not yet available'), findsOneWidget);
    },
  );

  testWidgets('tapping a locked lesson card opens the access-code sheet (C2)', (
    tester,
  ) async {
    final viewModel = _viewModel(
      activeSubject: SubjectKey.chemistry,
      cards: [
        LessonCardData(
          lessonId: 'q1w5',
          title: 'Planning and Recording Scientific Investigations',
          week: 5,
          summary: 'summary text',
          isUnlocked: false,
          hasPreTest: true,
          isCompleted: false,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          learnViewModelProvider.overrideWith((ref) => Stream.value(viewModel)),
        ],
        child: ShadApp(theme: appShadTheme, home: const LearnScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.text('Planning and Recording Scientific Investigations'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Apply Code'), findsOneWidget);
  });

  testWidgets(
    'switching the subject tab notifies onSelectSubject with the new subject (C1)',
    (tester) async {
      SubjectKey? selected;
      final viewModel = _viewModel(
        activeSubject: SubjectKey.chemistry,
        cards: const [],
        onSelectSubject: (s) => selected = s,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            learnViewModelProvider.overrideWith(
              (ref) => Stream.value(viewModel),
            ),
          ],
          child: ShadApp(theme: appShadTheme, home: const LearnScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Biology'));
      await tester.pumpAndSettle();

      expect(selected, SubjectKey.biology);
    },
  );
}
