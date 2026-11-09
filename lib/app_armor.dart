/// All-in-one mobile security for Flutter apps.
///
/// ```dart
/// void main() => AppArmor.run(
///       config: ArmorConfig(
///         rasp: RaspConfig(
///           androidPackageName: 'com.company.app',
///           androidSigningCertHashes: ['<SHA-256 of signing key>'],
///           iosBundleIds: ['com.company.app'],
///           iosTeamId: 'ABCDE12345',
///         ),
///       ),
///       app: () => const MyApp(),
///     );
/// ```
library;

export 'src/app_armor.dart' show AppArmor;
export 'src/clipboard/armor_clipboard.dart';
export 'src/config.dart';
export 'src/logging/log_redactor.dart';
export 'src/logging/release_logs.dart';
export 'src/network/certificate_pinning.dart';
export 'src/network/safe_urls.dart';
export 'src/privacy/armor_native.dart';
export 'src/rasp/rasp_engine.dart' show RaspEngine;
export 'src/session/armor_session_guard.dart';
export 'src/status.dart';
export 'src/storage/armor_vault.dart';
export 'src/threats.dart';
export 'src/ui/armor_gate.dart';
export 'src/ui/armor_secure_screen.dart';
export 'src/ui/armor_texts.dart';
export 'src/ui/armor_ui_config.dart';
