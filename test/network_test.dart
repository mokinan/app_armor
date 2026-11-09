import 'dart:convert';

import 'package:app_armor/app_armor.dart';
import 'package:flutter_test/flutter_test.dart';

// Self-signed test certificate; pins computed with openssl.
const String certBase64 =
    'MIIC9DCCAdygAwIBAgIUFKGwIpK4t5pI/6P3P18nKu+bg1owDQYJKoZIhvcNAQELBQAwGjEYMBYGA1UEAwwPYXBpLmV4YW1wbGUuY29tMB4XDTI2MTEwOTE2MTU1OFoXDTM2MTEwNjE2MTU1OFowGjEYMBYGA1UEAwwPYXBpLmV4YW1wbGUuY29tMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAyHsZ8+HUTe8sk4LAZ6Uhf4COXtUFgGKP+PAwiVymDdZ3xKpSk9RdXpm5/PkHF+FzYZt5mogBUTPAxda5piyY+TgX99giUjhaJAUhrMp1YsV54p/vXFa3WA4dqtbOf8aOtGVlWjoB2lvVYMfQLP4D5oduq9LPY5fTWDZfvU7SVcqPGFgJcJfT2wTOW/M9R1VtpXS+cdXxfNQ7I0+gDk4kDh8T+iBZkctvb2+JyNeZjjLEZBg+zV/u7ta+LfUILQ/qPK8cOkQxL0SMkKkHsXxDnMMt0RfQ/5QhnWtrwe6q8q7Vhux0P35KDbWWeOfeohJ+tX3Xq+Dz6AvmbWDszCfnVQIDAQABozIwMDAdBgNVHQ4EFgQUx85xNTiANd+bNrIjU2tD3lslfEgwDwYDVR0TAQH/BAUwAwEB/zANBgkqhkiG9w0BAQsFAAOCAQEAF6lomG40eUzC4o31N/g/YmDpCrJ7bynFZ3Qaxc5nZSy70Em7VhwSu+lAm1lExkSVf8i7I5215rwAj1lXk+hANkG1ZZ5g2dzfPSuhVJkd+R90dqvgcRy4IlhdMBYuK7oJuDp/zcQYIfQwWG0JU4IQwbgi7MGokzBj/mfgLSI1xpEI9SxP4OXjowgwQTwXs4REMz35wuqk++m2+iYTMfH0zo3b7G/BtSN0svWcElY5cMCdS/4dHaBZVoOHFcCUnngEwNNoHkgvZjVdWPxf/E8/Qqs1xliw7RXVosGJC1zvb5Fa+O8h3UlvJINXnvixpmnAlGJZZFU2adxLcBVDpEckSg==';
const String spkiPin = 'sha256/5IR6F/J0PyRW7NBOhBeII+dubqEZ14ENmYZAZqkMCTk=';
const String certPin = 'cert/YaMHon9PgqlvK9xsX4hYW0ep1QQLK/vA9VIhuUgjD54=';

void main() {
  final der = base64.decode(certBase64);

  group('ArmorPinning', () {
    test('reads the public key pin like openssl does', () {
      expect(ArmorPinning.spkiPinOf(der), spkiPin);
    });

    test('matches SPKI and whole-certificate pins', () {
      expect(ArmorPinning.matches(der, [spkiPin]), isTrue);
      expect(ArmorPinning.matches(der, [certPin]), isTrue);
      expect(ArmorPinning.matches(der, ['sha256/AAAA', 'cert/BBBB']), isFalse);
    });

    test('unreadable certificates match nothing', () {
      expect(ArmorPinning.spkiPinOf(base64.decode('AAEC')), isNull);
    });

    test('only pinned hosts are checked', () {
      final pinning = ArmorPinning(pins: {
        'API.example.com': [spkiPin]
      });
      expect(pinning.pinsFor('api.example.com'), [spkiPin]);
      expect(pinning.pinsFor('v2.api.example.com'), isNull);
      expect(pinning.validateCertificate(null, 'cdn.other.com', 443), isTrue);
      expect(
          pinning.validateCertificate(null, 'api.example.com', 443), isFalse);
    });

    test('subdomains are pinned when asked', () {
      final pinning = ArmorPinning(pins: {
        'example.com': [spkiPin]
      }, includeSubdomains: true);
      expect(pinning.pinsFor('api.example.com'), [spkiPin]);
      expect(pinning.pinsFor('badexample.com'), isNull);
    });

    test('disabled pinning accepts everything', () {
      final pinning = ArmorPinning(pins: {
        'api.example.com': [spkiPin]
      }, enabled: false);
      expect(pinning.validateCertificate(null, 'api.example.com', 443), isTrue);
    });
  });

  group('SafeUrls.https', () {
    test('upgrades and adds the scheme', () {
      expect(SafeUrls.https('http://a.com/x').toString(), 'https://a.com/x');
      expect(SafeUrls.https('a.com').toString(), 'https://a.com');
      expect(SafeUrls.https('a.com:8080/p').toString(), 'https://a.com:8080/p');
      expect(SafeUrls.https(' https://a.com ').toString(), 'https://a.com');
    });

    test('rejects other schemes and tricks', () {
      expect(SafeUrls.https('javascript:alert(1)'), isNull);
      expect(SafeUrls.https('file:///etc/passwd'), isNull);
      expect(SafeUrls.https('intent://x#Intent;end'), isNull);
      expect(SafeUrls.https('https://user:pw@evil.com'), isNull);
      expect(SafeUrls.https(''), isNull);
    });
  });

  group('ArmorWebViewPolicy', () {
    final policy = ArmorWebViewPolicy.forSite('https://help.wss.sa/chat');

    test('stays on the site over HTTPS', () {
      expect(policy.decide('https://wss.sa/x'), ArmorNavigation.allow);
      expect(policy.decide('https://a.b.wss.sa'), ArmorNavigation.allow);
      expect(policy.decide('about:blank'), ArmorNavigation.allow);
    });

    test('sends other sites outside, blocks the rest', () {
      expect(
          policy.decide('https://evilwss.sa'), ArmorNavigation.openExternally);
      expect(policy.decide('http://wss.sa'), ArmorNavigation.block);
      expect(policy.decide('tel:123'), ArmorNavigation.openExternally);
      expect(policy.decide('javascript:alert(1)'), ArmorNavigation.block);
    });

    test('leaves frames alone', () {
      expect(policy.decide('https://evil.com', isMainFrame: false),
          ArmorNavigation.allow);
    });
  });
}
