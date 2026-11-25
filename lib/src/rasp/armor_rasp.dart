import 'dart:async';

import 'package:flutter/foundation.dart';

import '../platforms.dart';
import '../threats.dart';
import 'rasp_config.dart';
import 'rasp_engine.dart';

/// Runtime protection on its own: root, jailbreak, hooks, debugger,
/// emulator, tampering and the other freeRASP checks, without the gate,
/// the policy or the rest of AppArmor.
///
/// `AppArmor.init` uses it for you. Use it directly only when you want the
/// runtime checks and nothing else, and handle each threat yourself:
/// ```dart
/// import 'package:app_armor/rasp.dart';
///
/// ArmorRasp.threats.listen((threat) => ...);
/// await ArmorRasp.start(const RaspConfig(...));
/// ```
class ArmorRasp {
  ArmorRasp._();

  static final StreamController<ArmorThreat> _threats =
      StreamController<ArmorThreat>.broadcast();
  static final StreamController<void> _finished =
      StreamController<void>.broadcast();
  static final List<StreamSubscription<Object?>> _subscriptions = [];
  static bool _running = false;

  /// Every threat the checks find. Listen before [start] so none is missed.
  static Stream<ArmorThreat> get threats => _threats.stream;

  /// Emits once all checks have run, and again after periodic re-checks.
  static Stream<void> get checksFinished => _finished.stream;

  /// Whether the checks were started.
  static bool get isRunning => _running;

  /// Whether [start] would run the checks here: on Android or iOS, in a
  /// platform of [RaspConfig.platforms], and in a release build unless
  /// [RaspConfig.runInDebug] is on.
  static bool willRun(RaspConfig config) =>
      ArmorPlatform.isCurrentIn(config.platforms) &&
      (ArmorPlatform.isRelease || config.runInDebug);

  /// Starts the checks. Returns true if they started, false if they are
  /// skipped here (see [willRun]), were already started, or failed to start.
  /// Never throws.
  static Future<bool> start(RaspConfig config, {RaspEngine? engine}) async {
    if (_running || !willRun(config)) return false;
    _running = true;
    final RaspEngine e = engine ?? FreeRaspEngine();
    try {
      _subscriptions
        ..add(e.threats.listen(_threats.add))
        ..add(e.checksFinished.listen((_) => _finished.add(null)));
      await e.start(config);
      return true;
    } catch (err) {
      debugPrint('AppArmor: runtime protection failed to start '
          '(${err.runtimeType})');
      await _cancel();
      return false;
    }
  }

  static Future<void> _cancel() async {
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    _running = false;
  }

  /// Stops listening to the engine. For tests.
  static Future<void> reset() => _cancel();
}
