import 'platforms.dart';
import 'privacy/privacy_config.dart';
import 'rasp/rasp_config.dart';
import 'threats.dart';
import 'ui/armor_ui_config.dart';

export 'platforms.dart' show ArmorPlatform;
export 'privacy/privacy_config.dart';
export 'rasp/rasp_config.dart';

/// Everything AppArmor does, in one place. Each part can be turned off by
/// setting it to `null` or `false`.
class ArmorConfig {
  const ArmorConfig({
    this.enabled = true,
    this.platforms = ArmorPlatform.all,
    this.policy,
    this.rasp,
    this.privacy = const PrivacyConfig(),
    this.silenceLogsInRelease = true,
    this.ui = const ArmorUiConfig(),
    this.onThreat,
  });

  /// Master switch. When false, [AppArmor.init] does nothing at all.
  final bool enabled;

  /// The platforms AppArmor runs on; all of them by default. With
  /// `{ArmorPlatform.android}`, [AppArmor.init] does nothing on iOS, as if
  /// [enabled] were false there.
  ///
  /// [RaspConfig.platforms] and [PrivacyConfig.platforms] narrow it further
  /// for one part, e.g. runtime checks on Android only but screen privacy
  /// everywhere.
  final Set<ArmorPlatform> platforms;

  /// Whether AppArmor runs on the platform the app is running on now.
  bool get runsHere => enabled && ArmorPlatform.isCurrentIn(platforms);

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
