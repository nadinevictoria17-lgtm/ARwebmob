import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:ar_science_explorer/core/services/voice_over_controller.dart';
import 'package:ar_science_explorer/features/student/ar_lab/ar_lab_providers.dart';
import 'package:ar_science_explorer/features/student/ar_lab/ar_lab_screen.dart';
import 'package:ar_science_explorer/core/services/access_code_service.dart';
import 'package:ar_science_explorer/core/services/quiz_attempt_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

/// Grants every permission it's asked about. ScanTab (rendered as the
/// screen's first tab) gates mounting EmbedUnity on
/// `Permission.camera.request()` resolving granted -- without this, the
/// real `MethodChannelPermissionHandler` has no platform to talk to in a
/// widget test, so `pumpAndSettle` never settles and every test here times
/// out.
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

class _FakeFlutterTts implements FlutterTts {
  int stopCallCount = 0;

  @override
  Future<dynamic> stop() async {
    stopCallCount += 1;
    return 1;
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async => 1;

  @override
  Future<dynamic> setLanguage(String language) async => 1;

  @override
  void setCompletionHandler(VoidCallback callback) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    PermissionHandlerPlatform.instance = _FakeGrantedPermissionHandler();
  });

  testWidgets('renders three tabs: Scan, Read, Review', (tester) async {
    final firestore = FakeFirebaseFirestore();
    final quizAttemptService = QuizAttemptService(firestore: firestore);
    final vm = ArLabViewModel(
      lessonId: 'q1w1',
      title: 'Scientific Models and the Particle Model of Matter',
      summary: 'summary',
      hasAR: true,
      markerIndex: 0,
      isRead: false,
      hasPreTest: true,
      hasPostTest: true,
      postTestEligible: false,
      postTestReason: 'Complete the lesson first.',
      studentId: '111111',
      accessCodeService: AccessCodeService(
        firestore: firestore,
        quizAttemptService: quizAttemptService,
      ),
      onMarkAsRead: () async {},
      onStartPreTest: () {},
      onStartPostTest: () {},
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          arLabViewModelProvider(
            'q1w1',
          ).overrideWith((ref) => Stream.value(vm)),
        ],
        child: const ShadApp(home: ArLabScreen(lessonId: 'q1w1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Read'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
  });

  testWidgets('stops voice narration when the screen is disposed', (
    tester,
  ) async {
    final firestore = FakeFirebaseFirestore();
    final quizAttemptService = QuizAttemptService(firestore: firestore);
    final vm = ArLabViewModel(
      lessonId: 'q1w1',
      title: 'Scientific Models and the Particle Model of Matter',
      summary: 'summary',
      hasAR: true,
      markerIndex: 0,
      isRead: false,
      hasPreTest: true,
      hasPostTest: true,
      postTestEligible: false,
      postTestReason: 'Complete the lesson first.',
      studentId: '111111',
      accessCodeService: AccessCodeService(
        firestore: firestore,
        quizAttemptService: quizAttemptService,
      ),
      onMarkAsRead: () async {},
      onStartPreTest: () {},
      onStartPostTest: () {},
    );

    final fakeTts = _FakeFlutterTts();
    final voiceOverController = VoiceOverController(tts: fakeTts);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          arLabViewModelProvider(
            'q1w1',
          ).overrideWith((ref) => Stream.value(vm)),
        ],
        child: ShadApp(
          home: ArLabScreen(
            lessonId: 'q1w1',
            voiceOverController: voiceOverController,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(fakeTts.stopCallCount, 0);

    // Replace the widget tree so ArLabScreen (and its State) is disposed.
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();

    expect(fakeTts.stopCallCount, greaterThanOrEqualTo(1));
  });
}
