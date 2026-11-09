import 'dart:async';

import 'package:flutter/widgets.dart';

/// Why the session timed out.
enum SessionTimeoutReason {
  /// No touch for [ArmorSessionGuard.inactivityTimeout].
  inactivity,

  /// The app stayed in the background longer than
  /// [ArmorSessionGuard.backgroundTimeout].
  background,
}

/// Ends the session when the user leaves the app idle or in the background
/// for too long. AppArmor only reports the timeout; [onTimeout] decides what
/// happens (log out, ask for biometrics, show a "still there?" sheet…).
///
/// Put it above your app, e.g. in `MaterialApp.builder`:
/// ```dart
/// builder: (context, child) => ArmorSessionGuard(
///   inactivityTimeout: const Duration(minutes: 15),
///   backgroundTimeout: const Duration(minutes: 5),
///   onTimeout: (reason) => auth.logout(),
///   child: child!,
/// ),
/// ```
class ArmorSessionGuard extends StatefulWidget {
  const ArmorSessionGuard({
    super.key,
    required this.child,
    required this.onTimeout,
    this.inactivityTimeout,
    this.backgroundTimeout,
    this.enabled = true,
    this.onActivity,
  });

  final Widget child;

  final void Function(SessionTimeoutReason reason) onTimeout;

  /// Null turns the inactivity timer off.
  final Duration? inactivityTimeout;

  /// Null turns the background timer off. Zero locks on every return.
  final Duration? backgroundTimeout;

  /// Turn off while signed out, so the guard doesn't fire on the login page.
  final bool enabled;

  /// Called on every touch, e.g. to refresh a token that is about to expire.
  final VoidCallback? onActivity;

  @override
  State<ArmorSessionGuard> createState() => _ArmorSessionGuardState();
}

class _ArmorSessionGuardState extends State<ArmorSessionGuard>
    with WidgetsBindingObserver {
  Timer? _timer;
  DateTime? _backgroundSince;
  DateTime _lastActivity = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _restart();
  }

  @override
  void didUpdateWidget(ArmorSessionGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled ||
        oldWidget.inactivityTimeout != widget.inactivityTimeout) {
      _restart();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void _restart() {
    _lastActivity = DateTime.now();
    _schedule();
  }

  /// Starts the inactivity timer for the time left since the last touch.
  void _schedule() {
    _timer?.cancel();
    final Duration? timeout = widget.inactivityTimeout;
    if (!widget.enabled || timeout == null) return;
    final Duration left = timeout - DateTime.now().difference(_lastActivity);
    if (left <= Duration.zero) {
      _fire(SessionTimeoutReason.inactivity);
      return;
    }
    _timer = Timer(left, () => _fire(SessionTimeoutReason.inactivity));
  }

  void _fire(SessionTimeoutReason reason) {
    _timer?.cancel();
    if (widget.enabled) widget.onTimeout(reason);
  }

  void _onPointer(PointerEvent _) {
    if (!widget.enabled) return;
    _restart();
    widget.onActivity?.call();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _backgroundSince ??= DateTime.now();
      case AppLifecycleState.resumed:
        final DateTime? since = _backgroundSince;
        _backgroundSince = null;
        final Duration? limit = widget.backgroundTimeout;
        if (widget.enabled && since != null && limit != null) {
          if (DateTime.now().difference(since) >= limit) {
            _fire(SessionTimeoutReason.background);
            return;
          }
        }
        // Timers may pause in the background; count from the last touch.
        _schedule();
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointer,
        onPointerSignal: _onPointer,
        child: widget.child,
      );
}
