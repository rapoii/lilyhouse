import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Three-state crossfade: loading → content / empty.
///
/// Wraps [AnimatedSwitcher] with a consistent fade+scale micro-transition
/// so every screen shares the same polish.  Duration 220 ms keeps it
/// perceptually instant yet smooth at 240 Hz.
class StateCrossfade extends StatelessWidget {
  final bool isLoading;
  final bool isEmpty;
  final Widget loadingChild;
  final Widget emptyChild;
  final Widget contentChild;
  final Duration duration;

  const StateCrossfade({
    super.key,
    required this.isLoading,
    required this.isEmpty,
    required this.loadingChild,
    required this.emptyChild,
    required this.contentChild,
    this.duration = const Duration(milliseconds: 220),
  });

  @override
  Widget build(BuildContext context) {
    final Widget active;
    final Key stateKey;

    if (isLoading) {
      active = loadingChild;
      stateKey = const ValueKey('loading');
    } else if (isEmpty) {
      active = emptyChild;
      stateKey = const ValueKey('empty');
    } else {
      active = contentChild;
      stateKey = const ValueKey('content');
    }

    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      child: KeyedSubtree(
        key: stateKey,
        child: active,
      ),
    );
  }
}
