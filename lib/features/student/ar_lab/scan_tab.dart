import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_embed_unity/flutter_embed_unity.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../core/ar/voice_scripts_data.dart';
import '../../../core/models/lesson.dart';
import '../../../core/services/voice_over_controller.dart';
import 'ar_lab_providers.dart';

/// The AR Lab's Scan phase (PROJECT_FLOW.md Part 6.3): shows the live Unity
/// camera feed and overlays the description of whatever marker it currently
/// recognizes, plus optional voice narration controls.
class ScanTab extends StatefulWidget {
  const ScanTab({
    super.key,
    required this.vm,
    required this.voiceOverController,
  });

  final ArLabViewModel vm;
  final VoiceOverController voiceOverController;

  @override
  State<ScanTab> createState() => _ScanTabState();
}

class _ScanTabState extends State<ScanTab> with WidgetsBindingObserver {
  String _language = 'en';

  // Fixes a real first-launch bug: Unity's own native camera init used to
  // race the OS's runtime permission dialog -- EmbedUnity was mounted
  // unconditionally, so on a fresh install Unity would try to open the
  // camera before the OS had actually granted CAMERA access, fail silently,
  // and never retry within that session (only a full app restart, with the
  // permission now already granted from a prior run, worked). Explicitly
  // requesting the permission here and gating EmbedUnity's mount on the
  // result means Unity never starts until Android has confirmed access.
  PermissionStatus? _cameraPermission;

  // Set once, the first time EmbedUnity actually mounts (camera permission
  // just got granted) — Unity's ARSessionManager GameObject only exists once
  // its scene is running, so sending this any earlier would be a message
  // into the void. Cleared on dispose so a later Scan tab (a different
  // lesson) doesn't inherit a stale restriction from this one.
  bool _sentActiveLesson = false;

  // A wrong-lesson scan (Unity's "wrongModel" event) is shown as a
  // self-dismissing banner rather than a persistent one — it's telling the
  // student about a single scan attempt, not an ongoing state like
  // _DetectedLessonOverlay below.
  String? _wrongModelMessage;
  Timer? _wrongModelTimer;

