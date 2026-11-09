import 'dart:ui';

import '../threats.dart';

/// Texts shown by AppArmor. Arabic and English are built in; pass your own
/// to `ArmorUiConfig.texts` for other languages.
class ArmorTexts {
  const ArmorTexts({
    required this.checking,
    required this.passed,
    required this.blockedTitle,
    required this.blockedMessage,
    required this.closeApp,
    required this.textDirection,
    this.reasons = const {},
  });

  final String checking;
  final String passed;
  final String blockedTitle;
  final String blockedMessage;
  final String closeApp;
  final TextDirection textDirection;

  /// A short reason per threat, shown under the message.
  final Map<ArmorThreat, String> reasons;

  static ArmorTexts forLocale(Locale? locale) =>
      locale?.languageCode == 'ar' ? arabic : english;

  static const ArmorTexts english = ArmorTexts(
    checking: 'Checking security…',
    passed: 'Device is secure',
    blockedTitle: 'This app can\'t run on this device',
    blockedMessage: 'To protect your data, the app was stopped because a '
        'security risk was found on this device.',
    closeApp: 'Close app',
    textDirection: TextDirection.ltr,
    reasons: {
      ArmorThreat.hooks: 'A tool that tampers with apps is running.',
      ArmorThreat.debugger: 'A debugger is attached to the app.',
      ArmorThreat.rootOrJailbreak: 'The device is rooted or jailbroken.',
      ArmorThreat.emulator: 'The app is running on an emulator.',
      ArmorThreat.tampering: 'This copy of the app was modified. '
          'Please install it from the official store.',
      ArmorThreat.unofficialStore:
          'The app was not installed from an official store.',
      ArmorThreat.noScreenLock: 'The device has no screen lock.',
      ArmorThreat.developerMode: 'Developer options are on.',
      ArmorThreat.adbEnabled: 'USB debugging is on.',
      ArmorThreat.unlockedBootloader: 'The device bootloader is unlocked.',
      ArmorThreat.multiInstance: 'The app is running as a cloned copy.',
      ArmorThreat.timeSpoofing: 'The device time was changed.',
      ArmorThreat.locationSpoofing: 'A fake location app is in use.',
      ArmorThreat.automation: 'An automation tool is controlling the app.',
      ArmorThreat.vpn: 'A VPN is active.',
      ArmorThreat.unsecureWifi: 'The Wi-Fi network is not secure.',
      ArmorThreat.screenRecording: 'The screen is being recorded.',
    },
  );

  static const ArmorTexts arabic = ArmorTexts(
    checking: 'جارٍ التحقق من الأمان…',
    passed: 'الجهاز آمن',
    blockedTitle: 'لا يمكن تشغيل التطبيق على هذا الجهاز',
    blockedMessage: 'حفاظًا على بياناتك، تم إيقاف التطبيق لوجود خطر أمني '
        'على هذا الجهاز.',
    closeApp: 'إغلاق التطبيق',
    textDirection: TextDirection.rtl,
    reasons: {
      ArmorThreat.hooks: 'توجد أداة تعبث بالتطبيقات تعمل على الجهاز.',
      ArmorThreat.debugger: 'يوجد مصحح أخطاء متصل بالتطبيق.',
      ArmorThreat.rootOrJailbreak: 'الجهاز مكسور الحماية (روت / جيلبريك).',
      ArmorThreat.emulator: 'التطبيق يعمل على محاكي.',
      ArmorThreat.tampering:
          'تم تعديل نسخة التطبيق. يرجى تثبيته من المتجر الرسمي.',
      ArmorThreat.unofficialStore: 'لم يتم تثبيت التطبيق من متجر رسمي.',
      ArmorThreat.noScreenLock: 'لا يوجد قفل شاشة على الجهاز.',
      ArmorThreat.developerMode: 'خيارات المطور مفعلة.',
      ArmorThreat.adbEnabled: 'تصحيح أخطاء USB مفعل.',
      ArmorThreat.unlockedBootloader: 'محمل الإقلاع في الجهاز غير مقفل.',
      ArmorThreat.multiInstance: 'التطبيق يعمل كنسخة مستنسخة.',
      ArmorThreat.timeSpoofing: 'تم تغيير وقت الجهاز.',
      ArmorThreat.locationSpoofing: 'يوجد تطبيق موقع وهمي.',
      ArmorThreat.automation: 'توجد أداة أتمتة تتحكم في التطبيق.',
      ArmorThreat.vpn: 'يوجد VPN مفعل.',
      ArmorThreat.unsecureWifi: 'شبكة الواي فاي غير آمنة.',
      ArmorThreat.screenRecording: 'يتم تسجيل الشاشة.',
    },
  );
}
