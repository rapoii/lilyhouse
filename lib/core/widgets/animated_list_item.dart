import 'dart:async';
import 'package:flutter/material.dart';

/// A wrapper that animates its child on first build with a staggered
/// fade + slide-up effect.  Each item in a list gets a different delay
/// based on its [index], giving the classic iOS staggered-entry feel.
///
/// 240 fps-safe: uses only offset & opacity on a single Animation, no
/// rebuilds during the tween, and all durations are <300 ms so even at
/// 240 Hz the interpolation is buttery.
class AnimatedListItem extends StatefulWidget {
  final int index;
  final Widget child;

  /// Per-item stagger offset.  30 ms keeps the cascade visible without
  /// making the tail items wait too long (max ~10 items visible = 300 ms).
  final Duration staggerDelay;

  /// Total animation duration per item.
  final Duration duration;

  const AnimatedListItem({
    super.key,
    required this.index,
    required this.child,
    this.staggerDelay = const Duration(milliseconds: 30),
    this.duration = const Duration(milliseconds: 260),
  });

  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.duration);

    final curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(curve);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(curve);

    final delay = widget.staggerDelay * (widget.index.clamp(0, 12));
    if (delay == Duration.zero) {
      _ctrl.forward();
    } else {
      _timer = Timer(delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}
