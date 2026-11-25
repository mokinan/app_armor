import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../platforms.dart';
import 'privacy_config.dart';

/// Talks to AppArmor's Android and iOS code.
class ArmorNative {
  ArmorNative._();

  static const MethodChannel _channel = MethodChannel('app_armor');

  static final StreamController<void> _screenshots =
      StreamController<void>.broadcast();
  static final StreamController<bool> _capture =
      StreamController<bool>.broadcast();

  static bool _listening = false;
  static int _secureScreens = 0;

  /// Where screen privacy may run, from [PrivacyConfig.platforms]. Elsewhere
  /// [applyPrivacy] and secure screens do nothing.
  static Set<ArmorPlatform> privacyPlatforms = ArmorPlatform.all;

  static bool _privacyAllowed = true;

  static bool get _privacyHere =>
      _privacyAllowed && ArmorPlatform.isCurrentIn(privacyPlatforms);

  /// Pauses (false) or resumes (true) secure screens, e.g. when protection
  /// is turned off remotely while one is shown.
  static Future<void> setPrivacyAllowed(bool allowed) async {
    final bool before = _privacyHere;
    _privacyAllowed = allowed;
    final bool after = _privacyHere;
    if (_secureScreens > 0 && before != after) {
      await _invoke('setSecureScreen', after);
    }
  }

  /// Fires when the user takes a screenshot (iOS, Android 14+).
  static Stream<void> get onScreenshot {
    _listen();
    return _screenshots.stream;
  }

  /// Fires with true when screen recording / mirroring starts, false when
  /// it stops (iOS).
  static Stream<bool> get onScreenCaptureChanged {
    _listen();
    return _capture.stream;
  }

  static bool get _supported => ArmorPlatform.current != null;

  static void _listen() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'screenshotTaken':
          _screenshots.add(null);
        case 'captureChanged':
          _capture.add(call.arguments == true);
      }
    });
  }

  static Future<void> applyPrivacy(PrivacyConfig config) async {
    privacyPlatforms = config.platforms;
    if (!ArmorPlatform.isCurrentIn(privacyPlatforms)) return;
    _listen();
    await _invoke('configure', {
      'hideInAppSwitcher': config.hideInAppSwitcher,
      'blockScreenshots': config.blockScreenshots,
      'coverWhileRecording': config.coverWhileRecording,
      'preventTapjacking': config.preventTapjacking,
      'detectScreenshots': config.detectScreenshots,
    });
  }

  /// Turns screenshot blocking on while at least one secure screen is shown.
  static Future<void> pushSecureScreen() async {
    _secureScreens++;
    if (_secureScreens == 1 && _privacyHere) {
      await _invoke('setSecureScreen', true);
    }
  }

  static Future<void> popSecureScreen() async {
    if (_secureScreens == 0) return;
    _secureScreens--;
    if (_secureScreens == 0 && _privacyHere) {
      await _invoke('setSecureScreen', false);
    }
  }

  /// For tests.
  static void reset() {
    privacyPlatforms = ArmorPlatform.all;
    _privacyAllowed = true;
    _secureScreens = 0;
  }

  /// Whether the screen is being recorded or mirrored right now (iOS).
  static Future<bool> isScreenCaptured() async =>
      await _invoke<bool>('isScreenCaptured') ?? false;

  /// True the first time it is called after the app is installed (or
  /// reinstalled), false after that.
  static Future<bool> consumeFirstRun() async =>
      await _invoke<bool>('consumeFirstRun') ?? false;

  static Future<T?> _invoke<T>(String method, [Object? args]) async {
    if (!_supported) return null;
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('AppArmor: $method failed (${e.code})');
      return null;
    }
  }
}
