import 'dart:async';

import 'package:flutter/services.dart';

/// Copies secrets (OTP, IBAN, payment links…) and removes them from the
/// clipboard after a while, so other apps can't read them later.
class ArmorClipboard {
  ArmorClipboard._();

  static Timer? _timer;

  /// Copies [text] and clears the clipboard after [clearAfter], unless the
  /// user copied something else in the meantime.
  static Future<void> copySensitive(
    String text, {
    Duration clearAfter = const Duration(seconds: 60),
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    _timer?.cancel();
    _timer = Timer(clearAfter, () async {
      try {
        final ClipboardData? now =
            await Clipboard.getData(Clipboard.kTextPlain);
        if (now?.text == text) {
          await Clipboard.setData(const ClipboardData(text: ''));
        }
      } catch (_) {}
    });
  }
}
