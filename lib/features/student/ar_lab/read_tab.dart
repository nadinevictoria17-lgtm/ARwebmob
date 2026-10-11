import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shadcn_ui/shadcn_ui.dart';

import 'ar_lab_providers.dart';
import 'content_viewer.dart';
import 'lesson_pdf_view.dart';

class ReadTab extends StatelessWidget {
  const ReadTab({super.key, required this.vm});

  final ArLabViewModel vm;

  /// Path of the module PDF bundled for this lesson, e.g. `q1`/week `3` ->
  /// `assets/lessons/Q1W3.pdf`. Null for a lesson with no curriculum
  /// placement (teacher-authored lessons), which have no bundled module.
  String? get _bundledPdfAsset {
    final quarter = vm.quarter;
    final week = vm.week;
    if (quarter == null || week == null) return null;
    return 'assets/lessons/Q${quarter}W$week.pdf';
  }

  @override
  Widget build(BuildContext context) {
    final pdfAsset = _bundledPdfAsset;
    final scheme = ShadTheme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(vm.title, style: ShadTheme.of(context).textTheme.h3),
        const SizedBox(height: 12),
        Text(vm.summary, style: ShadTheme.of(context).textTheme.p),
        ContentViewer(imageUrls: vm.contentImageUrls, status: vm.contentStatus),
        // The lesson module itself, read in place. Every built-in lesson
        // ships a PDF under assets/lessons/ (Q1W1..Q3W8) — these were in
        // the bundle but nothing ever displayed them, so the Read tab was
        // just a title, a one-line summary and a "Mark as Read" button
        // with no actual reading material in it.
        if (pdfAsset != null) ...[
          const SizedBox(height: 20),
          FutureBuilder<bool>(
            future: _assetExists(pdfAsset),
            builder: (context, snapshot) {
              // Render nothing at all until we know the asset is really
              // there — a lesson whose PDF is missing from the bundle
              // should degrade to the old text-only Read tab, not show a
              // broken viewer.
              if (snapshot.data != true) return const SizedBox.shrink();
              return LessonPdfView(assetPath: pdfAsset);
            },
          ),
        ],
        const SizedBox(height: 24),
        if (!vm.isRead)
          ShadButton(
            onPressed: () async => vm.onMarkAsRead(),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.check, size: 16),
                SizedBox(width: 8),
                Text('Mark as Read'),
              ],
            ),
          )
        else
          ShadBadge(
            backgroundColor: scheme.primary.withValues(alpha: 0.12),
            foregroundColor: scheme.primary,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.check, size: 14),
                SizedBox(width: 4),
                Text('Read'),
              ],
            ),
          ),
      ],
    );
  }
}

Future<bool> _assetExists(String path) async {
  try {
    await rootBundle.load(path);
    return true;
  } catch (_) {
    return false;
  }
}
