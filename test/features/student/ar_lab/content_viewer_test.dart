import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ar_science_explorer/features/student/ar_lab/content_viewer.dart';

void main() {
  testWidgets('shows nothing when no content has been uploaded', (
    tester,
  ) async {
    await tester.pumpWidget(
      // ShadApp, not MaterialApp: the widget reads ShadTheme.of(context).
      const ShadApp(
        home: Scaffold(body: ContentViewer(imageUrls: null, status: null)),
      ),
    );
    expect(find.byType(ContentViewer), findsOneWidget);
    expect(find.textContaining('Processing'), findsNothing);
  });

  testWidgets('shows a processing message while status is processing', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ShadApp(
        home: Scaffold(
          body: ContentViewer(
            imageUrls: ['https://example.com/a.pptx'],
            status: 'processing',
          ),
        ),
      ),
    );
    expect(find.textContaining('Processing'), findsOneWidget);
  });

  testWidgets('shows a swipeable gallery once ready', (tester) async {
    await tester.pumpWidget(
      const ShadApp(
        home: Scaffold(
          body: ContentViewer(
            imageUrls: [
              'https://example.com/slide1.png',
              'https://example.com/slide2.png',
            ],
            status: 'ready',
          ),
        ),
      ),
    );
    expect(find.textContaining('Processing'), findsNothing);
    expect(find.textContaining('1 / 2'), findsOneWidget); // slide counter
  });

  testWidgets(
    'shows a PDF affordance instead of a broken NetworkImage for a raw PDF upload',
    (tester) async {
      // Regression test for the final whole-branch review's Fix 3: a PDF
      // upload sets contentStatus: 'ready' immediately with a single
      // non-image URL (contentImageUrls: [rawPdfUrl]) — unlike PPTX, which
      // yields multiple PNG slide URLs post-conversion. Feeding that raw PDF
      // URL into NetworkImage/PhotoViewGallery can't decode it, so students
      // saw a broken-image icon. The PhotoViewGallery (which would attempt
      // the NetworkImage decode) must not even be built for this case.
      Uri? launchedUri;

      await tester.pumpWidget(
        ShadApp(
          home: Scaffold(
            body: ContentViewer(
              imageUrls: const ['https://example.com/lesson-notes.pdf'],
              status: 'ready',
              launchUrl: (uri) async {
                launchedUri = uri;
                return true;
              },
            ),
          ),
        ),
      );

      expect(find.textContaining('Processing'), findsNothing);
      expect(find.byType(PhotoViewGallery), findsNothing);
      expect(find.text('View lesson content (PDF)'), findsOneWidget);

      await tester.tap(find.byKey(const Key('content-viewer-open-pdf')));
      await tester.pumpAndSettle();

      expect(launchedUri, Uri.parse('https://example.com/lesson-notes.pdf'));
    },
  );
}
