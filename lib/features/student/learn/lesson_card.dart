// lib/features/student/learn/lesson_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/services/access_code_service.dart';
import '../access_code/access_code_sheet.dart';
import 'learn_providers.dart';
import 'marker_viewer_screen.dart';

class LessonCard extends StatelessWidget {
  const LessonCard({
    super.key,
    required this.data,
    required this.studentId,
    required this.accessCodeService,
  });

  final LessonCardData data;
  final String studentId;
  final AccessCodeService accessCodeService;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return ShadCard(
      padding: const EdgeInsets.all(16),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () {
            if (data.isUnlocked) {
              context.push('/lesson/${data.lessonId}');
            } else {
              _showAccessCodeSheet(context);
            }
          },
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data.title, style: ShadTheme.of(context).textTheme.h4),
                    const SizedBox(height: 4),
                    if (data.week != null)
                      Text(
                        'Week ${data.week}',
                        style: ShadTheme.of(context).textTheme.small.copyWith(
                          color: scheme.mutedForeground,
                        ),
                      ),
                    Text(
                      data.summary,
                      style: ShadTheme.of(context).textTheme.muted,
                    ),
                    if (!data.isUnlocked) ...[
                      const SizedBox(height: 4),
                      Text(
                        'This lesson is not yet available.',
                        style: ShadTheme.of(context).textTheme.small,
                      ),
                      Text(
                        "Unlock with your teacher's code",
                        style: ShadTheme.of(context).textTheme.small,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!data.isUnlocked)
                Icon(LucideIcons.lock, color: scheme.mutedForeground)
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (data.markerImage != null)
                      Tooltip(
                        message: 'View & download AR marker',
                        child: ShadIconButton.ghost(
                          icon: const Icon(LucideIcons.qrCode),
                          onPressed: () => _showMarker(context),
                        ),
                      ),
                    if (data.hasPreTest)
                      ShadButton.ghost(
                        onPressed: () =>
                            context.push('/quiz/${data.lessonId}/pre'),
                        child: const Text('Pre-Test'),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMarker(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MarkerViewerScreen(
          lessonTitle: data.title,
          markerImage: data.markerImage!,
        ),
      ),
    );
  }

  void _showAccessCodeSheet(BuildContext context) {
    showAccessCodeSheet(
      context,
      studentId: studentId,
      accessCodeService: accessCodeService,
      targetId: data.lessonId,
      targetType: AccessCodeTarget.lesson,
      title: 'Enter code to unlock ${data.title}',
    );
  }
}
