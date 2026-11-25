/// Every threat AppArmor can report.
///
/// Most come from the runtime protection engine (freeRASP); [screenshot] and
/// [screenRecording] are also reported by AppArmor's own native code.
enum ArmorThreat {
  /// Frida, Xposed, Shadow or another hooking framework is attached.
  hooks,

  /// A debugger is attached to the app.
  debugger,

  /// Rooted (Android) or jailbroken (iOS) device.
  rootOrJailbreak,

  /// Running on an emulator or simulator.
  emulator,

  /// The app was modified or re-signed (wrong signing key or bundle id).
  tampering,

  /// Installed from a store that is not in the allowed list (Android).
  unofficialStore,

  /// The device has no screen lock (PIN, pattern, password, biometrics).
  noScreenLock,

  /// The device has no hardware-backed keystore / Secure Enclave.
  noSecureHardware,

  /// Android developer options are on.
  developerMode,

  /// Android USB debugging (ADB) is on.
  adbEnabled,

  /// The app was reinstalled (iOS only).
  deviceIdChanged,

  /// The app was moved to another device or restored from a backup.
  deviceBinding,

  /// The release build is not obfuscated (Android).
  obfuscationIssues,

  /// A system-wide VPN is active.
  vpn,

  /// The app runs as a second instance (app cloners, work profiles).
  multiInstance,

  /// Connected to an open or weakly secured Wi-Fi.
  unsecureWifi,

  /// The device clock was changed.
  timeSpoofing,

  /// A mock location app is in use.
  locationSpoofing,

  /// An automation or accessibility tool is driving the UI.
  automation,

  /// The bootloader is unlocked (Android).
  unlockedBootloader,

  /// The user took a screenshot.
  screenshot,

  /// The screen is being recorded, mirrored or cast.
  screenRecording,
}

/// What AppArmor does when a threat is found.
enum ThreatAction {
  /// Cover the app with the blocked screen. It can't be used any more.
  block,

  /// Let the app run, but report the threat through `onThreat` and
  /// [ArmorStatus.warnings] so the app can react (e.g. hide payments).
  warn,

  /// Do nothing at all, not even report it.
  ignore,
}

/// Which [ThreatAction] each [ArmorThreat] gets.
///
/// Start from a preset and change single threats with [copyWith]:
/// ```dart
/// ThreatPolicy.recommended().copyWith({ArmorThreat.emulator: ThreatAction.warn})
/// ```
class ThreatPolicy {
  const ThreatPolicy(this.actions, {this.fallback = ThreatAction.warn});

  /// The action for each threat. Missing threats get [fallback].
  final Map<ArmorThreat, ThreatAction> actions;

  final ThreatAction fallback;

  /// Blocks attacks on the app itself (hooking, debugging, root, tampering,
  /// emulators); only reports device hygiene issues.
  factory ThreatPolicy.recommended() => const ThreatPolicy({
        ArmorThreat.hooks: ThreatAction.block,
        ArmorThreat.debugger: ThreatAction.block,
        ArmorThreat.rootOrJailbreak: ThreatAction.block,
        ArmorThreat.tampering: ThreatAction.block,
        ArmorThreat.emulator: ThreatAction.block,
        ArmorThreat.automation: ThreatAction.warn,
        ArmorThreat.unofficialStore: ThreatAction.warn,
        ArmorThreat.screenshot: ThreatAction.ignore,
      }, fallback: ThreatAction.warn);

  /// [recommended], and also blocks unofficial stores, unlocked bootloaders,
  /// cloned instances, spoofed time and automation tools. For banking and
  /// payment apps.
  factory ThreatPolicy.strict() => ThreatPolicy.recommended().copyWith({
        ArmorThreat.unofficialStore: ThreatAction.block,
        ArmorThreat.unlockedBootloader: ThreatAction.block,
        ArmorThreat.multiInstance: ThreatAction.block,
        ArmorThreat.timeSpoofing: ThreatAction.block,
        ArmorThreat.automation: ThreatAction.block,
        ArmorThreat.locationSpoofing: ThreatAction.block,
      });

  /// Never blocks; every threat is only reported. Useful to measure how many
  /// users would be affected before turning blocking on.
  factory ThreatPolicy.monitorOnly() =>
      const ThreatPolicy({}, fallback: ThreatAction.warn);

  /// Reads a policy from remote config or Firestore, so it can change
  /// without a new release:
  /// ```json
  /// {"preset": "strict", "fallback": "warn", "emulator": "warn", "vpn": "ignore"}
  /// ```
  /// `preset` is `recommended`, `strict` or `monitorOnly` (else [base],
  /// [ThreatPolicy.recommended] by default). Other keys are [ArmorThreat]
  /// names, values are [ThreatAction] names. Unknown keys and values are
  /// skipped, so older app versions keep working when new threats are added.
  factory ThreatPolicy.fromJson(Map<String, Object?> json,
      {ThreatPolicy? base}) {
    final ThreatPolicy policy = switch (json['preset']) {
      'recommended' => ThreatPolicy.recommended(),
      'strict' => ThreatPolicy.strict(),
      'monitorOnly' => ThreatPolicy.monitorOnly(),
      _ => base ?? ThreatPolicy.recommended(),
    };
    final ThreatAction? fallback = _action(json['fallback']);
    final Map<ArmorThreat, ThreatAction> overrides = {};
    for (final ArmorThreat t in ArmorThreat.values) {
      final ThreatAction? a = _action(json[t.name]);
      if (a != null) overrides[t] = a;
    }
    return policy.copyWith(overrides, fallback: fallback);
  }

  static ThreatAction? _action(Object? name) {
    for (final ThreatAction a in ThreatAction.values) {
      if (a.name == name) return a;
    }
    return null;
  }

  /// The opposite of [ThreatPolicy.fromJson].
  Map<String, String> toJson() => {
        'fallback': fallback.name,
        for (final MapEntry<ArmorThreat, ThreatAction> e in actions.entries)
          e.key.name: e.value.name,
      };

  ThreatAction actionFor(ArmorThreat threat) => actions[threat] ?? fallback;

  /// A copy with [overrides] replacing the actions of those threats.
  ThreatPolicy copyWith(Map<ArmorThreat, ThreatAction> overrides,
          {ThreatAction? fallback}) =>
      ThreatPolicy({...actions, ...overrides},
          fallback: fallback ?? this.fallback);

  /// A copy where every threat in [threats] is ignored.
  ThreatPolicy ignoring(Iterable<ArmorThreat> threats) =>
      copyWith({for (final t in threats) t: ThreatAction.ignore});
}

/// One detected threat and what was done about it.
class ThreatEvent {
  const ThreatEvent(this.threat, this.action, this.time);

  final ArmorThreat threat;
  final ThreatAction action;
  final DateTime time;

  @override
  String toString() => 'ThreatEvent(${threat.name}, ${action.name})';
}
