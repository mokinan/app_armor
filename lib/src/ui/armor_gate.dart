import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_armor.dart';
import '../status.dart';
import 'armor_texts.dart';
import 'armor_ui_config.dart';

/// Shows AppArmor's state over the app: a small badge while the checks run,
/// and a full-screen block when a blocking threat is found.
///
/// [AppArmor.run] adds it for you. Otherwise use [AppArmor.builder] in
/// `MaterialApp.builder`, or wrap your app's root.
class ArmorGate extends StatelessWidget {
  const ArmorGate({super.key, required this.child});

  final Widget? child;

  /// Closes the app. `SystemNavigator.pop` does nothing on iOS, so iOS
  /// exits the process instead.
  static void closeApp() {
    if (!kIsWeb && Platform.isIOS) {
      exit(0);
    } else {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: AppArmor.locale,
      builder: (context, armorLocale, _) => _build(context, armorLocale),
    );
  }

  Widget _build(BuildContext context, Locale? armorLocale) {
    final ArmorUiConfig ui = AppArmor.config.ui;
    final Locale locale = Localizations.maybeLocaleOf(context) ??
        armorLocale ??
        WidgetsBinding.instance.platformDispatcher.locale;
    final ArmorTexts texts = ui.texts ?? ArmorTexts.forLocale(locale);

    final Widget gate = ValueListenableBuilder<ArmorStatus>(
      valueListenable: AppArmor.status,
      builder: (context, status, _) {
        final bool top = ui.badgePosition == ArmorBadgePosition.top;
        return Stack(
          textDirection: TextDirection.ltr,
          children: [
            if (child != null) Positioned.fill(child: child!),
            if (status.isBlocked)
              Positioned.fill(
                child: Directionality(
                  textDirection: texts.textDirection,
                  child: _blocked(context, ui, texts, status),
                ),
              )
            else if (ui.showStatusBadge)
              Positioned(
                top: top ? 0 : null,
                bottom: top ? null : 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Directionality(
                          textDirection: texts.textDirection,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: _badge(context, ui, texts, status.phase),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );

    // Works above MaterialApp too, where there is no Directionality yet.
    return Directionality.maybeOf(context) == null
        ? Directionality(textDirection: texts.textDirection, child: gate)
        : gate;
  }

  Widget _blocked(BuildContext context, ArmorUiConfig ui, ArmorTexts texts,
      ArmorStatus status) {
    final details = ArmorBlockedDetails(
      threat: status.blockedBy!,
      texts: texts,
      reason: ui.showBlockReason ? texts.reasons[status.blockedBy!] : null,
      closeApp: closeApp,
    );
    final Widget? custom = ui.blockedScreenBuilder?.call(context, details);
    // Takes every touch, even where a custom screen leaves gaps, and hides
    // the app behind it from screen readers.
    final bool light =
        ThemeData.estimateBrightnessForColor(ui.backgroundColor) ==
            Brightness.light;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Keeps the status bar readable, for custom screens too.
      value: light ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
      child: BlockSemantics(
        child: Listener(
          behavior: HitTestBehavior.opaque,
          child: ColoredBox(
            color: ui.backgroundColor,
            child: custom ?? ArmorBlockedScreen(details: details, ui: ui),
          ),
        ),
      ),
    );
  }

  Widget _badge(BuildContext context, ArmorUiConfig ui, ArmorTexts texts,
      ArmorPhase phase) {
    if (phase != ArmorPhase.checking && phase != ArmorPhase.passed) {
      return const SizedBox.shrink(key: ValueKey('none'));
    }
    final details = ArmorBadgeDetails(phase: phase, texts: texts);
    return KeyedSubtree(
      key: ValueKey(phase),
      child: ui.statusBadgeBuilder?.call(context, details) ??
          ArmorStatusBadge(details: details, ui: ui),
    );
  }
}

/// The built-in checking badge. Use it inside your own
/// `statusBadgeBuilder` to keep the default look and add to it.
class ArmorStatusBadge extends StatelessWidget {
  const ArmorStatusBadge({
    super.key,
    required this.details,
    ArmorUiConfig? ui,
  }) : _ui = ui;

  final ArmorBadgeDetails details;
  final ArmorUiConfig? _ui;

  @override
  Widget build(BuildContext context) {
    // Defaults to the app's AppArmor config, so wrapping keeps its style.
    final ArmorUiConfig ui = _ui ?? AppArmor.config.ui;
    return Material(
      color: ui.badgeColor,
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (details.passed)
              Icon(Icons.verified_user_rounded,
                  size: 18, color: ui.successColor)
            else
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: ui.primaryColor),
              ),
            const SizedBox(width: 10),
            Text(
              details.label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ui.titleColor,
                fontFamily: ui.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The built-in blocked screen. Use it inside your own
/// `blockedScreenBuilder` to keep the default look and add to it.
class ArmorBlockedScreen extends StatelessWidget {
  const ArmorBlockedScreen({
    super.key,
    required this.details,
    ArmorUiConfig? ui,
  }) : _ui = ui;

  final ArmorBlockedDetails details;
  final ArmorUiConfig? _ui;

  @override
  Widget build(BuildContext context) {
    // Defaults to the app's AppArmor config, so wrapping keeps its style.
    final ArmorUiConfig ui = _ui ?? AppArmor.config.ui;
    final ArmorTexts texts = details.texts;
    final String? reason = details.reason;
    // A Material that fills the screen absorbs every touch, so nothing
    // behind it can be used.
    return Material(
      color: ui.backgroundColor,
      textStyle: TextStyle(fontFamily: ui.fontFamily),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            color: ui.primaryColor.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(ui.blockedIcon,
                              size: 60, color: ui.primaryColor),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          texts.blockedTitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: ui.titleColor,
                            fontFamily: ui.fontFamily,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          texts.blockedMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color: ui.messageColor,
                            fontFamily: ui.fontFamily,
                          ),
                        ),
                        if (reason != null) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: ui.primaryColor.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color:
                                      ui.primaryColor.withValues(alpha: 0.2)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.info_outline_rounded,
                                    size: 18, color: ui.primaryColor),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    reason,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: ui.primaryColor,
                                      fontFamily: ui.fontFamily,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              if (ui.showCloseButton)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: details.closeApp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ui.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      texts.closeApp,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        fontFamily: ui.fontFamily,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
