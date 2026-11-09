## 0.1.1

- iOS: the app switcher blur now also works in apps that use UIScene.
- `LogRedactor`: short key words (`pin`, `otp`, `card`, `cvv`…) only match
  whole words, so keys like `shipping` or `discard` are no longer masked.
- Docs: adding `ArmorVault` to an existing app, and tapjacking protection
  with screen filter apps.

## 0.1.0

First release.

- Runtime protection (freeRASP): hooks, debugger, root/jailbreak, emulator,
  tampering, unofficial store and 16 more checks, each with its own
  block / warn / ignore action and ready-made policies.
- `ArmorGate`: checking badge and blocked screen, Arabic and English.
  Restyle them (colors, icon, font, badge position) or replace them with
  `blockedScreenBuilder` / `statusBadgeBuilder`. `AppArmor.setLocale`
  picks the language when the gate sits above `MaterialApp`.
- Screen privacy: app switcher blur/blank card, screenshot blocking
  (whole app or per screen), cover while recording, tapjacking protection,
  screenshot detection.
- `ArmorVault`: Keychain/Keystore storage, migrates plain-text values,
  clears on reinstall.
- `ArmorPinning`: SPKI and certificate pinning for Dio.
- `ArmorWebViewPolicy`, `SafeUrls`, `ArmorDevCertificates`.
- `LogRedactor` and silent logs in release builds.
- `ArmorSessionGuard`: inactivity and background timeouts.
- `ArmorClipboard`: copies secrets and clears them later.
- `dart run app_armor`: Android backup rules, HTTPS-only network config,
  release build checks.
