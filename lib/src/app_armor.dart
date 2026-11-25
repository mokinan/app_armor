import 'dart:async';

import 'package:flutter/widgets.dart';

import 'config.dart';
import 'logging/release_logs.dart';
import 'privacy/armor_native.dart';
import 'privacy/armor_screen_protection.dart';
import 'rasp/armor_rasp.dart';
import 'rasp/rasp_engine.dart';
import 'status.dart';
import 'threats.dart';
import 'ui/armor_gate.dart';

/// Entry point of AppArmor.
///
/// The shortest setup, in `main.dart`:
/// ```dart
/// void main() => AppArmor.run(
///       config: ArmorConfig(rasp: RaspConfig(...)),
///       app: () => const MyApp(),
///     );
/// ```
class AppArmor {
  AppArmor._();

  /// What AppArmor knows right now; rebuilds `ArmorGate`.
  static final ValueNotifier<ArmorStatus> status =
      ValueNotifier(const ArmorStatus());

  /// The language of the badge and blocked screen when [ArmorGate] sits
  /// above `MaterialApp` (as with [run]) and can't see the app's locale.
  /// Null follows the device. Inside `MaterialApp.builder` the app's locale
  /// is used automatically.
  static final ValueNotifier<Locale?> locale = ValueNotifier(null);

  /// Sets [locale], e.g. when the user switches the app's language.
  static void setLocale(Locale? value) => locale.value = value;

  /// How long the check mark stays after the checks pass.
  static const Duration passedBadgeDuration = Duration(seconds: 2);

  static ArmorConfig _config = const ArmorConfig(enabled: false);
  static final List<ThreatEvent> _history = [];
  static final List<StreamSubscription<Object?>> _subscriptions = [];
  static Timer? _timer;
  static bool _initialized = false;
  static RaspEngine? _engine;

  /// True after [init] when AppArmor doesn't run on this platform.
  static bool _off = false;

  /// Whether protection is on now. Starts as [ArmorConfig.enabled] and
  /// changes with [setEnabled].
  static bool _enabled = false;

  /// Set by [setPolicy]; replaces [ArmorConfig.policy].
  static ThreatPolicy? _policy;

  /// Every threat found so far, in order, even while protection is off, so
  /// turning it on (or changing the policy) applies them right away.
  static final Set<ArmorThreat> _detected = {};

  /// The last action sent to `onThreat` for each threat.
  static final Map<ArmorThreat, ThreatAction> _reported = {};

  /// Overrides `kReleaseMode` in tests.
  @visibleForTesting
  static bool? get debugIsRelease => ArmorPlatform.debugIsRelease;

  @visibleForTesting
  static set debugIsRelease(bool? value) =>
      ArmorPlatform.debugIsRelease = value;

  static bool get _isRelease => ArmorPlatform.isRelease;

  static ArmorConfig get config => _config;

  /// Whether protection is running now: [init] was called, the platform is
  /// in [ArmorConfig.platforms], and it is turned on (see [setEnabled]).
  static bool get isEnabled => _initialized && !_off && _enabled;

  /// The policy in use: the one from [setPolicy], or the config's.
  static ThreatPolicy get policy => _policy ?? _config.effectivePolicy;

  /// Every threat reported since start, oldest first.
  static List<ThreatEvent> get history => List.unmodifiable(_history);

  /// Starts everything turned on in [config]. Safe to call once; later
  /// calls are ignored. Never throws: if a part fails to start, the app
  /// keeps running without it.
  ///
  /// With [ArmorConfig.enabled] false nothing starts yet; [setEnabled] can
  /// turn protection on later, e.g. from a remote flag.
  ///
  /// On a platform missing from [ArmorConfig.platforms] nothing starts, not
  /// even with [setEnabled]: `ArmorSecureScreen` does nothing and
  /// [reportThreat] is ignored.
  ///
  /// The runtime checks run in the background; this returns as soon as they
  /// are started.
  static Future<void> init(ArmorConfig config, {RaspEngine? engine}) async {
    if (_initialized) return;
    _initialized = true;
    _config = config;
    _engine = engine;

    if (!ArmorPlatform.isCurrentIn(config.platforms)) {
      _off = true;
      ArmorNative.privacyPlatforms = const {};
      return;
    }

    if (config.privacy.detectScreenshots) {
      _subscriptions
        ..add(ArmorScreenProtection.threats.listen(_handle))
        ..add(ArmorScreenProtection.recordingStopped
            .listen((_) => clearWarning(ArmorThreat.screenRecording)));
    }
    if (config.rasp != null) {
      _subscriptions
        ..add(ArmorRasp.checksFinished.listen((_) => _onChecksFinished()))
        ..add(ArmorRasp.threats.listen(_handle));
    }

    if (config.enabled) {
      await _turnOn();
    } else {
      // Secure screens wait for setEnabled(true) too.
      await ArmorNative.setPrivacyAllowed(false);
    }
  }

