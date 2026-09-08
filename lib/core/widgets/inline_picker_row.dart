import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'squircle_icon.dart';

/// Apple HIG inline collapsible picker row used across LilyHouse sheets
/// (Kostum Baru, Cicilan Baru, Booking Manual). The row collapses by default
/// showing a label + current value + chevron. Tapping the row expands an
/// `AnimatedSize` revealing a `CupertinoPicker` (or `CupertinoDatePicker`)
/// and a "Selesai" button. Implemented as a self-contained `StatefulWidget`
/// so the parent's `setState` does NOT rebuild the whole modal — only this
/// widget rebuilds when the user expands or scrolls the wheel.
class InlinePickerRow extends StatefulWidget {
  /// Icon shown in the squircle leading slot.
  final IconData icon;
  final Color iconColor;

  /// Label rendered in the row's `title` slot.
  final String label;

  /// Current value rendered in the `additionalInfo` slot. When null, the
  /// placeholder is shown in muted gray.
  final String? value;
  final String? placeholder;

  /// Picker content source. The list is captured once in `didUpdateWidget`
  /// and cached — only re-built when `items` identity changes.
  final List<InlinePickerItem> items;

  /// Currently selected item key. May be null for fresh state.
  final String? selectedKey;

  /// Called when the user settles on a different item. Parent should update
  /// its own state with the returned key + display label.
  final void Function(String key, String label) onSelected;

  /// Optional subtitle shown below the row (e.g. error message in red).
  final String? subtitle;
  final Color? subtitleColor;

  /// Disable tap (e.g. when item list is empty). When true, the row is greyed
  /// out and `onTap` is suppressed.
  final bool disabled;

  const InlinePickerRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.items,
    required this.selectedKey,
    required this.onSelected,
    this.placeholder,
    this.subtitle,
    this.subtitleColor,
    this.disabled = false,
  });

  @override
  State<InlinePickerRow> createState() => _InlinePickerRowState();
}

class _InlinePickerRowState extends State<InlinePickerRow> {
  bool _expanded = false;

  // Cached list of picker children. Built once per `widget.items` identity.
  late List<Widget> _cachedChildren;
  late String? _cachedSelectedKey;

  @override
  void initState() {
    super.initState();
    _rebuildCache();
  }

  @override
  void didUpdateWidget(covariant InlinePickerRow old) {
    super.didUpdateWidget(old);
    // Rebuild cache only if item identity or selection changed.
    if (!identical(old.items, widget.items) ||
        old.selectedKey != widget.selectedKey) {
      _rebuildCache();
    }
  }

  void _rebuildCache() {
    _cachedSelectedKey = widget.selectedKey;
    _cachedChildren = widget.items
        .map((it) => Center(
              child: Text(
                it.label,
                style: const TextStyle(fontSize: 18, color: AppColors.textDark),
              ),
            ))
        .toList(growable: false);
  }

  void _toggle() {
    if (widget.disabled) return;
    setState(() => _expanded = !_expanded);
  }

