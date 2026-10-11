import 'package:flutter/material.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

/// Renders a teacher-authored lesson's uploaded content: nothing when no
/// content has been uploaded, a processing message while the server-side
/// PPTX-to-slide-image conversion (Task 8) is still running, an "open
/// externally" affordance for a raw PDF upload (which sets `contentStatus:
/// 'ready'` immediately with a single non-image URL — it never goes
/// through slide conversion, so it can't be decoded as an image), and a
/// swipeable slide gallery once PPTX-converted slide images are ready — or
/// immediately for the legacy case of a single already-viewable image URL
/// that never needed conversion (`status == null`).
class ContentViewer extends StatefulWidget {
  const ContentViewer({
    super.key,
    required this.imageUrls,
    required this.status,
    this.launchUrl,
  });

  final List<String>? imageUrls;
  final String? status;

  /// Test-only injection point for opening a PDF externally, so widget
  /// tests can assert a launch was attempted without a real
  /// `url_launcher` platform channel handler. Defaults to
  /// `url_launcher`'s real `launchUrl`.
  final Future<bool> Function(Uri uri)? launchUrl;

  @override
  State<ContentViewer> createState() => _ContentViewerState();
}

bool _isPdfUrl(String url) =>
    url.toLowerCase().split('?').first.endsWith('.pdf');

class _ContentViewerState extends State<ContentViewer> {
  final _controller = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.imageUrls;
    if (urls == null || urls.isEmpty) return const SizedBox.shrink();

    final scheme = ShadTheme.of(context).colorScheme;

    if (widget.status == 'processing') {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Processing your teacher's uploaded content...",
                style: ShadTheme.of(
                  context,
                ).textTheme.muted.copyWith(color: scheme.mutedForeground),
              ),
            ),
          ],
        ),
      );
    }

    // A raw PDF upload never goes through slide-image conversion, so its
    // single URL isn't image-decodable — feeding it into NetworkImage
    // below would render a broken-image icon instead of viewable content.
    if (urls.length == 1 && _isPdfUrl(urls.first)) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: ShadButton.outline(
          key: const Key('content-viewer-open-pdf'),
          onPressed: () =>
              (widget.launchUrl ?? _defaultLaunchUrl)(Uri.parse(urls.first)),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.fileText, size: 16),
              SizedBox(width: 8),
              Text('View lesson content (PDF)'),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 400,
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: PhotoViewGallery.builder(
                pageController: _controller,
                itemCount: urls.length,
                onPageChanged: (index) =>
                    setState(() => _currentIndex = index),
                builder: (context, index) => PhotoViewGalleryPageOptions(
                  imageProvider: NetworkImage(urls[index]),
                  // A slide image can fail to load (network hiccup, an
                  // expired signed URL) — fall back to a plain icon instead
                  // of letting the uncaught NetworkImageLoadException bubble
                  // up through the image resource service.
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Icon(
                      LucideIcons.imageOff,
                      size: 48,
                      color: scheme.mutedForeground,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_currentIndex + 1} / ${urls.length}',
            style: ShadTheme.of(
              context,
            ).textTheme.small.copyWith(color: scheme.mutedForeground),
          ),
        ],
      ),
    );
  }
}

Future<bool> _defaultLaunchUrl(Uri uri) => url_launcher.launchUrl(
  uri,
  mode: url_launcher.LaunchMode.externalApplication,
);
