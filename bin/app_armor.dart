// Applies AppArmor's native hardening to the Flutter app in the current
// folder. Run from the app's root:
//
//   dart run app_armor            apply everything
//   dart run app_armor --check    only report, change nothing
//
// Each step can be skipped:
//   --no-backup        keep Android backups as they are
//   --no-network       keep Android network settings as they are
//   --debug-user-certs trust user-installed certificates in debug builds
//                      (for Charles / Proxyman while developing)
//   --force            replace attributes the manifest already sets
import 'dart:io';

const String _backupFile = 'app_armor_backup_rules';
const String _extractionFile = 'app_armor_data_extraction_rules';
const String _networkFile = 'app_armor_network_security_config';

final List<String> _done = [];
final List<String> _warnings = [];

void main(List<String> args) {
  if (args.contains('-h') || args.contains('--help')) {
    stdout.writeln(_help);
    return;
  }
  final bool check = args.contains('--check');
  final bool force = args.contains('--force');
  final bool backup = !args.contains('--no-backup');
  final bool network = !args.contains('--no-network');
  final bool debugUserCerts = args.contains('--debug-user-certs');

  if (!File('pubspec.yaml').existsSync()) {
    stderr.writeln('Run this from the root of your Flutter app.');
    exitCode = 64;
    return;
  }

  _android(
      check: check,
      force: force,
      backup: backup,
      network: network,
      debugUserCerts: debugUserCerts);
  _ios();
  _release();

  stdout.writeln(check ? '\nAppArmor check\n' : '\nAppArmor setup\n');
  for (final line in _done) {
    stdout.writeln('  ✓ $line');
  }
  for (final line in _warnings) {
    stdout.writeln('  ! $line');
  }
  stdout.writeln('');
}

void _android({
  required bool check,
  required bool force,
  required bool backup,
  required bool network,
  required bool debugUserCerts,
}) {
  final File manifest = File('android/app/src/main/AndroidManifest.xml');
  if (!manifest.existsSync()) {
    _warnings.add('Android: AndroidManifest.xml not found, skipped.');
    return;
  }
  String xml = manifest.readAsStringSync();
  final Map<String, String> attributes = {};

  if (backup) {
    attributes['android:allowBackup'] = 'false';
    attributes['android:fullBackupContent'] = '@xml/$_backupFile';
    attributes['android:dataExtractionRules'] = '@xml/$_extractionFile';
    if (!check) {
      _writeXml(_backupFile, _backupRules);
      _writeXml(_extractionFile, _extractionRules);
    }
  }
  if (network) {
    attributes['android:networkSecurityConfig'] = '@xml/$_networkFile';
    if (!check) {
      _writeXml(_networkFile, _networkConfig(debugUserCerts), overwrite: true);
    }
    if (RegExp(r'android:usesCleartextTraffic\s*=\s*"true"').hasMatch(xml)) {
      _warnings.add('Android: usesCleartextTraffic="true" allows plain HTTP. '
          'Remove it; the network config already blocks HTTP.');
    }
  }

  final RegExpMatch? app = RegExp(r'<application\b[^>]*>').firstMatch(xml);
  if (app == null) {
    _warnings.add('Android: <application> tag not found.');
    return;
  }
  String tag = app[0]!;
  for (final MapEntry(key: name, value: value) in attributes.entries) {
    final RegExp existing = RegExp('$name\\s*=\\s*"([^"]*)"');
    final RegExpMatch? m = existing.firstMatch(tag);
    if (m != null && m[1] == value) {
      _done.add('Android: $name="$value" already set.');
    } else if (m != null && !force) {
      _warnings.add('Android: $name is "${m[1]}", expected "$value". '
          'Kept (use --force to replace).');
    } else if (check) {
      _warnings.add('Android: $name="$value" is missing.');
    } else {
      tag = m != null
          ? tag.replaceFirst(existing, '$name="$value"')
          : tag.replaceFirst(RegExp(r'\s*>$'), '\n        $name="$value">');
      _done.add('Android: set $name="$value".');
    }
  }
  if (!check) {
    xml = xml.replaceRange(app.start, app.end, tag);
    manifest.writeAsStringSync(xml);
  }
}

