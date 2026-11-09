import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'config.dart';
import 'logging/release_logs.dart';
import 'privacy/armor_native.dart';
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

  /// Overrides `kReleaseMode` in tests.
  @visibleForTesting
  static bool? debugIsRelease;

  static bool get _isRelease => debugIsRelease ?? kReleaseMode;

  static ArmorConfig get config => _config;

  /// Every threat reported since start, oldest first.
  static List<ThreatEvent> get history => List.unmodifiable(_history);

  /// Starts everything turned on in [config]. Safe to call once; later
  /// calls are ignored. Never throws: if a part fails to start, the app
  /// keeps running without it.
  ///
  /// The runtime checks run in the background; this returns as soon as they
  /// are started.
  static Future<void> init(ArmorConfig config, {RaspEngine? engine}) async {
    if (_initialized || !config.enabled) return;
    _initialized = true;
    _config = config;

    if (config.silenceLogsInRelease && _isRelease) ReleaseLogs.silence();

    await _startPrivacy(config.privacy);

    final RaspConfig? rasp = config.rasp;
    if (rasp != null && (_isRelease || rasp.runInDebug) && _raspSupported) {
      await _startRasp(rasp, engine ?? FreeRaspEngine());
    }
  }

  /// Initializes Flutter and AppArmor, then runs [app] inside `ArmorGate`.
  ///
  /// [app] may be async, so other start-up work (Firebase, config…) can
  /// happen there. In release builds `print` is silenced too when
  /// [ArmorConfig.silenceLogsInRelease] is on.
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

    if (config.enabled && config.silenceLogsInRelease && _isRelease) {
      return ReleaseLogs.runSilenced(body);
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
    status.value = s.copyWith(warnings: {...s.warnings}..remove(threat));
  }

  static bool get _raspSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> _startPrivacy(PrivacyConfig privacy) async {
    try {
      await ArmorNative.applyPrivacy(privacy);
      if (privacy.detectScreenshots) {
        _subscriptions
          ..add(ArmorNative.onScreenshot
              .listen((_) => _handle(ArmorThreat.screenshot)))
          ..add(ArmorNative.onScreenCaptureChanged.listen((captured) {
            if (captured) {
              _handle(ArmorThreat.screenRecording);
            } else {
              clearWarning(ArmorThreat.screenRecording);
            }
          }));
      }
    } catch (e) {
      debugPrint('AppArmor: privacy failed to start (${e.runtimeType})');
    }
  }

  static Future<void> _startRasp(RaspConfig rasp, RaspEngine engine) async {
    _onChecksStarted(rasp.checkTimeout);
    try {
      _subscriptions
        ..add(engine.checksFinished.listen((_) => _onChecksFinished()))
        ..add(engine.threats.listen(_handle));
      await engine.start(rasp);
    } catch (e) {
      // Never stop the app because protection failed to start.
      debugPrint('AppArmor: runtime protection failed to start '
          '(${e.runtimeType})');
      _setIdleIf(ArmorPhase.checking);
    }
  }

  static void _handle(ArmorThreat threat) {
    final ThreatAction action = _config.effectivePolicy.actionFor(threat);
    if (action == ThreatAction.ignore) return;

    final ThreatEvent event = ThreatEvent(threat, action, DateTime.now());
    _history.add(event);
    final ArmorStatus s = status.value;

    if (action == ThreatAction.block) {
      _timer?.cancel();
      status.value = s.copyWith(
        phase: ArmorPhase.blocked,
        // Keeps the first reason when several threats arrive.
        blockedBy: s.blockedBy ?? threat,
      );
    } else if (!s.warnings.contains(threat)) {
      status.value = s.copyWith(warnings: {...s.warnings, threat});
    }

    try {
      _config.onThreat?.call(event);
    } catch (e) {
      debugPrint('AppArmor: onThreat threw (${e.runtimeType})');
    }
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
    _config = const ArmorConfig(enabled: false);
    debugIsRelease = null;
    ReleaseLogs.restore();
    locale.value = null;
    status.value = const ArmorStatus();
  }
}
