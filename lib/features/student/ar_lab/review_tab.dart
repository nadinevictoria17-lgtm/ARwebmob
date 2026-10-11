import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/services/access_code_service.dart';
import '../access_code/access_code_sheet.dart';
import 'ar_lab_providers.dart';

class ReviewTab extends StatelessWidget {
  const ReviewTab({super.key, required this.vm});

  final ArLabViewModel vm;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.partyPopper, size: 48, color: scheme.primary),
          const SizedBox(height: 12),
          Text('Lesson Complete', style: ShadTheme.of(context).textTheme.h3),
          const SizedBox(height: 24),
          ShadButton.outline(
            onPressed: vm.hasPostTest && vm.postTestEligible
                ? () {
                    vm.onStartPostTest();
                    context.push('/quiz/${vm.lessonId}/post');
                  }
                : null,
            child: Text(
              !vm.hasPostTest
                  ? 'No Post-Test for this lesson'
                  : vm.postTestEligible
                  ? 'Start Post-Test'
                  : (vm.postTestReason ?? 'Post-Test locked'),
            ),
          ),
          // A locked post-test used to be a dead end: the button above went
          // disabled reading "Ask your teacher for a retake code" with
          // nowhere to actually type one. The only retake-code entry point
          // in the whole app was the results screen shown immediately after
          // an attempt — so a student who left that screen before their
          // teacher issued the code could never take the test again. Home's
          // generic code box can't redeem retakes either: those branches of
          // AccessCodeService.redeem require targetType/targetId, which it
          // doesn't pass.
          if (vm.hasPostTest && !vm.postTestEligible) ...[
            const SizedBox(height: 8),
            ShadButton.secondary(
              key: const Key('review-tab-enter-retake-code'),
              onPressed: () => showAccessCodeSheet(
                context,
                studentId: vm.studentId,
                accessCodeService: vm.accessCodeService,
                targetId: vm.lessonId,
                targetType: AccessCodeTarget.quiz,
                title: 'Enter retake code',
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.keyRound, size: 16),
                  SizedBox(width: 8),
                  Text('Enter retake code'),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          ShadButton(
            onPressed: () => context.go('/progress'),
            child: const Text('Go to Progress'),
          ),
        ],
      ),
    );
  }
}