  /// Retry timers for the SetActiveLesson handshake (see _sendActiveLesson),
  /// cancelled on dispose so a pending send can't fire into a dead widget.
  final List<Timer> _activeLessonTimers = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.vm.addListener(_onViewModelChanged);
    _requestCameraPermission();
  }

  /// Unity keeps running (camera session live, rendering every frame) even
  /// once this tab is gone, because unmounting `EmbedUnity` only removes the
  /// Android view — the player itself stays loaded. On a low-end school
  /// phone that meant the Vuforia camera ran through the entire post-test,
  /// draining battery, heating the device, and holding the camera against
  /// every other app. Pausing on background/unmount and resuming on return
  /// is the fix.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (!mounted) return;
    if (state == AppLifecycleState.resumed) {
      if (_cameraPermission?.isGranted == true) resumeUnity();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      pauseUnity();
    }
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (!mounted) return;
    setState(() => _cameraPermission = status);
    if (status.isGranted) {
      resumeUnity();
      _sendActiveLesson();
    }
  }

  /// Tells Unity which lesson is open, so `ARSessionManager` can reject
  /// markers belonging to other lessons.
  ///
  /// Sent repeatedly on purpose. `setState` above only *schedules* a
  /// rebuild, so `EmbedUnity` hasn't been built yet at that point — let
  /// alone finished loading its scene and created the `ARSessionManager`
  /// GameObject. A single send therefore landed in the void on the first
  /// lesson opened after launch (Unity not loaded yet) while working on
  /// later lessons (Unity already resident), which made the per-lesson
  /// scan restriction silently inconsistent: the first lesson of a session
  /// would happily show another lesson's model. Re-sending over the first
  /// few seconds costs nothing — the Unity side just re-assigns the same
  /// string — and guarantees the restriction actually applies.
  void _sendActiveLesson() {
    _sentActiveLesson = true;
    final fragment = widget.vm.activeLessonFragment ?? '';

    // Send straight away for the common case where Unity is already
    // resident (any lesson after the first in a session)...
    sendToUnity('ARSessionManager', 'SetActiveLesson', fragment);

    // ...then repeat over the next few seconds to cover a cold start, where
    // the scene and its ARSessionManager GameObject don't exist yet.
    const retryDelays = [
      Duration(milliseconds: 500),
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ];
    for (final delay in retryDelays) {
      _activeLessonTimers.add(
        Timer(delay, () {
          if (!mounted) return;
          sendToUnity('ARSessionManager', 'SetActiveLesson', fragment);
        }),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.vm.removeListener(_onViewModelChanged);
    _wrongModelTimer?.cancel();
    for (final timer in _activeLessonTimers) {
      timer.cancel();
    }
    if (_sentActiveLesson) {
      sendToUnity('ARSessionManager', 'ClearActiveLesson', '');
    }
    // Leaving the Scan tab must stop Unity's camera/render loop — see
    // didChangeAppLifecycleState above.
    pauseUnity();
    super.dispose();
  }

  void _onViewModelChanged() => setState(() {});

  // The parent's StreamProvider emits a new ArLabViewModel instance whenever
  // the student record updates. Without re-subscribing here, this tab keeps
  // listening to the stale instance, so a marker found on the new one (e.g.
  // the lesson description card) never triggers a rebuild.
  @override
  void didUpdateWidget(ScanTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.vm != widget.vm) {
      oldWidget.vm.removeListener(_onViewModelChanged);
      widget.vm.addListener(_onViewModelChanged);
    }
  }

  void _handleUnityMessage(String message) {
    debugPrint('ScanTab: Unity message received: $message');
    try {
      final decoded = jsonDecode(message);
      if (decoded is! Map<String, dynamic>) return;
      final event = decoded['event'] as String?;
      final trackableName = decoded['trackableName'] as String?;
      if (trackableName == null) return;
      if (event == 'markerFound') {
        widget.vm.onMarkerFound(trackableName);
        debugPrint(
          'ScanTab: markerFound "$trackableName" -> lesson '
          '${widget.vm.detectedLesson?.id ?? "NO MATCH"}',
        );
      } else if (event == 'markerLost') {
        widget.vm.onMarkerLost(trackableName);
      } else if (event == 'wrongModel') {
        _showWrongModelMessage();
      }
    } catch (error) {
      // A malformed or unrecognized message from Unity (bad JSON, wrong
      // shape, or a future event type) should never crash the Scan tab —
      // swallow it after logging for debugging.
      debugPrint('ScanTab: ignoring malformed Unity message: $error');
    }
  }

  void _showWrongModelMessage() {
    _wrongModelTimer?.cancel();
    setState(
      () => _wrongModelMessage = "Sorry, that's not this lesson's model.",
    );
    _wrongModelTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _wrongModelMessage = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.vm.hasAR) {
      final scheme = ShadTheme.of(context).colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            "This lesson doesn't have an AR model — continue to the Read tab.",
            textAlign: TextAlign.center,
            style: ShadTheme.of(
              context,
            ).textTheme.p.copyWith(color: scheme.mutedForeground),
          ),
        ),
      );
    }

    if (_cameraPermission == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_cameraPermission!.isGranted) {
      final scheme = ShadTheme.of(context).colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.videoOff, size: 48, color: scheme.mutedForeground),
              const SizedBox(height: 12),
              Text(
                _cameraPermission!.isPermanentlyDenied
                    ? 'Camera access is off for this app. Enable it in your phone\'s Settings to use Scan.'
                    : 'Camera access is needed to scan AR markers.',
                textAlign: TextAlign.center,
                style: ShadTheme.of(context).textTheme.p,
              ),
              const SizedBox(height: 16),
              ShadButton(
                onPressed: _cameraPermission!.isPermanentlyDenied
                    ? openAppSettings
                    : _requestCameraPermission,
                child: Text(
                  _cameraPermission!.isPermanentlyDenied
                      ? 'Open Settings'
                      : 'Allow Camera',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final scripts = kVoiceScripts[widget.vm.lessonId];

    return Stack(
      children: [
        Positioned.fill(
          child: EmbedUnity(onMessageFromUnity: _handleUnityMessage),
        ),
        // No "point your camera at the marker" card while idle: the Unity
        // camera feed is the instruction, and the card sat on top of it.
        if (widget.vm.detectedLesson != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _DetectedLessonOverlay(lesson: widget.vm.detectedLesson!),
          ),
        if (_wrongModelMessage != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _WrongModelOverlay(text: _wrongModelMessage!),
          ),
        if (scripts != null)
          Positioned(
            top: 16,
            right: 16,
            child: _VoiceControls(
              scripts: scripts,
              language: _language,
              onLanguageChanged: (value) => setState(() => _language = value),
              onPlay: () => widget.voiceOverController.playAll(
                scripts[_language] ?? const [],
                _language,
              ),
            ),
          ),
      ],
    );
  }
}

