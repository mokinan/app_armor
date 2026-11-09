/// Masks secrets before data is logged, shown in a debug tool or sent to a
/// crash reporter.
class LogRedactor {
  const LogRedactor({
    this.sensitiveKeys = defaultSensitiveKeys,
    this.mask = '***',
    this.maskPatterns = true,
  });

  /// Map keys are masked when they contain one of these (case-insensitive).
  /// Words of 4 letters or fewer must be a whole word of the key, so `pin`
  /// masks `pin` and `userPin` but not `shipping`.
  static const List<String> defaultSensitiveKeys = [
    'authorization',
    'password',
    'passwd',
    'token',
    'secret',
    'cookie',
    'apikey',
    'api_key',
    'session',
    'iban',
    'otp',
    'pin',
    'cvv',
    'cvc',
    'card',
  ];

  final List<String> sensitiveKeys;
  final String mask;

  /// Also masks JWTs, `Bearer` tokens and card numbers inside strings.
  final bool maskPatterns;

  static final RegExp _jwt =
      RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+');
  static final RegExp _bearer =
      RegExp(r'(Bearer|Basic)\s+[A-Za-z0-9._~+/=-]+', caseSensitive: false);
  static final RegExp _card = RegExp(r'\b(?:\d[ -]?){12,18}\d\b');

  bool isSensitiveKey(Object? key) {
    final String text = key.toString();
    final String lower = text.toLowerCase();
    // "accessToken", "access_token", "Access-Token" -> access, token
    final Set<String> words = text
        .replaceAllMapped(
            RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}')
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .toSet();
    return sensitiveKeys.any((s) {
      final String word = s.toLowerCase();
      return word.length <= 4 ? words.contains(word) : lower.contains(word);
    });
  }

  /// A deep copy of [value] with sensitive map entries masked. Strings are
  /// passed through [redactText].
  dynamic redact(dynamic value) {
    if (value is Map) {
      return value.map((key, v) =>
          MapEntry(key, isSensitiveKey(key) && v != null ? mask : redact(v)));
    }
    if (value is List) return value.map(redact).toList();
    if (value is String) return redactText(value);
    return value;
  }

  /// [text] with JWTs, bearer tokens and card numbers masked.
  String redactText(String text) {
    if (!maskPatterns) return text;
    return text
        .replaceAllMapped(_bearer, (m) => '${m[1]} $mask')
        .replaceAll(_jwt, mask)
        .replaceAllMapped(_card, (m) {
      final String digits = m[0]!.replaceAll(RegExp(r'[ -]'), '');
      // Only real card numbers, not every long number (invoice ids…).
      if (!_passesLuhn(digits)) return m[0]!;
      return '$mask${digits.substring(digits.length - 4)}';
    });
  }

  static bool _passesLuhn(String digits) {
    int sum = 0;
    bool doubled = false;
    for (int i = digits.length - 1; i >= 0; i--) {
      int d = digits.codeUnitAt(i) - 48;
      if (doubled) {
        d *= 2;
        if (d > 9) d -= 9;
      }
      sum += d;
      doubled = !doubled;
    }
    return sum % 10 == 0;
  }
}
