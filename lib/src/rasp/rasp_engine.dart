import 'dart:async';

import 'package:freerasp/freerasp.dart';

import '../config.dart';
import '../threats.dart';

/// The runtime checks behind [RaspConfig]. Replaceable in tests.
abstract class RaspEngine {
  Stream<ArmorThreat> get threats;

  /// Emits once all checks have run (and again after periodic re-checks).
  Stream<void> get checksFinished;

  Future<void> start(RaspConfig config);
}

/// [RaspEngine] backed by freeRASP.
class FreeRaspEngine implements RaspEngine {
  @override
  Stream<ArmorThreat> get threats => Talsec.instance.onThreatDetected
      .map(mapThreat)
      .where((t) => t != null)
      .cast<ArmorThreat>();

  @override
  Stream<void> get checksFinished => Talsec.instance.onRaspExecutionState
      .where((s) => s == RaspExecutionState.allChecksFinished);

  @override
  Future<void> start(RaspConfig config) {
    return Talsec.instance.start(TalsecConfig(
      watcherMail: config.watcherMail,
      isProd: true,
      killOnBypass: config.killOnBypass,
      androidConfig: AndroidConfig(
        packageName: config.androidPackageName,
        signingCertHashes:
            config.androidSigningCertHashes.map(normalizeCertHash).toList(),
        supportedStores: config.androidSupportedStores,
      ),
      iosConfig: IOSConfig(
        bundleIds: config.iosBundleIds,
        teamId: config.iosTeamId,
      ),
    ));
  }

  /// freeRASP wants Base64. Accepts the hex form shown by `keytool` and the
  /// Play Console (`AB:CD:…`) too.
  static String normalizeCertHash(String hash) {
    final String hex = hash.replaceAll(':', '').trim();
    final bool isHex =
        hex.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex);
    return isHex ? hashConverter.fromSha256toBase64(hex) : hash.trim();
  }

  static ArmorThreat? mapThreat(Threat threat) {
    switch (threat) {
      case Threat.hooks:
        return ArmorThreat.hooks;
      case Threat.debug:
        return ArmorThreat.debugger;
      case Threat.privilegedAccess:
        return ArmorThreat.rootOrJailbreak;
      case Threat.simulator:
        return ArmorThreat.emulator;
      case Threat.appIntegrity:
        return ArmorThreat.tampering;
      case Threat.unofficialStore:
        return ArmorThreat.unofficialStore;
      case Threat.passcode:
        return ArmorThreat.noScreenLock;
      case Threat.secureHardwareNotAvailable:
        return ArmorThreat.noSecureHardware;
      case Threat.devMode:
        return ArmorThreat.developerMode;
      case Threat.adbEnabled:
        return ArmorThreat.adbEnabled;
      case Threat.deviceId:
        return ArmorThreat.deviceIdChanged;
      case Threat.deviceBinding:
        return ArmorThreat.deviceBinding;
      case Threat.obfuscationIssues:
        return ArmorThreat.obfuscationIssues;
      case Threat.systemVPN:
        return ArmorThreat.vpn;
      case Threat.multiInstance:
        return ArmorThreat.multiInstance;
      case Threat.unsecureWiFi:
        return ArmorThreat.unsecureWifi;
      case Threat.timeSpoofing:
        return ArmorThreat.timeSpoofing;
      case Threat.locationSpoofing:
        return ArmorThreat.locationSpoofing;
      case Threat.automation:
        return ArmorThreat.automation;
      case Threat.bootloader:
        return ArmorThreat.unlockedBootloader;
      case Threat.screenshot:
        return ArmorThreat.screenshot;
      case Threat.screenRecording:
        return ArmorThreat.screenRecording;
    }
  }
}
