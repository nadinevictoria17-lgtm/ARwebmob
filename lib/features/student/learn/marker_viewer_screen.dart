// lib/features/student/learn/marker_viewer_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show NetworkAssetBundle, rootBundle;
import 'package:photo_view/photo_view.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/ar/marker_mapping.dart';

/// Full-screen, pinch-to-zoom view of a lesson's AR marker image, with a
/// share/save action -- so a student without a second phone handy can show
/// this marker on their own screen for a classmate to scan, or save/send it
/// to be printed. Handles both the built-in curriculum's bundled marker
/// assets (`/markers/QxWy.jpg`) and a teacher-uploaded marker (a real
/// Firebase Storage URL) via [isNetworkMarker].
class MarkerViewerScreen extends StatelessWidget {
  const MarkerViewerScreen({
    super.key,
    required this.lessonTitle,
    required this.markerImage,
  });

  final String lessonTitle;
  final String markerImage;

  @override
  Widget build(BuildContext context) {
    final isNetwork = isNetworkMarker(markerImage);
    final imageProvider = isNetwork
        ? NetworkImage(markerImage)
        : AssetImage(markerAssetPath(markerImage)) as ImageProvider;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(lessonTitle),
        actions: [
          Tooltip(
            message: 'Save or share this marker',
            child: ShadIconButton.ghost(
              icon: const Icon(LucideIcons.download, color: Colors.white),
              onPressed: () => _share(context),
            ),
          ),
        ],
      ),
      body: PhotoView(
        imageProvider: imageProvider,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3,
        loadingBuilder: (context, event) =>
            const Center(child: CircularProgressIndicator()),
        errorBuilder: (context, error, stackTrace) => const Center(
          child: Text(
            'Couldn\'t load this marker image.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bytes = isNetworkMarker(markerImage)
          ? await NetworkAssetBundle(
              Uri.parse(markerImage),
            ).load(markerImage).then((data) => data.buffer.asUint8List())
          : await rootBundle
                .load(markerAssetPath(markerImage))
                .then((data) => data.buffer.asUint8List());
      final fileName = '${lessonTitle.replaceAll(RegExp(r'\s+'), '_')}_marker.jpg';
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, name: fileName, mimeType: 'image/jpeg')],
          text: 'AR marker for $lessonTitle',
        ),
      );
    } catch (_) {
      // Sharing/downloading is a convenience on top of viewing the marker --
      // a failure here (no share target, network hiccup) must never crash
      // the viewer itself.
      messenger.showSnackBar(
        const SnackBar(content: Text('Couldn\'t share this marker image.')),
      );
    }
  }
}
