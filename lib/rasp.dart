/// Runtime protection only: root, jailbreak, hooks (Frida, Xposed),
/// debugger, emulator, tampering and the other freeRASP checks.
///
/// ```dart
/// import 'package:app_armor/rasp.dart';
///
/// ArmorRasp.threats.listen((threat) { /* block, log, … */ });
/// await ArmorRasp.start(const RaspConfig(
///   androidPackageName: 'com.company.app',
///   androidSigningCertHashes: ['<SHA-256 of signing key>'],
///   iosBundleIds: ['com.company.app'],
///   iosTeamId: 'ABCDE12345',
///   platforms: {ArmorPlatform.android}, // optional: Android only
/// ));
/// ```
///
/// For the checks together with the blocked screen and the threat policy,
/// use `package:app_armor/app_armor.dart` and `AppArmor.run`.
library;

export 'src/platforms.dart' show ArmorPlatform;
export 'src/rasp/armor_rasp.dart';
export 'src/rasp/rasp_config.dart';
export 'src/rasp/rasp_engine.dart' show RaspEngine;
export 'src/threats.dart' show ArmorThreat;
