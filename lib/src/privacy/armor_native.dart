import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../config.dart';

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

  static bool get _supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

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
    if (_secureScreens == 1) await _invoke('setSecureScreen', true);
  }

  static Future<void> popSecureScreen() async {
    if (_secureScreens == 0) return;
    _secureScreens--;
    if (_secureScreens == 0) await _invoke('setSecureScreen', false);
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
