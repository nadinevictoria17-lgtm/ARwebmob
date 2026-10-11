// lib/main.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'core/services/access_code_service.dart';
import 'core/services/lesson_repository.dart';
import 'core/services/quiz_attempt_service.dart';
import 'core/services/quiz_repository.dart';
import 'core/services/student_account_service.dart';
import 'core/services/student_repository.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/student_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'features/student/app/router.dart';
import 'features/student/app/student_providers.dart';
import 'features/student/auth/student_login_screen.dart';
import 'features/teacher/app/router.dart';
import 'features/teacher/app/teacher_providers.dart';
import 'features/teacher/auth/teacher_auth_providers.dart';
import 'features/teacher/auth/teacher_login_screen.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Read the teacher's saved light/dark preference before the first frame
  // so the app never flashes light-then-dark on reload — see
  // theme_mode_provider.dart.
  final initialThemeMode = await loadPersistedThemeMode();
  runApp(
    ProviderScope(
      overrides: [themeModeProvider.overrideWith((ref) => initialThemeMode)],
      child: const ArScienceExplorerApp(),
    ),
  );
}

class ArScienceExplorerApp extends StatefulWidget {
  const ArScienceExplorerApp({super.key});

  @override
  State<ArScienceExplorerApp> createState() => _ArScienceExplorerAppState();
}

class _ArScienceExplorerAppState extends State<ArScienceExplorerApp> {
  // Student branch — constructed once, the first time a signed-in student id
  // is known — not on every rebuild of the surrounding Consumer.
  String? _servicesStudentId;
  StudentServices? _studentServices;
  GoRouter? _studentRouter;

  // Teacher branch — same caching rationale as the student branch above.
  String? _servicesTeacherEmail;
  TeacherServices? _teacherServices;
  GoRouter? _teacherRouter;

  StudentServices _studentServicesFor(String studentId) {
    if (_studentServices != null && _servicesStudentId == studentId) {
      return _studentServices!;
    }
    final quizAttemptService = QuizAttemptService(
      firestore: FirebaseFirestore.instance,
    );
    final services = StudentServices(
      lessonRepository: LessonRepository(firestore: FirebaseFirestore.instance),
      studentRepository: StudentRepository(
        firestore: FirebaseFirestore.instance,
      ),
      quizAttemptService: quizAttemptService,
      accessCodeService: AccessCodeService(
        firestore: FirebaseFirestore.instance,
        quizAttemptService: quizAttemptService,
      ),
      quizRepository: QuizRepository(firestore: FirebaseFirestore.instance),
    );
    _servicesStudentId = studentId;
    _studentServices = services;
    _studentRouter = buildStudentRouter(services: services);
    return services;
  }

  TeacherServices _teacherServicesFor(String teacherEmail) {
    if (_teacherServices != null && _servicesTeacherEmail == teacherEmail) {
      return _teacherServices!;
    }
    final services = teacherServicesFromFirestore(
      FirebaseFirestore.instance,
      // Lets Add Student provision the student's Firebase Auth login with
      // the password the teacher types, without disturbing the teacher's
      // own session (see StudentAccountService).
      studentAccountService: StudentAccountService(
        studentRepository: StudentRepository(
          firestore: FirebaseFirestore.instance,
        ),
        firebaseOptions: DefaultFirebaseOptions.currentPlatform,
      ),
    );
    _servicesTeacherEmail = teacherEmail;
    _teacherServices = services;
    _teacherRouter = buildTeacherRouter(services: services);
    return services;
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Consumer(
        builder: (context, ref, _) {
          final teacherEmail = ref
              .watch(currentTeacherEmailProvider)
              .valueOrNull;
          final themeMode = ref.watch(themeModeProvider);
          if (teacherEmail == null) {
            // Single app-level themed shell: the teacher router (below)
            // isn't built until a teacher is signed in, so the sign-in gate
            // gets its own `ShadApp` instance here — but both instances
            // share the exact same `appShadTheme`/`appMaterialTheme` (and
            // now the same `themeModeProvider`-driven `themeMode`/
            // `darkTheme`), so there is one themed shell definition, not
            // two independent ones (TeacherLoginScreen no longer builds
            // its own).
            return ShadApp(
              title: 'AR Science Explorer — Teacher',
              theme: appShadTheme,
              darkTheme: appShadThemeDark,
              themeMode: themeMode,
              materialThemeBuilder: (context, theme) =>
                  themeMode == ThemeMode.dark
                  ? appMaterialThemeDark
                  : appMaterialTheme,
              home: const TeacherLoginScreen(),
            );
          }

          final services = _teacherServicesFor(teacherEmail);

          return ProviderScope(
            key: ValueKey(teacherEmail),
            overrides: teacherProviderOverridesFor(services: services),
            child: ShadApp.router(
              title: 'AR Science Explorer',
              theme: appShadTheme,
              darkTheme: appShadThemeDark,
              themeMode: themeMode,
              materialThemeBuilder: (context, theme) =>
                  themeMode == ThemeMode.dark
                  ? appMaterialThemeDark
                  : appMaterialTheme,
              routerConfig: _teacherRouter!,
            ),
          );
        },
      );
    }

    return Consumer(
      builder: (context, ref, _) {
        final studentId = ref.watch(currentStudentIdProvider).valueOrNull;
        if (studentId == null) {
          // Same reasoning as the Teacher Web sign-in gate above: the
          // student router isn't built until a student is signed in, so the
          // sign-in gate gets its own `ShadApp` instance here. Both this and
          // the signed-in branch below share the exact same
          // `appShadTheme`/`studentTheme` pair, so there is one themed shell
          // definition, not two independent ones (StudentLoginScreen no
          // longer builds its own `MaterialApp`).
          return ShadApp(
            title: 'AR Science Explorer',
            theme: appShadTheme,
            materialThemeBuilder: (context, theme) => studentTheme,
            home: const StudentLoginScreen(),
          );
        }

        final services = _studentServicesFor(studentId);

        return ProviderScope(
          key: ValueKey(studentId),
          overrides: studentProviderOverridesFor(studentId, services: services),
          child: ShadApp.router(
            title: 'AR Science Explorer',
            theme: appShadTheme,
            materialThemeBuilder: (context, theme) => studentTheme,
            routerConfig: _studentRouter!,
          ),
        );
      },
    );
  }
}
