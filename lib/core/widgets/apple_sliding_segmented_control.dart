import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Single item descriptor for [AppleSlidingSegmentedControl].
class SegmentItem<T> {
  final T value;
  final String label;

  const SegmentItem({
    required this.value,
    required this.label,
  });
}

/// Authentic Apple iOS Segmented Control with full two-layer physics:
/// 1. Outer container (Layer 1): Rounded `#E5E5EA` track acting as rigid boundary.
/// 2. Elevated white thumb (Layer 2): Can be tapped OR grabbed and dragged
///    fluidly with the thumb across all segments without sticking, snapping
///    to the nearest segment with easeOutCubic curve on release.
/// 3. Dynamic label text flow: Typography smoothly interpolates between active
///    dark bold and inactive muted gray as the white thumb glides underneath.
class AppleSlidingSegmentedControl<T> extends StatefulWidget {
  final T groupValue;
  final List<SegmentItem<T>> items;
  final ValueChanged<T> onValueChanged;
  final Color backgroundColor;
  final Color thumbColor;
  final double height;
  final double fontSize;

  const AppleSlidingSegmentedControl({
    super.key,
    required this.groupValue,
    required this.items,
    required this.onValueChanged,
    this.backgroundColor = const Color(0xFFE5E5EA), // iOS systemGray5
    this.thumbColor = Colors.white,
    this.height = 34.0,
    this.fontSize = 12.5,
  });

  @override
  State<AppleSlidingSegmentedControl<T>> createState() =>
      _AppleSlidingSegmentedControlState<T>();
}

class _AppleSlidingSegmentedControlState<T>
    extends State<AppleSlidingSegmentedControl<T>> {
  int? _dragStartIndex;
  double _dragFraction = 0.0;
  VelocityTracker? _dragVelocity;
  double _innerWidth = 0.0;

  int _findActiveIndex() {
    final idx = widget.items.indexWhere((it) => it.value == widget.groupValue);
    return idx < 0 ? 0 : idx;
  }

  double _currentThumbPosition() {
    final base = _findActiveIndex().toDouble();
    if (_dragStartIndex != null) {
      return _dragStartIndex! + _dragFraction;
    }
    return base;
  }

  Alignment _computeThumbAlignment() {
    final count = widget.items.length;
    if (count <= 1) return Alignment.center;
    final pos = _currentThumbPosition();
    // Maps [0 .. count - 1] to [-1.0 .. 1.0]
    final alignX = -1.0 + (pos / (count - 1)) * 2.0;
    return Alignment(alignX, 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.items.length;
    final isDragging = _dragStartIndex != null;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: widget.backgroundColor,
        borderRadius: BorderRadius.circular(9.0),
      ),
      padding: const EdgeInsets.all(2.5),
      child: LayoutBuilder(
        builder: (context, constraints) {
          _innerWidth = constraints.maxWidth;
          final slotWidth = count > 0 ? _innerWidth / count : 0.0;

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: (details) {
              final active = _findActiveIndex();
              _dragStartIndex = active;
              _dragFraction = 0.0;
              _dragVelocity = VelocityTracker.withKind(PointerDeviceKind.touch);
              _dragVelocity!.addPosition(
                details.sourceTimeStamp ?? Duration.zero,
                details.globalPosition,
              );
            },
            onHorizontalDragUpdate: (details) {
              if (_dragStartIndex == null || slotWidth <= 0) return;
              _dragVelocity?.addPosition(
                details.sourceTimeStamp ?? Duration.zero,
                details.globalPosition,
              );
              final deltaFraction = (details.primaryDelta ?? 0) / slotWidth;
              final start = _dragStartIndex!;
              final minFraction = -start.toDouble();
              final maxFraction = (count - 1 - start).toDouble();
              setState(() {
                _dragFraction =
                    (_dragFraction + deltaFraction).clamp(minFraction, maxFraction);
              });
            },
            onHorizontalDragEnd: (details) {
              if (_dragStartIndex == null) return;
              final velocity =
                  _dragVelocity?.getVelocity() ?? Velocity.zero;
              final vx = velocity.pixelsPerSecond.dx;
              final start = _dragStartIndex!;
              final currentPos = start + _dragFraction;

              int targetIndex;
              if (vx.abs() >= 600) {
                final flickDir = vx > 0 ? 1 : -1;
                targetIndex = (currentPos + flickDir * 0.4).round();
              } else {
                targetIndex = currentPos.round();
              }
              targetIndex = targetIndex.clamp(0, count - 1);
              final selectedValue = widget.items[targetIndex].value;

              setState(() {
                _dragStartIndex = null;
                _dragFraction = 0.0;
                _dragVelocity = null;
              });

              if (selectedValue != widget.groupValue) {
                widget.onValueChanged(selectedValue);
              }
            },
            onHorizontalDragCancel: () {
              setState(() {
                _dragStartIndex = null;
                _dragFraction = 0.0;
                _dragVelocity = null;
              });
            },
            child: Stack(
              children: [
                // Layer 2: Elevated White Sliding Thumb Indicator
                if (count > 0)
                  AnimatedAlign(
                    duration: isDragging
                        ? Duration.zero
                        : const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    alignment: _computeThumbAlignment(),
                    child: FractionallySizedBox(
                      widthFactor: 1.0 / count,
                      heightFactor: 1.0,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.0),
                        decoration: BoxDecoration(
                          color: widget.thumbColor,
                          borderRadius: BorderRadius.circular(7.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 3.5,
                              offset: const Offset(0, 1.5),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 1.0,
                              offset: const Offset(0, 0.5),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Layer 3: Passive Text Labels with Dynamic Visual Flow
                Row(
                  children: List.generate(count, (index) {
                    final item = widget.items[index];
                    final currentPos = _currentThumbPosition();
                    final distance = (currentPos - index).abs();
                    // Activation level: 1.0 when thumb is centered on this slot
                    final targetT = (1.0 - distance).clamp(0.0, 1.0);

                    return Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          if (widget.groupValue != item.value) {
                            widget.onValueChanged(item.value);
                          }
                        },
                        child: Center(
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(end: targetT),
                            duration: isDragging
                                ? Duration.zero
                                : const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                            builder: (context, t, child) {
                              final textColor = Color.lerp(
                                const Color(0xFF636366), // Inactive dark gray
                                Colors.black87,          // Active black
                                t,
                              )!;
                              final isBold = t >= 0.5;

                              return Text(
                                item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: widget.fontSize,
                                  fontWeight: isBold
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: textColor,
                                  letterSpacing: -0.2,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
