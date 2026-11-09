import 'package:app_armor/app_armor.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('times out after inactivity, touches reset the timer',
      (tester) async {
    final reasons = <SessionTimeoutReason>[];
    await tester.pumpWidget(ArmorSessionGuard(
      inactivityTimeout: const Duration(minutes: 1),
      onTimeout: reasons.add,
      child: const SizedBox.expand(),
    ));

    await tester.pump(const Duration(seconds: 50));
    await tester.tapAt(const Offset(10, 10));
    await tester.pump(const Duration(seconds: 50));
    expect(reasons, isEmpty);

    await tester.pump(const Duration(seconds: 11));
    expect(reasons, [SessionTimeoutReason.inactivity]);
  });

  testWidgets('disabled guard never fires', (tester) async {
    final reasons = <SessionTimeoutReason>[];
    await tester.pumpWidget(ArmorSessionGuard(
      enabled: false,
      inactivityTimeout: const Duration(seconds: 1),
      onTimeout: reasons.add,
      child: const SizedBox.expand(),
    ));
    await tester.pump(const Duration(seconds: 5));
    expect(reasons, isEmpty);
  });

  testWidgets('returning after the background limit times out', (tester) async {
    final reasons = <SessionTimeoutReason>[];
    await tester.pumpWidget(ArmorSessionGuard(
      backgroundTimeout: Duration.zero,
      onTimeout: reasons.add,
      child: const SizedBox.expand(),
    ));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(reasons, [SessionTimeoutReason.background]);
  });
}