  /// Turns protection on or off while the app runs, e.g. from Firebase
  /// Remote Config or Firestore, so a released version can be controlled
  /// remotely:
  /// ```dart
  /// AppArmor.setEnabled(remoteConfig.getBool('armor_enabled'));
  /// ```
  ///
  /// Off: the blocked screen and the badge go away, warnings are cleared,
  /// screen privacy and secure screens stop, and logs are written again.
  /// Threats found meanwhile are kept, not acted on.
  ///
  /// On: everything in the config starts (runtime checks too, if they
  /// haven't started yet), and threats already found apply right away.
  ///
  /// Does nothing before [init] or on a platform missing from
  /// [ArmorConfig.platforms]. The runtime checks can't be stopped once
  /// started; while off, AppArmor only ignores what they find.
  static Future<void> setEnabled(bool enabled) async {
    if (!_initialized || _off || enabled == _enabled) return;
    if (enabled) {
      await _turnOn();
    } else {
      await _turnOff();
    }
  }

  /// Replaces the threat policy while the app runs, e.g. with one read from
  /// remote config by [ThreatPolicy.fromJson]. Threats already found are
  /// judged again: a threat that is no longer `block` unblocks the app.
  /// Null goes back to [ArmorConfig.policy].
  static void setPolicy(ThreatPolicy? policy) {
    _policy = policy;
    if (isEnabled) _applyDetected();
  }

  static Future<void> _turnOn() async {
    _enabled = true;
    if (_config.silenceLogsInRelease && _isRelease) ReleaseLogs.silence();
    await ArmorNative.setPrivacyAllowed(true);
    await ArmorScreenProtection.start(_config.privacy);

    final RaspConfig? rasp = _config.rasp;
    if (rasp != null && !ArmorRasp.isRunning && ArmorRasp.willRun(rasp)) {
      _onChecksStarted(rasp.checkTimeout);
      // Never stops the app if protection fails to start.
      if (!await ArmorRasp.start(rasp, engine: _engine)) {
        _setIdleIf(ArmorPhase.checking);
      }
    }
    _applyDetected();
  }

  static Future<void> _turnOff() async {
    _enabled = false;
    _timer?.cancel();
    _reported.clear();
    status.value = const ArmorStatus();
    ReleaseLogs.restore();
    await ArmorNative.setPrivacyAllowed(false);
    await ArmorScreenProtection.stop();
  }

