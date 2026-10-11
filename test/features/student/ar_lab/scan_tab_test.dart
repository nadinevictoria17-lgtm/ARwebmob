import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_embed_unity/flutter_embed_unity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ar_science_explorer/core/services/access_code_service.dart';
import 'package:ar_science_explorer/core/services/quiz_attempt_service.dart';
import 'package:ar_science_explorer/core/services/voice_over_controller.dart';
import 'package:ar_science_explorer/features/student/ar_lab/ar_lab_providers.dart';
import 'package:ar_science_explorer/features/student/ar_lab/scan_tab.dart';

/// Grants every permission it's asked about. ScanTab gates mounting
/// EmbedUnity on `Permission.camera.request()` resolving granted (see the
/// comment on `_ScanTabState._cameraPermission`) -- without this, the real
/// `MethodChannelPermissionHandler` has no platform to talk to in a widget
/// test and every test here hangs on the "requesting permission" spinner.
class _FakeGrantedPermissionHandler extends PermissionHandlerPlatform
    with MockPlatformInterfaceMixin {
  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async =>
      PermissionStatus.granted;

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async => {for (final p in permissions) p: PermissionStatus.granted};
}

class FakeFlutterTts implements FlutterTts {
  final List<String> spokenTexts = [];

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    spokenTexts.add(text);
    return 1;
  }

  @override
  Future<dynamic> setLanguage(String language) async => 1;

  @override
  Future<dynamic> stop() async => 1;

  @override
  void setCompletionHandler(VoidCallback callback) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ArLabViewModel _buildViewModel({
  required String lessonId,
  required bool hasAR,
  String? markerImage,
  int? quarter,
  int? week,
}) {
  final firestore = FakeFirebaseFirestore();
  final quizAttemptService = QuizAttemptService(firestore: firestore);
  final accessCodeService = AccessCodeService(
    firestore: firestore,
    quizAttemptService: quizAttemptService,
  );

  return ArLabViewModel(
    lessonId: lessonId,
    title: 'Some lesson title',
    summary: 'Some lesson summary',
    hasAR: hasAR,
    markerIndex: hasAR ? 0 : null,
    markerImage: markerImage,
    quarter: quarter,
    week: week,
    isRead: false,
    hasPreTest: true,
    hasPostTest: true,
    postTestEligible: true,
    postTestReason: null,
    studentId: '111111',
    accessCodeService: accessCodeService,
    onMarkAsRead: () async {},
    onStartPreTest: () {},
    onStartPostTest: () {},
  );
}

// ShadApp, not MaterialApp: ScanTab's overlays read ShadTheme.of(context).
Widget _wrap(Widget child) => ShadApp(home: Scaffold(body: child));

const _embedUnityChannel = MethodChannel(
  'com.learntoflutter/flutter_embed_unity',
);

