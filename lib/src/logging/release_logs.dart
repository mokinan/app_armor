import 'dart:async';

import 'package:flutter/foundation.dart';

/// Keeps release builds from writing to the device log (Logcat / Console),
/// where other apps, USB debugging and bug reports can read it.
class ReleaseLogs {
  ReleaseLogs._();

  static DebugPrintCallback? _original;

  /// Makes `debugPrint` a no-op for the rest of the app's life.
  static void silence() {
    _original ??= debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  /// Undoes [silence].
  static void restore() {
    if (_original == null) return;
    debugPrint = _original!;
    _original = null;
  }

  /// Runs [body] in a zone where `print` writes nothing.
  static R runSilenced<R>(R Function() body) => runZoned(
        body,
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {},
        ),
      );
}