/// Shown briefly when Unity rejects a scan because the marker belongs to a
/// different lesson than the one currently open (the per-lesson scan
/// restriction — see `ARSessionManager`/`ARTargetVisibilityAndInteraction`
/// on the Unity side, and `ArLabViewModel.activeLessonFragment`).
class _WrongModelOverlay extends StatelessWidget {
  const _WrongModelOverlay({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      backgroundColor: Colors.red.withValues(alpha: 0.85),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.circleAlert, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: ShadTheme.of(
                context,
              ).textTheme.h4.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

/// The recognized lesson's info panel.
///
/// Collapsible (client feedback, on-device test): expanded it covers the
/// bottom fifth of the screen, which sits directly on top of the AR model
/// and makes rotating/pinch-zooming it awkward — the student's fingers and
/// the model itself are both fighting this card for the same space. It
/// starts expanded (students should see the description on first
/// recognition) but collapses to a single title bar on tap, freeing the
/// whole camera view for interacting with the model.
class _DetectedLessonOverlay extends StatefulWidget {
  const _DetectedLessonOverlay({required this.lesson});

  final Lesson lesson;

  @override
  State<_DetectedLessonOverlay> createState() => _DetectedLessonOverlayState();
}

class _DetectedLessonOverlayState extends State<_DetectedLessonOverlay> {
  bool _expanded = true;

  @override
  void didUpdateWidget(_DetectedLessonOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A newly recognized lesson gets its description shown again — the
    // student collapsed the *previous* lesson's panel, not this one's.
    if (oldWidget.lesson.id != widget.lesson.id) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = ShadTheme.of(context).textTheme;
    final scheme = ShadTheme.of(context).colorScheme;
    final payload = widget.lesson.arPayload;
    final keyIdeas = payload?.keyIdeas;

    final header = InkWell(
      key: const Key('scan-description-toggle'),
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                payload?.title ?? widget.lesson.title,
                style: textTheme.p.copyWith(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              _expanded ? LucideIcons.chevronDown : LucideIcons.chevronUp,
              size: 20,
              color: scheme.mutedForeground,
            ),
          ],
        ),
      ),
    );

    if (!_expanded) {
      return ShadCard(padding: EdgeInsets.zero, child: header);
    }

    // Capped and scrollable rather than sized to content: a lesson with a
    // long description plus several key ideas would otherwise grow tall
    // enough to cover most of the live Unity camera feed above it.
    return ShadCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          header,
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.2,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (payload?.subtitle != null)
                      Text(
                        payload!.subtitle!,
                        style: textTheme.small.copyWith(
                          color: scheme.mutedForeground,
                        ),
                      ),
                    if (payload?.description != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          payload!.description!,
                          style: textTheme.small.copyWith(
                            color: scheme.mutedForeground,
                          ),
                        ),
                      ),
                    if (keyIdeas != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final idea in keyIdeas)
                              Text(
                                '• $idea',
                                style: textTheme.small.copyWith(
                                  color: scheme.mutedForeground,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceControls extends StatelessWidget {
  const _VoiceControls({
    required this.scripts,
    required this.language,
    required this.onLanguageChanged,
    required this.onPlay,
  });

  final Map<String, List<String>> scripts;
  final String language;
  final void Function(String) onLanguageChanged;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return ShadCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShadSelect<String>(
            initialValue: language,
            minWidth: 110,
            options: const [
              ShadOption(value: 'en', child: Text('English')),
              ShadOption(value: 'Filipino', child: Text('Filipino')),
            ],
            selectedOptionBuilder: (context, value) =>
                Text(value == 'en' ? 'English' : 'Filipino'),
            onChanged: (value) {
              if (value != null) onLanguageChanged(value);
            },
          ),
          ShadIconButton.ghost(
            icon: const Icon(LucideIcons.volume2),
            onPressed: onPlay,
          ),
        ],
      ),
    );
  }
}