void main() {
  final sendToUnityCalls = <List<dynamic>>[];

  setUp(() {
    PermissionHandlerPlatform.instance = _FakeGrantedPermissionHandler();
    sendToUnityCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_embedUnityChannel, (call) async {
          if (call.method == 'sendToUnity') {
            sendToUnityCalls.add(call.arguments as List<dynamic>);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_embedUnityChannel, null);
  });

  testWidgets(
    'shows no instruction card or marker image over the camera while nothing '
    'is detected',
    (tester) async {
      final vm = _buildViewModel(
        lessonId: 'q1w1',
        hasAR: true,
        markerImage: 'https://fake-storage.example/lessons/q1w1/marker.png',
      );
      final voiceOverController = VoiceOverController(tts: FakeFlutterTts());

      await tester.pumpWidget(
        _wrap(ScanTab(vm: vm, voiceOverController: voiceOverController)),
      );
      await tester.pump();

      expect(find.textContaining('Point your camera'), findsNothing);
      expect(find.byType(Image), findsNothing);
    },
  );

  testWidgets(
    'shows the detected lesson\'s AR title once a marker is found',
    (tester) async {
      final vm = _buildViewModel(lessonId: 'q1w1', hasAR: true);
      final voiceOverController = VoiceOverController(tts: FakeFlutterTts());

      await tester.pumpWidget(
        _wrap(ScanTab(vm: vm, voiceOverController: voiceOverController)),
      );
      await tester.pump();

      vm.onMarkerFound('DemocritusAtomQ1W1');
      await tester.pump();

      expect(find.text('Democritus Atom'), findsOneWidget);
      expect(find.textContaining('Point your camera'), findsNothing);
    },
  );

  testWidgets(
    'sends the lesson\'s Q<quarter>W<week> fragment to Unity as the active-lesson '
    'restriction once camera permission is granted',
    (tester) async {
      final vm = _buildViewModel(
        lessonId: 'q1w1',
        hasAR: true,
        quarter: 1,
        week: 1,
      );
      final voiceOverController = VoiceOverController(tts: FakeFlutterTts());

      await tester.pumpWidget(
        _wrap(ScanTab(vm: vm, voiceOverController: voiceOverController)),
      );
      await tester.pump();

      // The fragment is re-sent on a short retry schedule because Unity's
      // scene (and so ARSessionManager) may not exist yet when the tab
      // first builds — see ScanTab._sendActiveLesson. So assert on the
      // message rather than on a single call: every send must carry this
      // lesson's fragment, and at least one must have gone out.
      expect(sendToUnityCalls, isNotEmpty);
      expect(
        sendToUnityCalls,
        everyElement(['ARSessionManager', 'SetActiveLesson', 'Q1W1']),
      );

      // Dispose so the pending retry timers are cancelled.
      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
    },
  );

  testWidgets(
    'sends an empty fragment (no restriction) for a lesson with no curriculum placement',
    (tester) async {
      final vm = _buildViewModel(lessonId: 'teacher-1', hasAR: true);
      final voiceOverController = VoiceOverController(tts: FakeFlutterTts());

      await tester.pumpWidget(
        _wrap(ScanTab(vm: vm, voiceOverController: voiceOverController)),
      );
      await tester.pump();

      expect(sendToUnityCalls, isNotEmpty);
      expect(
        sendToUnityCalls,
        everyElement(['ARSessionManager', 'SetActiveLesson', '']),
      );

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
    },
  );

  testWidgets('clears the active-lesson restriction on dispose', (
    tester,
  ) async {
    final vm = _buildViewModel(
      lessonId: 'q1w1',
      hasAR: true,
      quarter: 1,
      week: 1,
    );
    final voiceOverController = VoiceOverController(tts: FakeFlutterTts());

    await tester.pumpWidget(
      _wrap(ScanTab(vm: vm, voiceOverController: voiceOverController)),
    );
    await tester.pump();

    await tester.pumpWidget(_wrap(const SizedBox.shrink()));

    // The restriction is set (possibly re-sent, see the retry schedule in
    // ScanTab._sendActiveLesson) and then cleared exactly once, last, on
    // dispose — so leaving a lesson can't leak its restriction into the
    // next one.
    expect(sendToUnityCalls.first, [
      'ARSessionManager',
      'SetActiveLesson',
      'Q1W1',
    ]);
    expect(sendToUnityCalls.last, [
      'ARSessionManager',
      'ClearActiveLesson',
      '',
    ]);
    expect(
      sendToUnityCalls.where((call) => call[1] == 'ClearActiveLesson').length,
      1,
    );
  });

  testWidgets(
    'shows a self-dismissing "not this lesson\'s model" banner on a wrongModel Unity event',
    (tester) async {
      final vm = _buildViewModel(
        lessonId: 'q1w1',
        hasAR: true,
        quarter: 1,
        week: 1,
      );
      final voiceOverController = VoiceOverController(tts: FakeFlutterTts());

      await tester.pumpWidget(
        _wrap(ScanTab(vm: vm, voiceOverController: voiceOverController)),
      );
      await tester.pump();

      final embedUnity = tester.widget<EmbedUnity>(find.byType(EmbedUnity));
      embedUnity.onMessageFromUnity?.call(
        '{"event":"wrongModel","trackableName":"Q1W6beakers"}',
      );
      await tester.pump();

      expect(find.textContaining("not this lesson's model"), findsOneWidget);

      await tester.pump(const Duration(seconds: 3));
      expect(find.textContaining("not this lesson's model"), findsNothing);
    },
  );

  testWidgets(
    'shows a graceful fallback message and never builds EmbedUnity when hasAR is false',
    (tester) async {
      final vm = _buildViewModel(lessonId: 'q1w5', hasAR: false);
      final voiceOverController = VoiceOverController(tts: FakeFlutterTts());

      await tester.pumpWidget(
        _wrap(ScanTab(vm: vm, voiceOverController: voiceOverController)),
      );
      await tester.pump();

      expect(find.textContaining("doesn't have an AR model"), findsOneWidget);
      expect(find.byType(EmbedUnity), findsNothing);
    },
  );

  testWidgets(
    'ignores a malformed Unity message (invalid JSON) without throwing or '
    'changing UI state',
    (tester) async {
      final vm = _buildViewModel(lessonId: 'q1w1', hasAR: true);
      final voiceOverController = VoiceOverController(tts: FakeFlutterTts());

      await tester.pumpWidget(
        _wrap(ScanTab(vm: vm, voiceOverController: voiceOverController)),
      );
      await tester.pump();

      final embedUnity = tester.widget<EmbedUnity>(find.byType(EmbedUnity));

      expect(
        () => embedUnity.onMessageFromUnity?.call('not valid json{'),
        returnsNormally,
      );
      await tester.pump();

      expect(vm.detectedLesson, isNull);
      expect(find.textContaining('Point your camera'), findsNothing);
    },
  );

  testWidgets(
    'ignores a well-formed JSON message missing the expected fields without '
    'throwing or changing UI state',
    (tester) async {
      final vm = _buildViewModel(lessonId: 'q1w1', hasAR: true);
      final voiceOverController = VoiceOverController(tts: FakeFlutterTts());

      await tester.pumpWidget(
        _wrap(ScanTab(vm: vm, voiceOverController: voiceOverController)),
      );
      await tester.pump();

      final embedUnity = tester.widget<EmbedUnity>(find.byType(EmbedUnity));

      expect(
        () => embedUnity.onMessageFromUnity?.call('{"unexpected":"shape"}'),
        returnsNormally,
      );
      expect(
        () => embedUnity.onMessageFromUnity?.call('["not", "a", "map"]'),
        returnsNormally,
      );
      await tester.pump();

      expect(vm.detectedLesson, isNull);
      expect(find.textContaining('Point your camera'), findsNothing);
    },
  );
}
