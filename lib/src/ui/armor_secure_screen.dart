import 'package:flutter/widgets.dart';

import '../privacy/armor_native.dart';

/// Blocks screenshots and screen recording while this widget is shown
/// (Android FLAG_SECURE; iOS covers the screen while it is being recorded).
///
/// Wrap only sensitive screens, e.g. a card, OTP or password screen:
/// ```dart
/// ArmorSecureScreen(child: PaymentScreen())
/// ```
class ArmorSecureScreen extends StatefulWidget {
  const ArmorSecureScreen(
      {super.key, required this.child, this.enabled = true});

  final Widget child;

  /// Lets the protection depend on a setting without changing the tree.
  final bool enabled;

  @override
  State<ArmorSecureScreen> createState() => _ArmorSecureScreenState();
}

class _ArmorSecureScreenState extends State<ArmorSecureScreen> {
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(ArmorSecureScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.enabled && !_active) {
      _active = true;
      ArmorNative.pushSecureScreen();
    } else if (!widget.enabled && _active) {
      _active = false;
      ArmorNative.popSecureScreen();
    }
  }

  @override
  void dispose() {
    if (_active) ArmorNative.popSecureScreen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
