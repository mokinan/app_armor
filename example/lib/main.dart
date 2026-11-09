import 'package:app_armor/app_armor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Screenshot helpers: `--dart-define=ARMOR_PREVIEW=checking|passed|blocked|custom`
/// and `--dart-define=ARMOR_LANG=ar`.
const String preview = String.fromEnvironment('ARMOR_PREVIEW');
const String lang = String.fromEnvironment('ARMOR_LANG', defaultValue: 'en');

final vault = ArmorVault();

void main() => AppArmor.run(
  config: ArmorConfig(
    // Each part can be removed or turned off on its own.
    rasp: const RaspConfig(
      androidPackageName: 'io.github.mokinan.app_armor_example',
      // SHA-256 of your upload key AND the Google Play signing key.
      androidSigningCertHashes: [
        'AB:CD:EF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:'
            'DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC',
      ],
      iosBundleIds: ['io.github.mokinan.appArmorExample'],
      iosTeamId: 'ABCDE12345',
    ),
    policy: ThreatPolicy.recommended().copyWith({
      // Testers use emulators: report them, don't block.
      ArmorThreat.emulator: ThreatAction.warn,
    }),
    privacy: const PrivacyConfig(
      hideInAppSwitcher: true,
      coverWhileRecording: true,
    ),
    ui: preview == 'custom' ? customUi : const ArmorUiConfig(),
    onThreat: (event) => debugPrint('AppArmor: $event'),
  ),
  app: () {
    // The gate sits above MaterialApp here, so tell it the language.
    AppArmor.setLocale(const Locale(lang));
    _showPreview();
    return const ExampleApp();
  },
);

void _showPreview() {
  switch (preview) {
    case 'checking':
      AppArmor.status.value = const ArmorStatus(phase: ArmorPhase.checking);
    case 'passed':
      AppArmor.status.value = const ArmorStatus(phase: ArmorPhase.passed);
    case 'blocked':
      AppArmor.reportThreat(ArmorThreat.rootOrJailbreak);
    case 'custom':
      AppArmor.reportThreat(ArmorThreat.hooks);
  }
}

/// A fully custom blocked screen, built with `blockedScreenBuilder`.
final customUi = ArmorUiConfig(
  backgroundColor: const Color(0xFF0B1020),
  blockedScreenBuilder: (context, d) => Scaffold(
    backgroundColor: const Color(0xFF0B1020),
    body: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFFEF4444),
                size: 36,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              d.texts.blockedTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              d.reason ?? d.texts.blockedMessage,
              style: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Error code: ${d.threat.name}',
              style: const TextStyle(color: Color(0xFF6B7280)),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: d.closeApp,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF374151)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(d.texts.closeApp),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AppArmor',
      debugShowCheckedModeBanner: false,
      locale: Locale(lang),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF1E5EFF),
        scaffoldBackgroundColor: const Color(0xFFF5F7FB),
      ),
      builder: (context, child) => ArmorSessionGuard(
        inactivityTimeout: const Duration(minutes: 15),
        backgroundTimeout: const Duration(minutes: 5),
        onTimeout: (reason) => debugPrint('Session ended: ${reason.name}'),
        child: child!,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('My Wallet', 'محفظتي')),
        backgroundColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),
      body: ValueListenableBuilder<ArmorStatus>(
        valueListenable: AppArmor.status,
        builder: (context, status, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E5EFF), Color(0xFF6D8BFF)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('Balance', 'الرصيد'),
                    style: TextStyle(color: Colors.white70),
                  ),
                  SizedBox(height: 8),
                  Text(
                    tr('SAR 12,480.00', '12,480.00 ر.س'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.shield_outlined),
                title: Text('Protection: ${status.phase.name}'),
                subtitle: Text(
                  status.warnings.isEmpty
                      ? 'No warnings'
                      : 'Warnings: ${status.warnings.map((w) => w.name).join(', ')}',
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SecretPage())),
              child: Text(
                tr(
                  'Open a screen that blocks screenshots',
                  'شاشة تمنع لقطات الشاشة',
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () async {
                await vault.write('token', 'secret-token');
                final token = await vault.read('token');
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Vault read: $token')));
                }
              },
              child: Text(
                tr('Save and read a secret', 'حفظ وقراءة قيمة سرية'),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => ArmorClipboard.copySensitive(
                '123456',
                clearAfter: const Duration(seconds: 10),
              ),
              child: Text(
                tr(
                  'Copy an OTP (cleared after 10 s)',
                  'نسخ رمز تحقق (يُمسح بعد 10 ثوانٍ)',
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () =>
                  AppArmor.reportThreat(ArmorThreat.rootOrJailbreak),
              child: Text(
                tr('Simulate a blocking threat', 'محاكاة تهديد'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SecretPage extends StatelessWidget {
  const SecretPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ArmorSecureScreen(
      child: Scaffold(
        appBar: AppBar(title: const Text('Card details')),
        body: const Center(child: Text('4111 •••• •••• 1111')),
      ),
    );
  }
}

String tr(String en, String ar) => lang == 'ar' ? ar : en;
