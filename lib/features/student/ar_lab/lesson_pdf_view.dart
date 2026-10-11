import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Renders a lesson's bundled module PDF inline in the Read tab, plus a
/// full-screen reader for actually studying it.
///
/// Inline rather than "open externally" on purpose: handing the file off to
/// whatever PDF app the phone happens to have takes the student out of the
/// lesson (and on a school device there may be no PDF app installed at all).
/// The embedded page keeps reading, scanning, and the post-test in one flow.
class LessonPdfView extends StatefulWidget {
  const LessonPdfView({super.key, required this.assetPath});

  final String assetPath;

  @override
  State<LessonPdfView> createState() => _LessonPdfViewState();
}

class _LessonPdfViewState extends State<LessonPdfView> {
  late PdfControllerPinch _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = PdfControllerPinch(
      document: PdfDocument.openAsset(widget.assetPath),
    );
  }

  @override
  void didUpdateWidget(LessonPdfView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Navigating between lessons reuses this widget — without reloading,
    // the student would keep seeing the previous lesson's module.
    if (oldWidget.assetPath != widget.assetPath) {
      _controller.dispose();
      _failed = false;
      _controller = PdfControllerPinch(
        document: PdfDocument.openAsset(widget.assetPath),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openFullScreen() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenPdfPage(assetPath: widget.assetPath),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();

    final scheme = ShadTheme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Lesson module',
                style: ShadTheme.of(context).textTheme.h4,
              ),
            ),
            ShadButton.ghost(
              key: const Key('read-tab-pdf-fullscreen'),
              onPressed: _openFullScreen,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.maximize2, size: 16),
                  SizedBox(width: 8),
                  Text('Full screen'),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Fixed height because this sits inside the Read tab's scrolling
        // ListView — an unbounded PDF view can't lay out there.
        SizedBox(
          height: 480,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: scheme.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: PdfViewPinch(
                key: const Key('read-tab-pdf-view'),
                controller: _controller,
                onDocumentError: (_) {
                  // A corrupt or unreadable bundled PDF must never take the
                  // whole Read tab down with it — drop the viewer and leave
                  // the rest of the lesson usable.
                  if (mounted) setState(() => _failed = true);
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FullScreenPdfPage extends StatefulWidget {
  const _FullScreenPdfPage({required this.assetPath});

  final String assetPath;

  @override
  State<_FullScreenPdfPage> createState() => _FullScreenPdfPageState();
}

class _FullScreenPdfPageState extends State<_FullScreenPdfPage> {
  late final PdfControllerPinch _controller = PdfControllerPinch(
    document: PdfDocument.openAsset(widget.assetPath),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson module'),
        actions: [
          PdfPageNumber(
            controller: _controller,
            builder: (_, _, page, pagesCount) => Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('$page / ${pagesCount ?? 0}'),
              ),
            ),
          ),
        ],
      ),
      body: PdfViewPinch(controller: _controller),
    );
  }
}
