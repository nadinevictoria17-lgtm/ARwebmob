import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../access/teacher_access_screen.dart';
import '../access_codes/access_codes_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../lessons/lessons_screen.dart';
import '../quizzes/item_analysis_screen.dart';
import '../quizzes/quizzes_screen.dart';
import '../reports/reports_screen.dart';
import '../students/students_screen.dart';
import 'teacher_providers.dart';
import 'teacher_shell.dart';

const _routes = [
  '/teacher/dashboard',
  '/teacher/lessons',
  '/teacher/quizzes',
  '/teacher/students',
  '/teacher/reports',
  '/teacher/access-codes',
  '/teacher/teacher-access',
];

GoRouter buildTeacherRouter({required TeacherServices services}) {
  return GoRouter(
    initialLocation: '/teacher/dashboard',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          // Item Analysis has no rail entry of its own (see teacher_shell's
          // comment) — its route nests under '/teacher/quizzes', so it
          // naturally highlights the "Quizzes" rail entry via the same
          // prefix match used for every other route.
          final index = _routes.indexWhere(
            (route) => state.matchedLocation.startsWith(route),
          );
          return TeacherShell(
            selectedIndex: index < 0 ? 0 : index,
            onDestinationSelected: (i) => context.go(_routes[i]),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/teacher/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/teacher/lessons',
            builder: (context, state) => const LessonsScreen(),
          ),
          GoRoute(
            path: '/teacher/quizzes',
            builder: (context, state) => const QuizzesScreen(),
          ),
          GoRoute(
            path: '/teacher/students',
            builder: (context, state) => const StudentsScreen(),
          ),
          GoRoute(
            path: '/teacher/reports',
            builder: (context, state) => const ReportsScreen(),
          ),
          GoRoute(
            path: '/teacher/access-codes',
            builder: (context, state) => const AccessCodesScreen(),
          ),
          GoRoute(
            path: '/teacher/teacher-access',
            builder: (context, state) => const TeacherAccessScreen(),
          ),
          GoRoute(
            path: '/teacher/quizzes/:quizId/item-analysis',
            builder: (context, state) {
              final quizId = state.pathParameters['quizId']!;
              final quizTitle = (state.extra as String?) ?? quizId;
              return ProviderScope(
                overrides: [
                  itemAnalysisOverrideFor(
                    quizId,
                    quizTitle: quizTitle,
                    services: services,
                  ),
                ],
                child: ItemAnalysisScreen(quizId: quizId, quizTitle: quizTitle),
              );
            },
          ),
        ],
      ),
    ],
  );
}
