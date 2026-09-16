import 'package:flutter/material.dart';

/// Layout variants so a skeleton mirrors the real card it replaces.
enum SkeletonLayout {
  /// Compact row (thumbnail + two text lines) — matches `CostumeCard`.
  list,

  /// Taller stacked card (title + amount + progress bar) — matches
  /// `InstallmentCard`.
  card,
}

/// A single shimmering placeholder block.
///
/// Renders on its own without a [SkeletonLoader] parent; the pulse is applied
/// by the parent so a whole list breathes in sync.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height = 12,
    this.borderRadius = 6,
    this.color = const Color(0xFFE9E9EE),
  });

  final double? width;
  final double height;
  final double borderRadius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// A pulsing list of placeholder cards shown while data loads.
///
/// Replaces the bare spinner so the screen keeps its structure: the user sees
/// where content will land instead of a blank canvas.  The pulse is a single
/// controller driving one [FadeTransition], so the whole list animates with a
/// single layer — cheap even at 240 Hz.
class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({
    super.key,
    this.itemCount = 6,
    this.layout = SkeletonLayout.list,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 16),
  });

  /// Number of placeholder cards to render.
  final int itemCount;

  /// Which real card shape to imitate.
  final SkeletonLayout layout;

  /// Outer padding; matches the list it stands in for.
  final EdgeInsets padding;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: ListView.separated(
        // Purely decorative: never let the user scroll or focus it.
        physics: const NeverScrollableScrollPhysics(),
        padding: widget.padding,
        itemCount: widget.itemCount,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          return KeyedSubtree(
            key: Key('skeleton_item_$index'),
            child: widget.layout == SkeletonLayout.card
                ? const _SkeletonCard()
                : const _SkeletonRow(),
          );
        },
      ),
    );
  }
}

/// Mirrors `CostumeCard`: 56 pt thumbnail + title + price line.
class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const SkeletonBox(width: 56, height: 56, borderRadius: 10),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                SkeletonBox(width: 160, height: 15),
                SizedBox(height: 10),
                SkeletonBox(width: 96, height: 13),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Mirrors `InstallmentCard`: title row + amount row + progress bar.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5EA), width: 0.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Expanded(child: SkeletonBox(width: 180, height: 16)),
              SizedBox(width: 8),
              SkeletonBox(width: 64, height: 22, borderRadius: 20),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              SkeletonBox(width: 120, height: 15),
              SkeletonBox(width: 88, height: 13),
            ],
          ),
          const SizedBox(height: 12),
          const SkeletonBox(width: double.infinity, height: 6, borderRadius: 3),
        ],
      ),
    );
  }
}
