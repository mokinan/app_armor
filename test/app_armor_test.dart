import 'dart:async';

import 'package:app_armor/app_armor.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeEngine implements RaspEngine {
  final threatsController = StreamController<ArmorThreat>.broadcast();
  final finishedController = StreamController<void>.broadcast();
  RaspConfig? started;
  bool fail = false;

  @override
  Stream<ArmorThreat> get threats => threatsController.stream;

  @override
  Stream<void> get checksFinished => finishedController.stream;

  @override
  Future<void> start(RaspConfig config) async {
    if (fail) throw Exception('boom');
    started = config;
  }
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
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('app_armor'), (call) async {
    calls.add(call);
    return null;
  });

  setUp(() async {
    await AppArmor.reset();
    AppArmor.debugIsRelease = true;
    calls.clear();
  });

  test('sends the privacy settings to the native side', () async {
    await AppArmor.init(
        const ArmorConfig(privacy: PrivacyConfig(blockScreenshots: true)));
    expect(calls.single.method, 'configure');
    expect(calls.single.arguments['blockScreenshots'], isTrue);
    expect(calls.single.arguments['hideInAppSwitcher'], isTrue);
  });

  test('does nothing when disabled', () async {
    final engine = FakeEngine();
    await AppArmor.init(const ArmorConfig(enabled: false, rasp: rasp),
        engine: engine);
    expect(engine.started, isNull);
    expect(AppArmor.status.value.phase, ArmorPhase.idle);
  });

  test('skips runtime checks in debug builds unless asked', () async {
    AppArmor.debugIsRelease = false;
    final engine = FakeEngine();
    await AppArmor.init(const ArmorConfig(rasp: rasp), engine: engine);
    expect(engine.started, isNull);
  });

  test('checking, then passed, then idle', () {
    fakeAsync((async) {
      final engine = FakeEngine();
      AppArmor.init(const ArmorConfig(rasp: rasp), engine: engine);
      async.flushMicrotasks();
      expect(engine.started, isNotNull);
      expect(AppArmor.status.value.phase, ArmorPhase.checking);

      engine.finishedController.add(null);
      async.flushMicrotasks();
      expect(AppArmor.status.value.phase, ArmorPhase.passed);

      async.elapse(AppArmor.passedBadgeDuration);
      expect(AppArmor.status.value.phase, ArmorPhase.idle);
    });
  });

  test('hides the badge if the engine never answers', () {
    fakeAsync((async) {
      AppArmor.init(const ArmorConfig(rasp: rasp), engine: FakeEngine());
      async.flushMicrotasks();
      async.elapse(rasp.checkTimeout);
      expect(AppArmor.status.value.phase, ArmorPhase.idle);
    });
  });

  test('a blocking threat blocks and keeps the first reason', () async {
    final events = <ThreatEvent>[];
    final engine = FakeEngine();
    await AppArmor.init(ArmorConfig(rasp: rasp, onThreat: events.add),
        engine: engine);

    engine.threatsController
      ..add(ArmorThreat.rootOrJailbreak)
      ..add(ArmorThreat.hooks);
    await pumpEventQueue();
    engine.finishedController.add(null);
    await pumpEventQueue();

    expect(AppArmor.status.value.phase, ArmorPhase.blocked);
    expect(AppArmor.status.value.blockedBy, ArmorThreat.rootOrJailbreak);
    expect(events.map((e) => e.threat),
        [ArmorThreat.rootOrJailbreak, ArmorThreat.hooks]);
  });

  test('warnings and ignored threats do not block', () async {
    final events = <ThreatEvent>[];
    final engine = FakeEngine();
    await AppArmor.init(
        ArmorConfig(
          rasp: rasp,
          onThreat: events.add,
          policy: ThreatPolicy.recommended()
              .copyWith({ArmorThreat.emulator: ThreatAction.warn}).ignoring(
                  [ArmorThreat.vpn]),
        ),
        engine: engine);

    engine.threatsController
      ..add(ArmorThreat.emulator)
      ..add(ArmorThreat.vpn);
    await pumpEventQueue();

    expect(AppArmor.status.value.isBlocked, isFalse);
    expect(AppArmor.status.value.warnings, {ArmorThreat.emulator});
    expect(events.single.action, ThreatAction.warn);
  });

  test('a failing engine never breaks the app', () async {
    await AppArmor.init(const ArmorConfig(rasp: rasp),
        engine: FakeEngine()..fail = true);
    expect(AppArmor.status.value.phase, ArmorPhase.idle);
  });

  test('release builds silence debugPrint', () async {
    final before = debugPrint;
    await AppArmor.init(const ArmorConfig());
    expect(identical(debugPrint, before), isFalse);
    await AppArmor.reset();
    expect(identical(debugPrint, before), isTrue);
  });

  test('custom checks go through the policy', () async {
    await AppArmor.init(const ArmorConfig());
    AppArmor.reportThreat(ArmorThreat.tampering);
    expect(AppArmor.status.value.blockedBy, ArmorThreat.tampering);
  });
}
