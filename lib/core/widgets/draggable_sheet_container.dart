import 'package:flutter/cupertino.dart';

/// Apple HIG-style draggable modal sheet container.
///
/// The pill at the top is a drag handle: drag down to dismiss, drag up to
/// expand up to [maxHeightFraction] of the screen. No haptic feedback.
/// On release, the sheet snaps to the closest of:
///   * collapsed (default [initialHeightFraction])
///   * expanded  ([maxHeightFraction])
///   * dismissed (if the drag offset was below the [dismissThreshold] fraction
///               of [initialHeightFraction]).
class DraggableSheetContainer extends StatefulWidget {
  /// Builder that produces the sheet body (called inside the sheet, below the
  /// drag handle). Should fill the remaining height.
  final WidgetBuilder builder;

  /// Initial sheet height as a fraction of the screen height (0..1).
  final double initialHeightFraction;

  /// Maximum sheet height as a fraction of the screen height (0..1) when
  /// expanded by drag.
  final double maxHeightFraction;

  /// How far the user must drag down (as a fraction of the sheet's initial
  /// height) to dismiss the sheet.
  final double dismissThreshold;

  /// Optional color of the sheet's background. Defaults to system grouped bg.
  final Color? backgroundColor;

  /// Called when the user drags far enough to dismiss the sheet.
  final VoidCallback? onDismissed;

  const DraggableSheetContainer({
    super.key,
    required this.builder,
    this.initialHeightFraction = 0.85,
    this.maxHeightFraction = 0.95,
    this.dismissThreshold = 0.25,
    this.backgroundColor,
    this.onDismissed,
  });

  @override
  State<DraggableSheetContainer> createState() => _DraggableSheetContainerState();
}

class _DraggableSheetContainerState extends State<DraggableSheetContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _dragOffset = 0.0; // positive = dragged down (shrinking)
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _animation = AlwaysStoppedAnimation(0.0);
    _controller.addListener(() {
      if (_isAnimating) setState(() {});
    });
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (_dragOffset >= _dismissDistance) {
          widget.onDismissed?.call();
        } else {
          setState(() {
            _dragOffset = 0.0;
            _isAnimating = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _initialHeight {
    final screenHeight = MediaQuery.of(context).size.height;
    return screenHeight * widget.initialHeightFraction;
  }

  double get _maxHeight {
    final screenHeight = MediaQuery.of(context).size.height;
    return screenHeight * widget.maxHeightFraction;
  }

  double get _dismissDistance => _initialHeight * widget.dismissThreshold;

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_isAnimating) return;
    setState(() {
      _dragOffset += details.primaryDelta ?? 0.0;
      // Soft rubber-band resistance when expanding past max height.
      final maxDelta = _maxHeight - _initialHeight;
      if (_dragOffset < -maxDelta) {
        final over = (-_dragOffset) - maxDelta;
        _dragOffset = -maxDelta - over * 0.3;
      }
    });
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_isAnimating) return;
    final currentHeight = (_initialHeight - _dragOffset).clamp(0.0, _maxHeight);
    double targetOffset;
    if (_dragOffset >= _dismissDistance) {
      targetOffset = _initialHeight; // animate the offset to make height 0
    } else {
      // Snap to whichever of {initial, max} is closer to the current height.
      final distToInitial = (_initialHeight - currentHeight).abs();
      final distToMax = (_maxHeight - currentHeight).abs();
      if (distToInitial < distToMax) {
        targetOffset = 0.0; // back to initial
      } else {
        targetOffset = _initialHeight - _maxHeight; // negative offset = expanded
      }
    }
    _animateTo(targetOffset);
  }

  void _animateTo(double target) {
    final start = _dragOffset;
    _animation = Tween<double>(begin: start, end: target).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _isAnimating = true;
    _controller
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    // Determine drag progress for visual feedback (0..1)
    final dragProgress = (_dragOffset.abs() / _initialHeight).clamp(0.0, 1.0);
    final pillColor = Color.lerp(
      const Color(0xFFD1D1D6),
      const Color(0xFF8E8E93),
      dragProgress,
    )!;
    final pillWidth = 36.0 + dragProgress * 12.0;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        final visualOffset = _isAnimating ? _animation.value : _dragOffset;
        final visualHeight = (_initialHeight - visualOffset).clamp(0.0, _maxHeight);
        return Container(
          height: visualHeight,
          decoration: BoxDecoration(
            color: widget.backgroundColor ?? const Color(0xFFF2F2F7),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            boxShadow: [
              BoxShadow(
                color: CupertinoColors.black.withValues(alpha: 0.10),
                blurRadius: 18,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: Column(
              children: [
                // Drag handle area - always responds to gestures
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: _onVerticalDragUpdate,
                  onVerticalDragEnd: _onVerticalDragEnd,
                  child: Container(
                    color: widget.backgroundColor ?? const Color(0xFFF2F2F7),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    alignment: Alignment.center,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: pillWidth,
                      height: 5,
                      decoration: BoxDecoration(
                        color: pillColor,
                        borderRadius: BorderRadius.circular(2.5),
                      ),
                    ),
                  ),
                ),
                Expanded(child: widget.builder(context)),
              ],
            ),
          ),
        );
      },
    );
  }
}
