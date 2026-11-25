/// Screen privacy only: app switcher cover, screenshot blocking (whole app
/// or per screen), cover while recording, tapjacking protection and
/// screenshot detection.
///
/// ```dart
/// import 'package:app_armor/screen_protection.dart';
///
/// await ArmorScreenProtection.start(const PrivacyConfig(
///   blockScreenshots: true,
///   platforms: {ArmorPlatform.android}, // optional: Android only
/// ));
///
/// // Or protect a single screen:
/// ArmorSecureScreen(child: PaymentScreen())
/// ```
library;

export 'src/platforms.dart' show ArmorPlatform;
export 'src/privacy/armor_native.dart';
export 'src/privacy/armor_screen_protection.dart';
export 'src/privacy/privacy_config.dart';
export 'src/threats.dart' show ArmorThreat;
export 'src/ui/armor_secure_screen.dart';
