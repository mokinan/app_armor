import 'package:flutter/foundation.dart';

/// A platform AppArmor's protection can run on.
///
/// Every part runs on [all] by default. Pass a smaller set to run it only
/// there, e.g. `platforms: {ArmorPlatform.android}`.
enum ArmorPlatform {
  android,
  ios;

  /// Android and iOS.
  static const Set<ArmorPlatform> all = {android, ios};

  /// Overrides [current] in tests. Null uses the real platform.
  static ArmorPlatform? debugOverride;

  /// Overrides `kReleaseMode` in tests (see [isRelease]).
  static bool? debugIsRelease;

  /// The platform the app runs on, or null on web and desktop, where
  /// AppArmor's protection doesn't run.
  static ArmorPlatform? get current {
    if (debugOverride != null) return debugOverride;
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return null;
    }
  }

  /// Whether [platforms] contains the platform the app runs on.
  static bool isCurrentIn(Set<ArmorPlatform> platforms) {
    final ArmorPlatform? p = current;
    return p != null && platforms.contains(p);
  }

  /// `kReleaseMode`, unless [debugIsRelease] is set.
  static bool get isRelease => debugIsRelease ?? kReleaseMode;
}