  int get _initialIndex {
    if (widget.selectedKey == null || _cachedSelectedKey == null) return 0;
    final i = widget.items.indexWhere((it) => it.key == _cachedSelectedKey);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.value != null && widget.value!.isNotEmpty;
    final infoText = hasValue ? widget.value! : (widget.placeholder ?? '');
    final infoColor = hasValue
        ? AppColors.textDark
        : const Color(0xFF8E8E93);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoListTile(
          leading: SquircleIcon(icon: widget.icon, color: widget.iconColor),
          title: Text(
            widget.label,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textDark,
            ),
          ),
          additionalInfo: Text(
            infoText,
            style: TextStyle(fontSize: 15, color: infoColor),
          ),
          subtitle: widget.subtitle != null
              ? Text(
                  widget.subtitle!,
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.subtitleColor ?? AppColors.dangerRose,
                    fontWeight: FontWeight.w500,
                  ),
                )
              : null,
          trailing: AnimatedRotation(
            turns: _expanded ? 0.25 : 0.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            child: const Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: Color(0xFFC7C7CC),
            ),
          ),
          onTap: widget.disabled ? null : _toggle,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded
              ? _PickerBody(
                  items: widget.items,
                  cachedChildren: _cachedChildren,
                  initialIndex: _initialIndex,
                  onSelected: widget.onSelected,
                  onClose: _toggle,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _PickerBody extends StatelessWidget {
  final List<InlinePickerItem> items;
  final List<Widget> cachedChildren;
  final int initialIndex;
  final void Function(String key, String label) onSelected;
  final VoidCallback onClose;

  const _PickerBody({
    required this.items,
    required this.cachedChildren,
    required this.initialIndex,
    required this.onSelected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // No opaque color — the picker renders its own background, and an
      // opaque white box would clip the section's rounded bottom corners.
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE5E5EA), width: 0.5),
        ),
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 180,
            child: CupertinoPicker(
              itemExtent: 36,
              scrollController:
                  FixedExtentScrollController(initialItem: initialIndex),
              onSelectedItemChanged: (idx) {
                if (idx < 0 || idx >= items.length) return;
                final it = items[idx];
                onSelected(it.key, it.label);
              },
              children: cachedChildren,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: onClose,
                  child: const Text('Selesai', style: AppTypography.actionButton),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InlineDatePickerRow extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final DateTime? value;
  final String Function(DateTime) formatValue;
  final DateTime initialDate;
  final DateTime? minimumDate;
  final DateTime? maximumDate;
  final int minimumYear;
  final int maximumYear;
  final void Function(DateTime) onChanged;
  final String? placeholder;
  final String? subtitle;
  final Color? subtitleColor;

  /// Reset to null + collapse. Set to enable a "Hapus Tanggal" button next
  /// to Selesai (used by Cicilan Baru).
  final VoidCallback? onClear;

  const InlineDatePickerRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.formatValue,
    required this.initialDate,
    required this.onChanged,
    this.minimumDate,
    this.maximumDate,
    this.minimumYear = 2020,
    this.maximumYear = 2035,
    this.placeholder,
    this.subtitle,
    this.subtitleColor,
    this.onClear,
  });

  @override
  State<InlineDatePickerRow> createState() => _InlineDatePickerRowState();
}

class _InlineDatePickerRowState extends State<InlineDatePickerRow> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.value != null;
    final infoText =
        hasValue ? widget.formatValue(widget.value!) : (widget.placeholder ?? '');
    final infoColor =
        hasValue ? AppColors.textDark : const Color(0xFF8E8E93);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoListTile(
          leading: SquircleIcon(icon: widget.icon, color: widget.iconColor),
          title: Text(
            widget.label,
            style: const TextStyle(fontSize: 15, color: AppColors.textDark),
          ),
          additionalInfo: Text(
            infoText,
            style: TextStyle(fontSize: 15, color: infoColor),
          ),
          subtitle: widget.subtitle != null
              ? Text(
                  widget.subtitle!,
                  style: TextStyle(
                    fontSize: 11,
                    color: widget.subtitleColor ?? AppColors.dangerRose,
                    fontWeight: FontWeight.w500,
                  ),
                )
              : null,
          trailing: AnimatedRotation(
            turns: _expanded ? 0.25 : 0.0,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            child: const Icon(
              CupertinoIcons.chevron_right,
              size: 14,
              color: Color(0xFFC7C7CC),
            ),
          ),
          onTap: _toggle,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: _expanded
              ? _DatePickerBody(
                  value: widget.value ?? widget.initialDate,
                  minimumDate: widget.minimumDate,
                  maximumDate: widget.maximumDate,
                  minimumYear: widget.minimumYear,
                  maximumYear: widget.maximumYear,
                  onChanged: widget.onChanged,
                  onClose: _toggle,
                  onClear: widget.onClear,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _DatePickerBody extends StatelessWidget {
  final DateTime value;
  final DateTime? minimumDate;
  final DateTime? maximumDate;
  final int minimumYear;
  final int maximumYear;
  final void Function(DateTime) onChanged;
  final VoidCallback onClose;
  final VoidCallback? onClear;

  const _DatePickerBody({
    required this.value,
    required this.minimumDate,
    required this.maximumDate,
    required this.minimumYear,
    required this.maximumYear,
    required this.onChanged,
    required this.onClose,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFFE5E5EA), width: 0.5),
        ),
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 180,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: value,
              minimumDate: minimumDate,
              maximumDate: maximumDate,
              minimumYear: minimumYear,
              maximumYear: maximumYear,
              onDateTimeChanged: onChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment:
                  onClear != null ? MainAxisAlignment.spaceBetween : MainAxisAlignment.end,
              children: [
                if (onClear != null)
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    onPressed: onClear,
                    child: const Text(
                      'Hapus Tanggal',
                      style: TextStyle(
                        color: AppColors.primaryPink,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  onPressed: onClose,
                  child: const Text('Selesai', style: AppTypography.actionButton),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class InlinePickerItem {
  final String key;
  final String label;
  const InlinePickerItem(this.key, this.label);
}