  /// Initializes Flutter and AppArmor, then runs [app] inside `ArmorGate`.
  ///
  /// [app] may be async, so other start-up work (Firebase, config…) can
  /// happen there. In release builds `print` is silenced too when
  /// [ArmorConfig.silenceLogsInRelease] is on, and while protection is on.
  static Future<void> run({
    required ArmorConfig config,
    required FutureOr<Widget> Function() app,
  }) async {
    Future<void> body() async {
      WidgetsFlutterBinding.ensureInitialized();
      await init(config);
      final Widget root = await app();
      runApp(ArmorGate(child: root));
    }

    if (ArmorPlatform.isCurrentIn(config.platforms) &&
        config.silenceLogsInRelease &&
        _isRelease) {
      // Follows setEnabled: print works again while protection is off.
      return runZoned(body, zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          if (!ReleaseLogs.isSilenced) parent.print(zone, line);
        },
      ));
    }
    return body();
  }

  /// For `MaterialApp.builder` / `GetMaterialApp.builder`, when you call
  /// [init] yourself instead of [run]:
  /// ```dart
  /// MaterialApp(builder: AppArmor.builder())
  /// ```
  /// Pass your own builder as [inner] to keep it (it runs inside the gate).
  static TransitionBuilder builder([TransitionBuilder? inner]) =>
      (context, child) => ArmorGate(
            child: inner == null ? child : inner(context, child),
          );

  /// Reports a threat found by your own checks (e.g. a failed server-side
  /// attestation). It goes through the same policy as built-in threats.
  static void reportThreat(ArmorThreat threat) => _handle(threat);

  /// Closes the app (Android and iOS), e.g. from a custom blocked screen.
  static void closeApp() => ArmorGate.closeApp();

  /// Removes a warning, e.g. when screen recording stops.
  static void clearWarning(ArmorThreat threat) {
    final ArmorStatus s = status.value;
    if (!s.warnings.contains(threat)) return;
    _detected.remove(threat);
    _reported.remove(threat);
    status.value = s.copyWith(warnings: {...s.warnings}..remove(threat));
  }

  static void _handle(ArmorThreat threat) {
    if (_off) return;
    _detected.add(threat);
    if (!_enabled && _initialized) return;

    final ThreatAction action = policy.actionFor(threat);
    if (action == ThreatAction.ignore) return;
    _updateStatus();
    _report(threat, action);
  }

  /// Applies every threat found so far with the current policy, and tells
  /// `onThreat` about the ones whose action changed.
  static void _applyDetected() {
    _updateStatus();
    for (final ArmorThreat t in _detected) {
      final ThreatAction action = policy.actionFor(t);
      if (action == ThreatAction.ignore) {
        _reported.remove(t);
      } else if (_reported[t] != action) {
        _report(t, action);
      }
    }
  }

  static void _report(ArmorThreat threat, ThreatAction action) {
    final ThreatEvent event = ThreatEvent(threat, action, DateTime.now());
    _history.add(event);
    _reported[threat] = action;
    try {
      _config.onThreat?.call(event);
    } catch (e) {
      debugPrint('AppArmor: onThreat threw (${e.runtimeType})');
    }
  }

  /// Rebuilds [status] from the threats found and the current policy.
  static void _updateStatus() {
    final ThreatPolicy p = policy;
    ArmorThreat? blockedBy;
    final Set<ArmorThreat> warnings = {};
    for (final ArmorThreat t in _detected) {
      switch (p.actionFor(t)) {
        case ThreatAction.block:
          // Keeps the first reason when several threats arrive.
          blockedBy ??= t;
        case ThreatAction.warn:
          warnings.add(t);
        case ThreatAction.ignore:
          break;
      }
    }
    final ArmorStatus s = status.value;
    final ArmorPhase phase;
    if (blockedBy != null) {
      _timer?.cancel();
      phase = ArmorPhase.blocked;
    } else {
      phase = s.isBlocked ? ArmorPhase.idle : s.phase;
    }
    status.value =
        ArmorStatus(phase: phase, blockedBy: blockedBy, warnings: warnings);
  }

  static void _onChecksStarted(Duration timeout) {
    if (status.value.isBlocked) return;
    status.value = status.value.copyWith(phase: ArmorPhase.checking);
    _timer?.cancel();
    _timer = Timer(timeout, () => _setIdleIf(ArmorPhase.checking));
  }

  static void _onChecksFinished() {
    // Periodic re-checks report again; only the first run shows the badge.
    if (status.value.phase != ArmorPhase.checking) return;
    status.value = status.value.copyWith(phase: ArmorPhase.passed);
    _timer?.cancel();
    _timer = Timer(passedBadgeDuration, () => _setIdleIf(ArmorPhase.passed));
  }

  static void _setIdleIf(ArmorPhase phase) {
    if (status.value.phase == phase) {
      status.value = status.value.copyWith(phase: ArmorPhase.idle);
    }
  }

  @visibleForTesting
  static Future<void> reset() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    _timer?.cancel();
    _history.clear();
    _initialized = false;
    _off = false;
    _enabled = false;
    _engine = null;
    _policy = null;
    _detected.clear();
    _reported.clear();
    _config = const ArmorConfig(enabled: false);
    debugIsRelease = null;
    ArmorPlatform.debugOverride = null;
    await ArmorRasp.reset();
    ArmorScreenProtection.reset();
    ReleaseLogs.restore();
    locale.value = null;
    status.value = const ArmorStatus();
  }
}
