import 'package:flutter/foundation.dart';

import 'threats.dart';

/// Where the security checks are.
enum ArmorPhase {
  /// Nothing to show: checks are off, or the check mark has gone.
  idle,

  /// The runtime checks are running.
  checking,

  /// The checks finished and nothing was blocked.
  passed,

  /// A blocking threat was found; the app can't be used.
  blocked,
}

/// What AppArmor knows right now. Listen to `AppArmor.status`.
@immutable
class ArmorStatus {
  const ArmorStatus({
    this.phase = ArmorPhase.idle,
    this.blockedBy,
    this.warnings = const {},
  });

  final ArmorPhase phase;

  /// The threat that blocked the app, when [phase] is [ArmorPhase.blocked].
  final ArmorThreat? blockedBy;

  /// Threats found with [ThreatAction.warn]. The app can check these, e.g.
  /// to disable payments on a rooted device instead of blocking the app.
  final Set<ArmorThreat> warnings;

  bool get isBlocked => phase == ArmorPhase.blocked;

  bool hasWarning(ArmorThreat threat) => warnings.contains(threat);

  ArmorStatus copyWith({
    ArmorPhase? phase,
    ArmorThreat? blockedBy,
    Set<ArmorThreat>? warnings,
  }) =>
      ArmorStatus(
        phase: phase ?? this.phase,
        blockedBy: blockedBy ?? this.blockedBy,
        warnings: warnings ?? this.warnings,
      );

  @override
  String toString() =>
      'ArmorStatus(${phase.name}, blockedBy: ${blockedBy?.name}, '
      'warnings: ${warnings.map((w) => w.name).toList()})';
}
