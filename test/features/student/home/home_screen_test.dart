import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ar_science_explorer/core/data/curriculum_data.dart';
import 'package:ar_science_explorer/core/models/quiz_attempt.dart';
import 'package:ar_science_explorer/core/theme/app_theme.dart';
import 'package:ar_science_explorer/features/student/home/home_providers.dart';
import 'package:ar_science_explorer/features/student/home/home_screen.dart';

void main() {
  testWidgets(
    'renders greeting, percent complete, and the continue-lesson card',
    (tester) async {
      final viewModel = HomeViewModel(
        studentDisplayName: 'Juan',
        currentQuarter: 1,
        currentWeek: 3,
        percentComplete: 2 / 24,
        continueLesson: kBuiltInLessons.firstWhere((l) => l.id == 'q1w3'),
        lessonsCompletedCount: 2,
        quizzesTakenCount: 3,
        lastAttempts: const <QuizAttempt>[],
        onRedeemCode: (_) async => (success: true, message: 'ok'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeViewModelProvider.overrideWith(
              (ref) => Stream.value(viewModel),
            ),
          ],
          child: ShadApp(theme: appShadTheme, home: const HomeScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Juan'), findsWidgets);
      expect(
        find.textContaining('States of Matter and Particle Arrangement'),
        findsWidgets,
      ); // q1w3's title
      expect(find.textContaining('8%'), findsWidgets); // round(2/24*100) == 8
    },
  );
}
