import 'dart:async';

import 'package:app_armor/rasp.dart';
import 'package:app_armor/screen_protection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeEngine implements RaspEngine {
  final threatsController = StreamController<ArmorThreat>.broadcast();
  final finishedController = StreamController<void>.broadcast();
  RaspConfig? started;

  @override
  Stream<ArmorThreat> get threats => threatsController.stream;

  @override
  Stream<void> get checksFinished => finishedController.stream;

  @override
  Future<void> start(RaspConfig config) async => started = config;
}

const rasp = RaspConfig(
  androidPackageName: 'com.example.app',
  androidSigningCertHashes: ['AAAA'],
  iosBundleIds: ['com.example.app'],
  iosTeamId: 'ABCDE12345',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(const MethodChannel('app_armor'),
      (call) async {
    calls.add(call);
    return null;
  });

  setUp(() async {
    await ArmorRasp.reset();
    ArmorScreenProtection.reset();
    ArmorPlatform.debugOverride = ArmorPlatform.android;
    ArmorPlatform.debugIsRelease = true;
    calls.clear();
  });

  group('ArmorRasp alone', () {
    test('forwards threats and finished checks', () async {
      final engine = FakeEngine();
      final threats = <ArmorThreat>[];
      var finished = 0;
      ArmorRasp.threats.listen(threats.add);
      ArmorRasp.checksFinished.listen((_) => finished++);

      expect(await ArmorRasp.start(rasp, engine: engine), isTrue);
      expect(ArmorRasp.isRunning, isTrue);
      engine.threatsController.add(ArmorThreat.hooks);
      engine.finishedController.add(null);
      await pumpEventQueue();

      expect(threats, [ArmorThreat.hooks]);
      expect(finished, 1);
      expect(calls, isEmpty, reason: 'no screen privacy was asked for');
    });

    test('skips platforms that are not listed', () async {
      ArmorPlatform.debugOverride = ArmorPlatform.ios;
      final engine = FakeEngine();
      const androidOnly = RaspConfig(
        androidPackageName: 'com.example.app',
        androidSigningCertHashes: ['AAAA'],
        iosBundleIds: ['com.example.app'],
        iosTeamId: 'ABCDE12345',
        platforms: {ArmorPlatform.android},
      );
      expect(ArmorRasp.willRun(androidOnly), isFalse);
      expect(await ArmorRasp.start(androidOnly, engine: engine), isFalse);
      expect(engine.started, isNull);
    });

    test('skips debug builds unless asked', () async {
      ArmorPlatform.debugIsRelease = false;
      expect(await ArmorRasp.start(rasp, engine: FakeEngine()), isFalse);
    });
  });

  group('ArmorScreenProtection alone', () {
    test('applies the settings', () async {
      expect(
          await ArmorScreenProtection.start(
              const PrivacyConfig(blockScreenshots: true)),
          isTrue);
      expect(calls.single.method, 'configure');
      expect(calls.single.arguments['blockScreenshots'], isTrue);
    });

    test('does nothing on a platform that is not listed', () async {
      ArmorPlatform.debugOverride = ArmorPlatform.ios;
      expect(
          await ArmorScreenProtection.start(
              const PrivacyConfig(platforms: {ArmorPlatform.android})),
          isFalse);
      expect(calls, isEmpty);
    });

    test('reports screenshots and recording', () async {
      await ArmorScreenProtection.start(const PrivacyConfig());
      final threats = <ArmorThreat>[];
      var stopped = 0;
      ArmorScreenProtection.threats.listen(threats.add);
      ArmorScreenProtection.recordingStopped.listen((_) => stopped++);

      Future<void> fromNative(String method, [Object? args]) =>
          messenger.handlePlatformMessage(
              'app_armor',
              const StandardMethodCodec()
                  .encodeMethodCall(MethodCall(method, args)),
              (_) {});
      await fromNative('screenshotTaken');
      await fromNative('captureChanged', true);
      await fromNative('captureChanged', false);
      await pumpEventQueue();

      expect(threats, [ArmorThreat.screenshot, ArmorThreat.screenRecording]);
      expect(stopped, 1);
    });
  });
}
