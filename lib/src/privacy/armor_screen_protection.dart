import 'dart:async';

import 'package:flutter/foundation.dart';

import '../platforms.dart';
import '../threats.dart';
import 'armor_native.dart';
import 'privacy_config.dart';

/// Screen privacy on its own: app switcher cover, screenshot blocking,
/// cover while recording, tapjacking protection and screenshot detection,
/// without runtime checks or the rest of AppArmor.
///
/// `AppArmor.init` uses it for you. Use it directly when screen privacy is
/// all you need:
/// ```dart
/// import 'package:app_armor/screen_protection.dart';
///
/// await ArmorScreenProtection.start(
///   const PrivacyConfig(blockScreenshots: true),
/// );
/// ArmorScreenProtection.threats.listen((threat) => ...);
/// ```
class ArmorScreenProtection {
  ArmorScreenProtection._();

  static PrivacyConfig? _config;

  /// The settings passed to [start], or null before it.
  static PrivacyConfig? get config => _config;

  /// Whether [start] would apply [config] here: on Android or iOS, in a
  /// platform of [PrivacyConfig.platforms].
  static bool willRun(PrivacyConfig config) =>
      ArmorPlatform.isCurrentIn(config.platforms);

  /// Applies [config]. Can be called again to change the settings. Returns
  /// false if screen privacy doesn't run here (see [willRun]) or failed.
  /// Never throws.
  static Future<bool> start(PrivacyConfig config) async {
    _config = config;
    try {
      await ArmorNative.applyPrivacy(config);
      return willRun(config);
    } catch (e) {
      debugPrint('AppArmor: privacy failed to start (${e.runtimeType})');
      return false;
    }
  }

  /// Turns every option off.
  static Future<bool> stop() => start(PrivacyConfig.off);

  /// [ArmorThreat.screenshot] when the user takes a screenshot (iOS,
  /// Android 14+) and [ArmorThreat.screenRecording] when recording,
  /// mirroring or casting starts (iOS). Needs
  /// [PrivacyConfig.detectScreenshots].
  static Stream<ArmorThreat> get threats => _onlyWhenDetecting(_merge(
        ArmorNative.onScreenshot.map((_) => ArmorThreat.screenshot),
        ArmorNative.onScreenCaptureChanged
            .where((captured) => captured)
            .map((_) => ArmorThreat.screenRecording),
      ));

  /// Fires when screen recording, mirroring or casting stops (iOS).
  static Stream<void> get recordingStopped => _onlyWhenDetecting(
      ArmorNative.onScreenCaptureChanged.where((captured) => !captured));

  /// Whether the screen is being recorded or mirrored right now (iOS).
  static Future<bool> isScreenCaptured() => ArmorNative.isScreenCaptured();

  static Stream<T> _onlyWhenDetecting<T>(Stream<T> s) => s.where((_) {
        final PrivacyConfig? c = _config;
        return c != null && c.detectScreenshots && willRun(c);
      });

  /// Forgets [config]. For tests.
  static void reset() {
    _config = null;
    ArmorNative.reset();
  }
}

/// Merges two broadcast streams.
Stream<T> _merge<T>(Stream<T> a, Stream<T> b) {
  late StreamController<T> c;
  final List<StreamSubscription<T>> subs = [];
  c = StreamController<T>.broadcast(
    onListen: () => subs
      ..add(a.listen(c.add))
      ..add(b.listen(c.add)),
    onCancel: () async {
      for (final s in subs) {
        await s.cancel();
      }
      subs.clear();
    },
  );
  return c.stream;
}
