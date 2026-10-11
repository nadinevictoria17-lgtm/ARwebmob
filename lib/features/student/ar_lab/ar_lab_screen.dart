import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/services/voice_over_controller.dart';
import 'ar_lab_providers.dart';
import 'read_tab.dart';
import 'review_tab.dart';
import 'scan_tab.dart';

class ArLabScreen extends ConsumerStatefulWidget {
  const ArLabScreen({
    super.key,
    required this.lessonId,
    this.voiceOverController,
  });

  final String lessonId;

  /// Overrides the [VoiceOverController] this screen builds internally.
  /// Exposed for tests that need to observe narration lifecycle (e.g.
  /// asserting [VoiceOverController.stop] is called on [dispose]); real
  /// callers should leave this null and let the screen build its own.
  final VoiceOverController? voiceOverController;

  @override
  ConsumerState<ArLabScreen> createState() => _ArLabScreenState();
}

class _ArLabScreenState extends ConsumerState<ArLabScreen> {
  late final VoiceOverController _voiceOverController;

  @override
  void initState() {
    super.initState();
    _voiceOverController =
        widget.voiceOverController ?? VoiceOverController(tts: FlutterTts());
  }

  @override
  void dispose() {
    _voiceOverController.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncViewModel = ref.watch(arLabViewModelProvider(widget.lessonId));

    return asyncViewModel.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) => Scaffold(
        body: Center(child: Text('Could not load this lesson: $error')),
      ),
      data: (vm) => DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: Text(vm.title),
            bottom: TabBar(
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(LucideIcons.scanLine, size: 16),
                      SizedBox(width: 6),
                      Text('Scan'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(LucideIcons.bookOpen, size: 16),
                      SizedBox(width: 6),
                      Text('Read'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(LucideIcons.listChecks, size: 16),
                      SizedBox(width: 6),
                      Text('Review'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Swipe navigation is disabled: TabBarView is a PageView under the
          // hood, and its horizontal-drag recognizer competes in the gesture
          // arena with the embedded Unity AndroidView's own touch handling.
          // On the Scan tab that fight is what made a swipe-right jump to
          // the next tab instead of rotating the model, and made rotate/zoom
          // feel loose even when it didn't -- Unity was only getting partial
          // gesture claims. Tabs are switched via the TabBar only now, which
          // leaves the embed the whole gesture arena to itself.
          body: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            children: [
              ScanTab(vm: vm, voiceOverController: _voiceOverController),
              ReadTab(vm: vm),
              ReviewTab(vm: vm),
            ],
          ),
        ),
      ),
    );
  }
}
