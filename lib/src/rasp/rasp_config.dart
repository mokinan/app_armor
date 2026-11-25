import '../platforms.dart';
import '../threats.dart';

/// Runtime protection (RASP), powered by freeRASP by Talsec.
class RaspConfig {
  const RaspConfig({
    required this.androidPackageName,
    required this.androidSigningCertHashes,
    required this.iosBundleIds,
    required this.iosTeamId,
    this.androidSupportedStores = const [],
    this.watcherMail = '',
    this.killOnBypass = true,
    this.runInDebug = false,
    this.checkTimeout = const Duration(seconds: 20),
    this.platforms = ArmorPlatform.all,
  });

  /// e.g. `com.company.app`.
  final String androidPackageName;

  /// SHA-256 of every key the Android app is signed with (upload key AND the
  /// Google Play app signing key), Base64 or hex (`AB:CD:…`).
  ///
  /// Play Console > Test and release > App integrity > App signing.
  /// If the Play key is missing, every store install is reported as
  /// [ArmorThreat.tampering]: either add it, or set tampering to
  /// [ThreatAction.warn] until you have it.
  final List<String> androidSigningCertHashes;

  /// Stores other than Google Play that may install the app, e.g.
  /// `com.huawei.appmarket`.
  final List<String> androidSupportedStores;

  final List<String> iosBundleIds;

  /// The 10-character Apple Developer Team ID.
  final String iosTeamId;

  /// Talsec sends a weekly security report here. Empty for none.
  final String watcherMail;

  /// Closes the app when an attacker hooks the threat callbacks themselves.
  final bool killOnBypass;

  /// Debug builds are skipped by default so `flutter run`, the debugger and
  /// emulators keep working. Set true to try the checks while developing
  /// (debugger and emulator are then reported, so relax the policy).
  final bool runInDebug;

  /// The checking badge is hidden if the engine never reports back.
  final Duration checkTimeout;

  /// Where the runtime checks run. `{ArmorPlatform.android}` runs them on
  /// Android only; iOS then starts without them.
  final Set<ArmorPlatform> platforms;
}
