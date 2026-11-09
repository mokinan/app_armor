import 'package:app_armor/app_armor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const redactor = LogRedactor();

  test('masks sensitive keys deeply', () {
    final out = redactor.redact({
      'user': 'kinan',
      'Password': 'p',
      'nested': [
        {'accessToken': 'abc', 'id': 1}
      ],
      'otp': null,
    });
    expect(out, {
      'user': 'kinan',
      'Password': '***',
      'nested': [
        {'accessToken': '***', 'id': 1}
      ],
      'otp': null,
    });
  });

  test('masks tokens and card numbers in text', () {
    expect(redactor.redactText('Authorization: Bearer abc.def-123'),
        'Authorization: Bearer ***');
    expect(redactor.redactText('jwt eyJhbGc.eyJzdWIi.c2lnbmF0dXJl end'),
        'jwt *** end');
    expect(
        redactor.redactText('card 4111 1111 1111 1111 ok'), 'card ***1111 ok');
  });

  test('keeps long numbers that are not cards', () {
    expect(
        redactor.redactText('invoice 1234567890123'), 'invoice 1234567890123');
  });
}
