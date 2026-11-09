import 'threats.dart';
import 'ui/armor_ui_config.dart';

/// Everything AppArmor does, in one place. Each part can be turned off by
/// setting it to `null` or `false`.
class ArmorConfig {
  const ArmorConfig({
    this.enabled = true,
    this.policy,
    this.rasp,
    this.privacy = const PrivacyConfig(),
    this.silenceLogsInRelease = true,
    this.ui = const ArmorUiConfig(),
    this.onThreat,
  });

  /// Master switch. When false, [AppArmor.init] does nothing at all.
  final bool enabled;

  /// What to do for each threat. Defaults to [ThreatPolicy.recommended].
  final ThreatPolicy? policy;

  ThreatPolicy get effectivePolicy => policy ?? ThreatPolicy.recommended();

  /// Runtime protection (root, jailbreak, hooks, debugger, emulator,
  /// tampering…). Null turns it off.
  final RaspConfig? rasp;

  /// Screen privacy: app switcher, screenshots, screen recording, tapjacking.
  final PrivacyConfig privacy;

  /// In release builds, `debugPrint` writes nothing, and `print` writes
  /// nothing inside [AppArmor.run], so nothing leaks to Logcat / Console.
  final bool silenceLogsInRelease;

  /// How the checking badge and the blocked screen look.
  final ArmorUiConfig ui;

  /// Called for every threat that is not ignored, e.g. to send it to
  /// analytics or to hide sensitive features on a warning.
  final void Function(ThreatEvent event)? onThreat;
}

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
}

/// Screen privacy options. All are handled natively by AppArmor.
class PrivacyConfig {
  const PrivacyConfig({
    this.hideInAppSwitcher = true,
    this.blockScreenshots = false,
    this.coverWhileRecording = false,
    this.preventTapjacking = true,
    this.detectScreenshots = true,
  });

  /// The app switcher shows a blank card (Android 13+) or a blur (iOS)
  /// instead of a snapshot of the current screen.
  final bool hideInAppSwitcher;

  /// Blocks screenshots and screen recording in the whole app (Android
  /// FLAG_SECURE; also hides it in the app switcher on every Android
  /// version). iOS can't block screenshots: it covers the app while it is
  /// being recorded instead. To protect only some screens, leave this off
  /// and wrap them in `ArmorSecureScreen`.
  final bool blockScreenshots;

  /// iOS: covers the app with a blur while the screen is recorded,
  /// mirrored or cast.
  final bool coverWhileRecording;

  /// Android: ignores touches while another app draws over this one, so
  /// an overlay can't trick the user into tapping something.
  final bool preventTapjacking;

  /// Reports [ArmorThreat.screenshot] (iOS, Android 14+) and
  /// [ArmorThreat.screenRecording] (iOS) through the policy.
  final bool detectScreenshots;

  static const PrivacyConfig off = PrivacyConfig(
    hideInAppSwitcher: false,
    preventTapjacking: false,
    detectScreenshots: false,
  );
}
