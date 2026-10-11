// test/integration/lesson_content_delivery_test.dart
//
// Cross-target integration coverage for PROJECT_FLOW.md Part 8 (PDF path
// only — PPTX-to-slide-image conversion is a Cloud Function, intentionally
// undeployed/out of scope per the task, so it is not exercised here).
//
// A teacher (Web target) uploads a PDF through the real
// `LessonContentUploadService` and persists the lesson doc through the
// real `LessonRepository`, mirroring `lesson_form.dart`'s own
// `_handleSubmit` logic exactly (contentStatus goes straight to 'ready' for
// a non-PPTX upload — verified by reading lesson_form.dart, see the
// `contentStatus` computation this test's setup step reproduces). A
// student (Android target) then reads that same lesson doc back through
// the real `LessonRepository.mergedLessons` and renders the real
// `ContentViewer` widget against it, over one shared
// `FakeFirebaseFirestore`.
import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ar_science_explorer/core/models/subject_key.dart';
import 'package:ar_science_explorer/core/models/teacher_lesson.dart';
import 'package:ar_science_explorer/core/services/lesson_content_upload_service.dart';
import 'package:ar_science_explorer/core/services/lesson_repository.dart';
import 'package:ar_science_explorer/features/student/ar_lab/content_viewer.dart';

/// Same fake-uploader shape already established by
/// `test/core/services/lesson_content_upload_service_test.dart` — records
/// what was uploaded and returns a deterministic fake download URL, so the
/// real `LessonContentUploadService.uploadLessonContent` path runs for
/// real, with only the actual Firebase Storage network call swapped out.
class _FakeStorageUploader implements StorageUploader {
  String? lastPath;
  Uint8List? lastBytes;

  @override
  Future<String> upload(String path, Uint8List bytes) async {
    lastPath = path;
    lastBytes = bytes;
    return 'https://fake-storage.example/$path';
  }
}

void main() {
  testWidgets('teacher uploads a PDF (contentStatus -> ready immediately, no '
      'conversion); the lesson doc round-trips through Firestore and the '
      'real student ContentViewer renders the open-PDF affordance and '
      'launches the exact uploaded URL', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final lessonRepo = LessonRepository(firestore: firestore);
    final fakeUploader = _FakeStorageUploader();
    final uploadService = LessonContentUploadService(uploader: fakeUploader);

    const lessonId = 'teacher-content-lesson-1';
    final pdfBytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46]); // "%PDF"

    // Teacher (Web target): real upload service call.
    final uploadedUrl = await uploadService.uploadLessonContent(
      lessonId: lessonId,
      fileName: 'lesson-notes.pdf',
      bytes: pdfBytes,
    );
    expect(fakeUploader.lastPath, 'lessons/$lessonId/lesson-notes.pdf');
    expect(uploadedUrl, endsWith('lesson-notes.pdf'));

    // Mirrors lesson_form.dart's `_handleSubmit` exactly: a non-PPTX
    // upload (`isConversionNeeded == false`, since the extension isn't
    // '.pptx') sets `contentStatus: 'ready'` directly, with the single
    // uploaded URL as the one-element `contentImageUrls` list — verified
    // by reading lesson_form.dart lines 127/183-188 before writing this
    // test. There is no intermediate 'processing' state for a PDF.
    const fileName = 'lesson-notes.pdf';
    final isConversionNeeded = fileName.toLowerCase().endsWith('.pptx');
    final contentStatus = isConversionNeeded ? 'processing' : 'ready';
    final contentImageUrls = [uploadedUrl];
    expect(contentStatus, 'ready');

    await lessonRepo.createLesson(
      TeacherLesson(
        id: lessonId,
        title: 'Uploaded PDF Lesson',
        subject: SubjectKey.physics,
        createdAt: DateTime(2026, 8, 1).toIso8601String(),
        contentImageUrls: contentImageUrls,
        contentStatus: contentStatus,
      ),
    );

    // Student (Android target): read the same doc back through the real
    // merge path the Learn/AR-Lab screens actually use.
    final teacherLessons = await lessonRepo.fetchTeacherLessons();
    final merged = lessonRepo.mergedLessons(teacherLessons);
    final lesson = merged.firstWhere((l) => l.id == lessonId);

    expect(lesson.contentStatus, 'ready');
    expect(lesson.contentImageUrls, [uploadedUrl]);

    // Render the real student-side ContentViewer against exactly what
    // the student-side repository read back.
    Uri? launchedUri;
    await tester.pumpWidget(
      // ShadApp, not MaterialApp: the widget reads ShadTheme.of(context).
      ShadApp(
        home: Scaffold(
          body: ContentViewer(
            imageUrls: lesson.contentImageUrls,
            status: lesson.contentStatus,
            launchUrl: (uri) async {
              launchedUri = uri;
              return true;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // A single PDF URL renders the "open externally" affordance, not a
    // slide gallery (that branch is for PPTX-derived slide images only).
    final openPdfButton = find.byKey(const Key('content-viewer-open-pdf'));
    expect(openPdfButton, findsOneWidget);
    expect(find.byType(PageView), findsNothing);

    await tester.tap(openPdfButton);
    await tester.pumpAndSettle();

    expect(launchedUri, isNotNull);
    expect(launchedUri.toString(), uploadedUrl);
  });

  testWidgets(
    'a still-processing PPTX conversion shows the processing state, not '
    'the PDF affordance or a broken gallery (regression guard: confirms '
    'the PDF-only ready path above is not accidentally the only path '
    'exercised)',
    (tester) async {
      await tester.pumpWidget(
        // ShadApp, not MaterialApp: the widget reads ShadTheme.of(context).
        const ShadApp(
          home: Scaffold(
            body: ContentViewer(
              imageUrls: ['https://fake-storage.example/lessons/x/slides.pptx'],
              status: 'processing',
            ),
          ),
        ),
      );
      // Not pumpAndSettle: the processing state renders an indeterminate
      // CircularProgressIndicator, which animates forever and would time
      // out a settle wait.
      await tester.pump();

      expect(find.textContaining('Processing'), findsOneWidget);
      expect(find.byKey(const Key('content-viewer-open-pdf')), findsNothing);
    },
  );
}
