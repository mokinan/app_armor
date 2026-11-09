import 'package:flutter/material.dart';

import '../status.dart';
import '../threats.dart';
import 'armor_texts.dart';

/// Where the checking badge appears.
enum ArmorBadgePosition { top, bottom }

/// What a custom blocked screen needs to draw itself.
class ArmorBlockedDetails {
  const ArmorBlockedDetails({
    required this.threat,
    required this.texts,
    required this.reason,
    required this.closeApp,
  });

  /// The threat that blocked the app.
  final ArmorThreat threat;

  /// The texts for the current language.
  final ArmorTexts texts;

  /// A short, translated reason for [threat], or null when
  /// [ArmorUiConfig.showBlockReason] is off or no text exists for it.
  final String? reason;

  /// Closes the app on Android and iOS. Use it for your own close button.
  final VoidCallback closeApp;
}

/// What a custom checking badge needs to draw itself.
class ArmorBadgeDetails {
  const ArmorBadgeDetails({required this.phase, required this.texts});

  /// [ArmorPhase.checking] or [ArmorPhase.passed].
  final ArmorPhase phase;

  final ArmorTexts texts;

  bool get passed => phase == ArmorPhase.passed;

  /// The text for [phase], e.g. "Checking security…".
  String get label => passed ? texts.passed : texts.checking;
}

/// The look of `ArmorGate`: the checking badge and the blocked screen.
///
/// Change colors, icon and font here, or replace either part completely
/// with [blockedScreenBuilder] / [statusBadgeBuilder].
class ArmorUiConfig {
  const ArmorUiConfig({
    this.showStatusBadge = true,
    this.showBlockReason = true,
    this.showCloseButton = true,
    this.texts,
    this.primaryColor = const Color(0xFF1E5EFF),
    this.successColor = const Color(0xFF16A34A),
    this.backgroundColor = Colors.white,
    this.titleColor = const Color(0xFF111827),
    this.messageColor = const Color(0xFF6B7280),
    this.badgeColor = Colors.white,
    this.blockedIcon = Icons.gpp_bad_outlined,
    this.fontFamily,
    this.badgePosition = ArmorBadgePosition.top,
    this.blockedScreenBuilder,
    this.statusBadgeBuilder,
  });

  /// A small "Checking security…" badge while checks run, then a check mark
  /// for two seconds.
  final bool showStatusBadge;

  /// The blocked screen names the threat (e.g. "The device is rooted").
  final bool showBlockReason;

  final bool showCloseButton;

  /// Texts to use. Defaults to Arabic or English by the app's locale.
  final ArmorTexts? texts;

  /// Icon, reason and button color; the spinner of the badge.
  final Color primaryColor;

  /// The check mark of the badge.
  final Color successColor;

  final Color backgroundColor;
  final Color titleColor;
  final Color messageColor;
  final Color badgeColor;
  final IconData blockedIcon;

  /// Font for the badge and the blocked screen. Null uses the app's font.
  final String? fontFamily;

  final ArmorBadgePosition badgePosition;

  /// Replaces the built-in blocked screen. It fills the whole screen and
  /// should not let the user reach the app behind it:
  /// ```dart
  /// blockedScreenBuilder: (context, d) => Scaffold(
  ///   body: Center(child: Text(d.reason ?? d.texts.blockedTitle)),
  ///   bottomNavigationBar: TextButton(
  ///       onPressed: d.closeApp, child: Text(d.texts.closeApp)),
  /// ),
  /// ```
  /// Wrap [ArmorBlockedScreen] to only add something around the default.
  final Widget Function(BuildContext context, ArmorBlockedDetails details)?
      blockedScreenBuilder;

  /// Replaces the built-in checking badge. Shown only while checking and
  /// for two seconds after the checks pass:
  /// ```dart
  /// statusBadgeBuilder: (context, d) => Chip(label: Text(d.label)),
  /// ```
  final Widget Function(BuildContext context, ArmorBadgeDetails details)?
      statusBadgeBuilder;
}
