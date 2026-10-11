import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/models/subject_key.dart';
import '../../../core/theme/app_theme.dart';
import 'learn_providers.dart';
import 'lesson_card.dart';

const _subjectOrder = [
  SubjectKey.chemistry,
  SubjectKey.biology,
  SubjectKey.physics,
  SubjectKey.earthScience,
];

class _EmptySubject extends StatelessWidget {
  const _EmptySubject({required this.subject});

  final SubjectKey subject;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: subject.accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.flaskConical,
                size: 28,
                color: subject.accentColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'No ${subject.name} lessons yet',
              style: ShadTheme.of(context).textTheme.h4,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Check back once your teacher adds some.',
              style: ShadTheme.of(context).textTheme.muted,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class LearnScreen extends ConsumerWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncViewModel = ref.watch(learnViewModelProvider);

    return asyncViewModel.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) =>
          Center(child: Text('Could not load lessons: $error')),
      data: (vm) => DefaultTabController(
        length: _subjectOrder.length,
        initialIndex: _subjectOrder.indexOf(vm.activeSubject),
        child: Column(
          children: [
            // Subject-accent tab indicator/labels — every other surface in
            // the app color-codes chemistry/biology/physics, but this tab
            // bar (the one place a student picks a subject) previously used
            // the flat default theme color for all three, missing the one
            // spot that visual language matters most.
            TabBar(
              onTap: (i) => vm.onSelectSubject(_subjectOrder[i]),
              indicatorColor: vm.activeSubject.accentColor,
              labelColor: vm.activeSubject.accentColor,
              unselectedLabelColor: ShadTheme.of(context).colorScheme.mutedForeground,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Chemistry'),
                Tab(text: 'Biology'),
                Tab(text: 'Physics'),
                Tab(text: 'Earth Science'),
              ],
            ),
            Expanded(
              child: vm.cards.isEmpty
                  ? _EmptySubject(subject: vm.activeSubject)
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (var i = 0; i < vm.cards.length; i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child:
                                LessonCard(
                                      data: vm.cards[i],
                                      studentId: vm.studentId,
                                      accessCodeService: vm.accessCodeService,
                                    )
                                    .animate()
                                    .fadeIn(
                                      duration: 220.ms,
                                      delay: (i * 30).ms,
                                    )
                                    .slideY(
                                      begin: 0.04,
                                      end: 0,
                                      duration: 220.ms,
                                      delay: (i * 30).ms,
                                    ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
