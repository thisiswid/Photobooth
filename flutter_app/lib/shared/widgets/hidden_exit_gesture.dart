import 'dart:async';

import 'package:flutter/material.dart';

/// Gesture tersembunyi untuk keluar dari layar kiosk tanpa menambah tombol UI.
/// Lima ketukan dalam tiga detik memicu [onTriggered].
class HiddenExitGesture extends StatefulWidget {
  const HiddenExitGesture({
    super.key,
    required this.child,
    required this.onTriggered,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback onTriggered;
  final bool enabled;

  @override
  State<HiddenExitGesture> createState() => _HiddenExitGestureState();
}

class _HiddenExitGestureState extends State<HiddenExitGesture> {
  static const _requiredTaps = 5;
  static const _tapWindow = Duration(seconds: 3);

  int _tapCount = 0;
  Timer? _resetTimer;

  @override
  void didUpdateWidget(covariant HiddenExitGesture oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && oldWidget.enabled) _reset();
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    if (!widget.enabled) return;

    _tapCount++;
    _resetTimer?.cancel();

    if (_tapCount >= _requiredTaps) {
      _reset();
      widget.onTriggered();
      return;
    }

    _resetTimer = Timer(_tapWindow, _reset);
  }

  void _reset() {
    _resetTimer?.cancel();
    _resetTimer = null;
    _tapCount = 0;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.enabled ? _handleTap : null,
      child: widget.child,
    );
  }
}
