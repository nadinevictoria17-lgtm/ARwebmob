import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ar_science_explorer/core/services/auth_service.dart';
import 'package:ar_science_explorer/core/services/student_repository.dart';
import 'package:ar_science_explorer/core/theme/app_theme.dart';
import 'package:ar_science_explorer/features/student/auth/student_auth_providers.dart';
import 'package:ar_science_explorer/features/student/auth/student_login_screen.dart';

class _TrackingAuthService extends AuthService {
  _TrackingAuthService() : super(firebaseAuth: MockFirebaseAuth());

  int signInStudentCallCount = 0;
  String? lastIdOrEmail;
  String? lastPassword;

  @override
  Future<User?> signInStudent({
    required String idOrEmail,
    required String password,
  }) async {
    signInStudentCallCount++;
    lastIdOrEmail = idOrEmail;
    lastPassword = password;
    return MockUser(uid: 'uid-student', email: '$idOrEmail@arscience.school');
  }
}

Future<void> _pumpScreen(WidgetTester tester, AuthService authService) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        studentAuthServiceProvider.overrideWithValue(authService),
        // These widget tests exercise the login form itself, not the
        // archive check, so a plain in-memory Firestore (with no students
        // in it) is enough to satisfy studentAuthViewModelProvider's
        // dependency without requiring Firebase.initializeApp().
        studentAuthRepositoryProvider.overrideWithValue(
          StudentRepository(firestore: FakeFirebaseFirestore()),
        ),
      ],
      child: ShadApp(theme: appShadTheme, home: const StudentLoginScreen()),
    ),
  );
}

void main() {
  group('StudentLoginScreen', () {
    testWidgets('formats a typed digit id live as 00-0000', (tester) async {
      await _pumpScreen(tester, _TrackingAuthService());

      await tester.enterText(find.byType(ShadInput).first, '123456');
      await tester.pump();

      expect(find.text('12-3456'), findsOneWidget);
    });

    testWidgets('accepts a literal email unformatted', (tester) async {
      await _pumpScreen(tester, _TrackingAuthService());

      await tester.enterText(
        find.byType(ShadInput).first,
        'student@arscience.school',
      );
      await tester.pump();

      expect(find.text('student@arscience.school'), findsOneWidget);
    });

    testWidgets(
      'submitting calls AuthService.signInStudent with the normalized value',
      (tester) async {
        final authService = _TrackingAuthService();
        await _pumpScreen(tester, authService);

        await tester.enterText(find.byType(ShadInput).first, '123456');
        await tester.enterText(find.byType(ShadInput).last, 'secret');
        await tester.pump();

        await tester.tap(find.widgetWithText(ShadButton, 'Sign in'));
        await tester.pumpAndSettle();

        expect(authService.signInStudentCallCount, 1);
        // The field shows the dash-formatted display value; AuthService is
        // responsible for stripping it back down to digits before building
        // the student's email (see auth_service_test.dart).
        expect(authService.lastIdOrEmail, '12-3456');
        expect(authService.lastPassword, 'secret');
      },
    );
  });
}
