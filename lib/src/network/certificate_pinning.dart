import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Certificate pinning: the app talks to your API only if the server shows
/// one of the keys you expect, so a proxy with a user-installed or
/// mis-issued certificate can't read the traffic.
///
/// Pins are SHA-256 hashes in Base64, in the same format as OkHttp and
/// Android's network security config:
/// - `sha256/<base64>`: hash of the public key (SPKI). Survives certificate
///   renewals that keep the same key. Recommended.
/// - `cert/<base64>`: hash of the whole certificate. Changes on every
///   renewal.
///
/// Get the SPKI pin of a server:
/// ```sh
/// openssl s_client -connect api.example.com:443 -servername api.example.com </dev/null \
///  | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der \
///  | openssl dgst -sha256 -binary | base64
/// ```
/// Always add a backup pin (the next key, or the CA's intermediate) so a
/// key change does not lock every user out.
///
/// With Dio:
/// ```dart
/// dio.httpClientAdapter = IOHttpClientAdapter(
///   validateCertificate: pinning.validateCertificate,
/// );
/// ```
class ArmorPinning {
  ArmorPinning({
    required Map<String, List<String>> pins,
    this.includeSubdomains = false,
    this.enabled = true,
    this.onPinFailure,
  }) : pins = {
          for (final e in pins.entries) e.key.toLowerCase(): e.value,
        };

  /// Host → accepted pins. Hosts not listed here are not pinned.
  final Map<String, List<String>> pins;

  /// `api.example.com` pins also apply to `v2.api.example.com`.
  final bool includeSubdomains;

  /// Turn off for environments with test certificates.
  final bool enabled;

  /// Called when a pinned host shows an unexpected certificate. Report it:
  /// it is either an attack or a certificate change you need to pin.
  final void Function(String host, String? seenSpkiPin)? onPinFailure;

  /// Matches Dio's `ValidateCertificate`. True when [host] is not pinned or
  /// its certificate matches a pin. Dio has already checked the chain.
  bool validateCertificate(
      X509Certificate? certificate, String host, int port) {
    if (!enabled) return true;
    final List<String>? expected = pinsFor(host);
    if (expected == null) return true;
    if (certificate == null) {
      onPinFailure?.call(host, null);
      return false;
    }
    final bool ok = matches(certificate.der, expected);
    if (!ok) onPinFailure?.call(host, spkiPinOf(certificate.der));
    return ok;
  }

  /// The pins for [host], or null when it is not pinned.
  List<String>? pinsFor(String host) {
    final String h = host.toLowerCase();
    if (pins.containsKey(h)) return pins[h];
    if (!includeSubdomains) return null;
    for (final e in pins.entries) {
      if (h.endsWith('.${e.key}')) return e.value;
    }
    return null;
  }

  /// Whether the DER certificate [der] matches one of [expected].
  static bool matches(Uint8List der, List<String> expected) {
    String? spki;
    String? cert;
    for (final String pin in expected) {
      if (pin.startsWith('sha256/')) {
        spki ??= spkiPinOf(der);
        if (spki == pin) return true;
      } else if (pin.startsWith('cert/')) {
        cert ??= 'cert/${base64.encode(sha256.convert(der).bytes)}';
        if (cert == pin) return true;
      }
    }
    return false;
  }

  /// `sha256/<base64>` of the public key in [der], or null if [der] can't
  /// be read.
  static String? spkiPinOf(Uint8List der) {
    final Uint8List? spki = extractSpki(der);
    if (spki == null) return null;
    return 'sha256/${base64.encode(sha256.convert(spki).bytes)}';
  }

  /// The SubjectPublicKeyInfo of an X.509 certificate, as DER.
  @visibleForTesting
  static Uint8List? extractSpki(Uint8List der) {
    try {
      final _Der cert = _Der.read(der, 0);
      final _Der tbs = _Der.read(der, cert.contentStart);
      int pos = tbs.contentStart;
      // version [0] is optional.
      if (der[pos] == 0xA0) pos = _Der.read(der, pos).end;
      // serialNumber, signature, issuer, validity, subject.
      for (int i = 0; i < 5; i++) {
        pos = _Der.read(der, pos).end;
      }
      final _Der spki = _Der.read(der, pos);
      if (der[pos] != 0x30) return null;
      return Uint8List.sublistView(der, spki.start, spki.end);
    } catch (_) {
      return null;
    }
  }
}

/// One DER element: where it starts, where its content starts, where it ends.
class _Der {
  _Der(this.start, this.contentStart, this.end);

  final int start;
  final int contentStart;
  final int end;

  static _Der read(Uint8List b, int pos) {
    final int start = pos;
    pos++; // tag
    int length = b[pos++];
    if (length & 0x80 != 0) {
      final int count = length & 0x7F;
      if (count == 0 || count > 4) throw const FormatException('DER length');
      length = 0;
      for (int i = 0; i < count; i++) {
        length = (length << 8) | b[pos++];
      }
    }
    final int end = pos + length;
    if (end > b.length) throw const FormatException('DER overflow');
    return _Der(start, pos, end);
  }
}

/// Accepts a self-signed or otherwise invalid certificate from specific
/// hosts only, e.g. a QC server. Every other host keeps normal checks.
///
/// Ignored in release builds unless [allowInRelease] is true, so it can't
/// reach the store build by mistake.
class ArmorDevCertificates extends HttpOverrides {
  ArmorDevCertificates._(this.hosts);

  final Set<String> hosts;

  static void allow(Iterable<String> hosts, {bool allowInRelease = false}) {
    if (kReleaseMode && !allowInRelease) return;
    HttpOverrides.global =
        ArmorDevCertificates._(hosts.map((h) => h.toLowerCase()).toSet());
  }

  /// Removes the override installed by [allow].
  static void clear() {
    if (HttpOverrides.current is ArmorDevCertificates) {
      HttpOverrides.global = null;
    }
  }

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..badCertificateCallback =
            (cert, host, port) => hosts.contains(host.toLowerCase());
}