void _writeXml(String name, String content, {bool overwrite = false}) {
  final File file = File('android/app/src/main/res/xml/$name.xml');
  if (file.existsSync() && !overwrite) return;
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(content);
  _done.add('Android: wrote res/xml/$name.xml.');
}

void _ios() {
  final File plist = File('ios/Runner/Info.plist');
  if (!plist.existsSync()) return;
  final String text = plist.readAsStringSync();
  if (RegExp(r'<key>NSAllowsArbitraryLoads</key>\s*<true/>').hasMatch(text)) {
    _warnings.add('iOS: NSAllowsArbitraryLoads is true, so plain HTTP is '
        'allowed. Remove it, or use NSExceptionDomains for single hosts.');
  } else {
    _done.add('iOS: App Transport Security is on (HTTPS only).');
  }
}

void _release() {
  _warnings.add('Build releases obfuscated, and keep the symbols for crash '
      'reports:\n      flutter build appbundle --obfuscate '
      '--split-debug-info=build/symbols\n      flutter build ipa --obfuscate '
      '--split-debug-info=build/symbols');
  final File gradle = File('android/app/build.gradle.kts').existsSync()
      ? File('android/app/build.gradle.kts')
      : File('android/app/build.gradle');
  if (gradle.existsSync() &&
      !RegExp(r'isMinifyEnabled\s*=\s*true|minifyEnabled\s+true')
          .hasMatch(gradle.readAsStringSync())) {
    _warnings.add('Android: R8 is off for release. Turn on minify and '
        'shrinkResources in ${gradle.path} to strip and obfuscate Java/Kotlin.');
  }
}

const String _backupRules = '''<?xml version="1.0" encoding="utf-8"?>
<!-- AppArmor, Android 11 and older: keep app data (tokens, settings) out of
     backups. Same rules as $_extractionFile.xml. -->
<full-backup-content>
    <exclude domain="root" />
    <exclude domain="file" />
    <exclude domain="database" />
    <exclude domain="sharedpref" />
    <exclude domain="external" />
</full-backup-content>
''';

const String _extractionRules = '''<?xml version="1.0" encoding="utf-8"?>
<!-- AppArmor, Android 12+: keep app data out of cloud backups and
     device-to-device transfers. -->
<data-extraction-rules>
    <cloud-backup>
        <exclude domain="root" />
        <exclude domain="file" />
        <exclude domain="database" />
        <exclude domain="sharedpref" />
        <exclude domain="external" />
    </cloud-backup>
    <device-transfer>
        <exclude domain="root" />
        <exclude domain="file" />
        <exclude domain="database" />
        <exclude domain="sharedpref" />
        <exclude domain="external" />
    </device-transfer>
</data-extraction-rules>
''';

String _networkConfig(bool debugUserCerts) =>
    '''<?xml version="1.0" encoding="utf-8"?>
<!-- AppArmor: HTTPS only, and only the system's trusted certificates.
     Certificates the user installs (used to intercept traffic) are not
     trusted. -->
<network-security-config>
    <base-config cleartextTrafficPermitted="false">
        <trust-anchors>
            <certificates src="system" />
        </trust-anchors>
    </base-config>${debugUserCerts ? '''

    <!-- Debug builds only: allow a proxy like Charles or Proxyman. -->
    <debug-overrides>
        <trust-anchors>
            <certificates src="user" />
        </trust-anchors>
    </debug-overrides>''' : ''}
</network-security-config>
''';

const String _help = '''
Applies AppArmor's native hardening to the Flutter app in this folder.

  dart run app_armor [options]

  --check             report only, change nothing
  --no-backup         don't change Android backup settings
  --no-network        don't change Android network settings
  --debug-user-certs  trust user certificates in debug builds (proxies)
  --force             replace manifest attributes that are already set
''';
