import 'package:app_armor/app_armor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recommended blocks attacks on the app, warns on the rest', () {
    final p = ThreatPolicy.recommended();
    for (final t in [
      ArmorThreat.hooks,
      ArmorThreat.debugger,
      ArmorThreat.rootOrJailbreak,
      ArmorThreat.tampering,
      ArmorThreat.emulator,
    ]) {
      expect(p.actionFor(t), ThreatAction.block, reason: t.name);
    }
    expect(p.actionFor(ArmorThreat.vpn), ThreatAction.warn);
    expect(p.actionFor(ArmorThreat.screenshot), ThreatAction.ignore);
  });

  test('strict blocks more', () {
    expect(ThreatPolicy.strict().actionFor(ArmorThreat.multiInstance),
        ThreatAction.block);
  });

  test('monitorOnly never blocks', () {
    final p = ThreatPolicy.monitorOnly();
    expect(
        ArmorThreat.values.map(p.actionFor), everyElement(ThreatAction.warn));
  });

  test('copyWith and ignoring override single threats', () {
    final p = ThreatPolicy.recommended().copyWith(
        {ArmorThreat.emulator: ThreatAction.warn}).ignoring([ArmorThreat.vpn]);
    expect(p.actionFor(ArmorThreat.emulator), ThreatAction.warn);
    expect(p.actionFor(ArmorThreat.vpn), ThreatAction.ignore);
    expect(p.actionFor(ArmorThreat.hooks), ThreatAction.block);
  });

  test('fromJson reads presets and overrides, skips unknown names', () {
    final p = ThreatPolicy.fromJson({
      'preset': 'strict',
      'emulator': 'warn',
      'vpn': 'ignore',
      'someFutureThreat': 'block',
      'hooks': 'explode',
      'fallback': 'ignore',
    });
    expect(p.actionFor(ArmorThreat.emulator), ThreatAction.warn);
    expect(p.actionFor(ArmorThreat.vpn), ThreatAction.ignore);
    expect(p.actionFor(ArmorThreat.hooks), ThreatAction.block);
    expect(p.actionFor(ArmorThreat.multiInstance), ThreatAction.block);
    expect(p.fallback, ThreatAction.ignore);
  });

  test('toJson round-trips', () {
    final p = ThreatPolicy.strict().ignoring([ArmorThreat.vpn]);
    final back =
        ThreatPolicy.fromJson(p.toJson(), base: ThreatPolicy.monitorOnly());
    for (final t in ArmorThreat.values) {
      expect(back.actionFor(t), p.actionFor(t), reason: t.name);
    }
  });
}
