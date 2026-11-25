import '../platforms.dart';
import '../threats.dart';

/// Screen privacy options. All are handled natively by AppArmor.
class PrivacyConfig {
  const PrivacyConfig({
    this.hideInAppSwitcher = true,
    this.blockScreenshots = false,
    this.coverWhileRecording = false,
    this.preventTapjacking = true,
    this.detectScreenshots = true,
    this.platforms = ArmorPlatform.all,
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
  /// an overlay can't trick the user into tapping something. Screen filter
  /// apps (blue-light, dimmer) also draw over apps, so their users can't
  /// tap while one is on. Turn off if your users rely on them.
  final bool preventTapjacking;

  /// Reports [ArmorThreat.screenshot] (iOS, Android 14+) and
  /// [ArmorThreat.screenRecording] (iOS) through the policy.
  final bool detectScreenshots;

  /// Where screen privacy runs, `ArmorSecureScreen` included. On other
  /// platforms none of the options above is applied.
  final Set<ArmorPlatform> platforms;

  static const PrivacyConfig off = PrivacyConfig(
    hideInAppSwitcher: false,
    preventTapjacking: false,
    detectScreenshots: false,
  );
}
