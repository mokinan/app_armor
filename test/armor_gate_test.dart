import 'package:app_armor/app_armor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
          const MethodChannel('app_armor'), (call) async => null);

  setUp(() async {
    await AppArmor.reset();
    AppArmor.debugIsRelease = true;
  });

  testWidgets('the gate covers the app when blocked', (tester) async {
    await tester.runAsync(() => AppArmor.init(const ArmorConfig(
        silenceLogsInRelease: false,
        ui: ArmorUiConfig(texts: ArmorTexts.english))));
    await tester.pumpWidget(MaterialApp(
      builder: AppArmor.builder(),
      home: const Text('home'),
    ));
    expect(find.text('home'), findsOneWidget);

    AppArmor.reportThreat(ArmorThreat.rootOrJailbreak);
    await tester.pump();
    expect(find.text(ArmorTexts.english.blockedTitle), findsOneWidget);
    expect(find.text(ArmorTexts.english.reasons[ArmorThreat.rootOrJailbreak]!),
        findsOneWidget);
  });

  testWidgets('the gate works above MaterialApp, in Arabic', (tester) async {
    await tester.runAsync(
        () => AppArmor.init(const ArmorConfig(silenceLogsInRelease: false)));
    tester.platformDispatcher.localeTestValue = const Locale('ar');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    await tester.pumpWidget(const ArmorGate(child: SizedBox()));
    AppArmor.reportThreat(ArmorThreat.hooks);
    await tester.pump();
    expect(find.text(ArmorTexts.arabic.blockedTitle), findsOneWidget);
  });

  testWidgets('custom blocked screen gets the details, taps never pass',
      (tester) async {
    ArmorBlockedDetails? got;
    var tapped = false;
    await tester.runAsync(() => AppArmor.init(ArmorConfig(
          silenceLogsInRelease: false,
          ui: ArmorUiConfig(
            texts: ArmorTexts.english,
            blockedScreenBuilder: (context, d) {
              got = d;
              return const Center(child: Text('custom block'));
            },
          ),
        )));
    await tester.pumpWidget(MaterialApp(
      builder: AppArmor.builder(),
      home: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => tapped = true,
        child: const SizedBox.expand(),
      ),
    ));
    AppArmor.reportThreat(ArmorThreat.tampering);
    await tester.pump();

    expect(find.text('custom block'), findsOneWidget);
    expect(got!.threat, ArmorThreat.tampering);
    expect(got!.reason, ArmorTexts.english.reasons[ArmorThreat.tampering]);
    await tester.tapAt(const Offset(5, 5));
    expect(tapped, isFalse);
  });

  testWidgets('custom badge while checking, default badge reusable',
      (tester) async {
    await tester.runAsync(() => AppArmor.init(ArmorConfig(
          silenceLogsInRelease: false,
          ui: ArmorUiConfig(
            texts: ArmorTexts.english,
            badgePosition: ArmorBadgePosition.bottom,
            statusBadgeBuilder: (context, d) => Text('mine: ${d.label}'),
          ),
        )));
    await tester.pumpWidget(
        MaterialApp(builder: AppArmor.builder(), home: const SizedBox()));
    AppArmor.status.value = const ArmorStatus(phase: ArmorPhase.checking);
    await tester.pump();
    expect(find.text('mine: ${ArmorTexts.english.checking}'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(
        home: ArmorStatusBadge(
            details: ArmorBadgeDetails(
                phase: ArmorPhase.passed, texts: ArmorTexts.english))));
    expect(find.text(ArmorTexts.english.passed), findsOneWidget);
  });

  testWidgets('setLocale picks the language above MaterialApp', (tester) async {
    await tester.runAsync(
        () => AppArmor.init(const ArmorConfig(silenceLogsInRelease: false)));
    AppArmor.setLocale(const Locale('ar'));
    await tester.pumpWidget(const ArmorGate(child: SizedBox()));
    AppArmor.reportThreat(ArmorThreat.hooks);
    await tester.pump();
    expect(find.text(ArmorTexts.arabic.blockedTitle), findsOneWidget);

    AppArmor.setLocale(const Locale('en'));
    await tester.pump();
    expect(find.text(ArmorTexts.english.blockedTitle), findsOneWidget);
  });
}
