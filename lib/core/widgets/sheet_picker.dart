import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Apple HIG sheet-style picker — Apple-style iOS bottom sheet that opens
/// from a tappable row, with a native `CupertinoPicker` or
/// `CupertinoDatePicker` inside a header bar containing Cancel / Selesai.
///
/// The picker is rendered in a separate `showCupertinoModalPopup` overlay
/// (Flutter's native modal — no custom animation, no layout competition with
/// the parent scroll form). Zero lag on real devices, by design.
///
/// Usage:
///   onTap: () => showSheetPicker<`T`>(context, ...);
class SheetPickerItem<T> {
  final T value;
  final String label;
  const SheetPickerItem(this.value, this.label);
}

/// Shows a Cupertino wheel picker in an iOS bottom sheet.
/// Returns the selected value, or `null` if cancelled.
Future<T?> showSheetPicker<T>({
  required BuildContext context,
  required String title,
  required List<SheetPickerItem<T>> items,
  required T currentValue,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    barrierColor: const Color(0x66000000),
    builder: (ctx) {
      int initialIndex = items.indexWhere((i) => i.value == currentValue);
      if (initialIndex < 0) initialIndex = 0;
      var tempIndex = initialIndex;
      return _SheetPickerHost(
        title: title,
        onDone: () => Navigator.of(ctx).pop(items[tempIndex].value),
        child: CupertinoPicker(
          itemExtent: 36,
          scrollController: FixedExtentScrollController(initialItem: initialIndex),
          onSelectedItemChanged: (i) => tempIndex = i,
          children: items
              .map((it) => Center(
                    child: Text(
                      it.label,
                      style: const TextStyle(fontSize: 18, color: AppColors.textDark),
                    ),
                  ))
              .toList(growable: false),
        ),
      );
    },
  );
}

/// Shows a Cupertino date picker in an iOS bottom sheet.
/// Returns the selected DateTime, or `null` if cancelled.
Future<DateTime?> showSheetDatePicker({
  required BuildContext context,
  required String title,
  required DateTime initialDate,
  DateTime? minimumDate,
  DateTime? maximumDate,
}) {
  return showCupertinoModalPopup<DateTime>(
    context: context,
    barrierColor: const Color(0x66000000),
    builder: (ctx) {
      var tempDate = initialDate;
      return _SheetPickerHost(
        title: title,
        onDone: () => Navigator.of(ctx).pop(tempDate),
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.date,
          initialDateTime: initialDate,
          minimumDate: minimumDate,
          maximumDate: maximumDate,
          backgroundColor: AppColors.cardBg,
          onDateTimeChanged: (d) => tempDate = d,
        ),
      );
    },
  );
}

/// iOS-style sheet bar button. Uses GestureDetector to avoid Material
/// text-theme decoration inheritance (yellow underline bug).
class _SheetPickerBarButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool primary;
  const _SheetPickerBarButton({
    required this.label,
    required this.onPressed,
    this.primary = false,
  });

  @override
  State<_SheetPickerBarButton> createState() => _SheetPickerBarButtonState();
}

class _SheetPickerBarButtonState extends State<_SheetPickerBarButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 60),
    reverseDuration: const Duration(milliseconds: 140),
    lowerBound: 0.0,
    upperBound: 1.0,
  );

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.primary
        ? CupertinoColors.systemBlue
        : AppColors.primaryPink;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) => _press.reverse(),
      onTapCancel: () => _press.reverse(),
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _press,
        builder: (ctx, child) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            color: CupertinoDynamicColor.maybeResolve(color, context)
                ?.withValues(alpha: 0.10 * _press.value),
            child: child,
          );
        },
        child: Text(
          widget.label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: widget.primary ? FontWeight.w600 : FontWeight.w400,
            letterSpacing: -0.2,
            color: CupertinoDynamicColor.maybeResolve(color, context),
            decoration: TextDecoration.none,
            decorationColor: const Color(0x00000000),
          ),
        ),
      ),
    );
  }
}

class _SheetPickerHost extends StatelessWidget {
  final String title;
  final VoidCallback onDone;
  final Widget child;

  const _SheetPickerHost({
    required this.title,
    required this.onDone,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Container(
      height: 280 + media.padding.bottom,
      padding: EdgeInsets.only(bottom: media.padding.bottom),
      decoration: const BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Column(
        children: [
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE5E5EA), width: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _SheetPickerBarButton(
                  label: 'Batal',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      title,
                      style: AppTypography.navTitle.copyWith(
                        decoration: TextDecoration.none,
                        decorationColor: const Color(0x00000000),
                      ),
                    ),
                  ),
                ),
                _SheetPickerBarButton(
                  label: 'Selesai',
                  onPressed: onDone,
                  primary: true,
                ),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
