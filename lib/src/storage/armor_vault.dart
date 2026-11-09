import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../privacy/armor_native.dart';

/// Reads a value from the old, insecure storage (SharedPreferences,
/// GetStorage, Hive…). Used once to move it into the vault.
typedef LegacyRead = FutureOr<String?> Function(String key);
typedef LegacyRemove = FutureOr<void> Function(String key);

/// Secure key-value storage for tokens, passwords and other secrets, kept in
/// the iOS Keychain / Android Keystore.
///
/// - Values never leave the device: they are not in iCloud Keychain or
///   backups (`unlocked_this_device` on iOS).
/// - [clearOnReinstall]: the iOS Keychain survives uninstalling the app;
///   with this on, a fresh install starts empty.
/// - [legacyRead]/[legacyRemove]: values still in plain-text storage are
///   moved into the vault the first time they are read, then erased.
/// - Never throws: a failed read returns null, a failed write is logged.
class ArmorVault {
  ArmorVault({
    FlutterSecureStorage? storage,
    this.clearOnReinstall = true,
    this.legacyRead,
    this.legacyRemove,
  }) : _storage = storage ??
            const FlutterSecureStorage(
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.unlocked_this_device,
                synchronizable: false,
              ),
            );

  final FlutterSecureStorage _storage;
  final bool clearOnReinstall;
  final LegacyRead? legacyRead;
  final LegacyRemove? legacyRemove;

  Future<void>? _ready;

  Future<void> _ensureReady() => _ready ??= _prepare();

  Future<void> _prepare() async {
    if (!clearOnReinstall) return;
    try {
      if (await ArmorNative.consumeFirstRun()) await _storage.deleteAll();
    } catch (e) {
      _log('prepare', e);
    }
  }

  Future<String?> read(String key) async {
    await _ensureReady();
    try {
      final String? value = await _storage.read(key: key);
      if (value != null || legacyRead == null) return value;
      final String? legacy = await legacyRead!(key);
      if (legacy == null) return null;
      await _storage.write(key: key, value: legacy);
      await legacyRemove?.call(key);
      return legacy;
    } catch (e) {
      _log('read', e);
      return null;
    }
  }

  /// Saves [value], or deletes the key when it is null. Any plain-text copy
  /// left in the legacy storage is removed either way.
  Future<void> write(String key, String? value) async {
    await _ensureReady();
    try {
      await legacyRemove?.call(key);
      if (value == null) {
        await _storage.delete(key: key);
      } else {
        await _storage.write(key: key, value: value);
      }
    } catch (e) {
      _log('write', e);
    }
  }

  Future<void> delete(String key) => write(key, null);

  /// Removes everything, e.g. on logout.
  Future<void> clear() async {
    await _ensureReady();
    try {
      await _storage.deleteAll();
    } catch (e) {
      _log('clear', e);
    }
  }

  static void _log(String operation, Object error) {
    // Only the error type: messages from platform storage may echo values.
    debugPrint('ArmorVault: $operation failed (${error.runtimeType})');
  }
}
