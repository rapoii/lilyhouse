import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'squircle_icon.dart';

/// Apple HIG inline collapsible picker row used across LilyHouse sheets
/// (Kostum Baru, Cicilan Baru, Booking Manual). The row collapses by default
/// showing a label + current value + chevron. Tapping the row expands an
/// `AnimatedSize` revealing a `CupertinoPicker` (or `CupertinoDatePicker`)
/// and a "Selesai" button.
///
/// **Performance contract**: wheel scroll does NOT call `setState` on the
/// parent. The picker's `additionalInfo` row is driven by a local
/// `ValueNotifier` mirror of the selection, so each wheel tick triggers only
/// a `_ValueText` widget repaint (RepaintBoundary isolated) — not the entire
/// modal rebuild. The parent receives a final `onConfirmed` callback ONLY
/// when the user closes the picker via Selesai.
class InlinePickerRow extends StatefulWidget {
  /// Icon shown in the squircle leading slot.
  final IconData icon;
  final Color iconColor;

  /// Label rendered in the row's `title` slot.
  final String label;

  /// Initial / canonical value rendered in the `additionalInfo` slot when
  /// the picker is closed. While the wheel is being scrolled, the row text
  /// shows the in-progress value live without rebuilding the parent.
  final String? value;
  final String? placeholder;

  /// Picker content source. The list is captured once in `didUpdateWidget`
  /// and cached — only re-built when `items` identity changes.
  final List<InlinePickerItem> items;

  /// Currently selected item key. May be null for fresh state.
  final String? selectedKey;

  /// Fired exactly once when the user closes the picker via the Selesai
  /// button. Parent should update its own state with the returned key.
  /// This is the ONLY callback that should trigger a parent setState.
  final void Function(String key, String label) onConfirmed;

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
    required this.onConfirmed,
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

  // Live mirror of the currently focused item while the wheel scrolls.
  // This drives the additionalInfo text in real-time without rebuilding
  // the parent modal. Reset to widget.selectedKey when the picker closes.
  late String? _liveKey;
  late String _liveLabel;

  // Cached list of picker children. Built once per `widget.items` identity.
  late List<Widget> _cachedChildren;

  // Isolated repaint target for the live additionalInfo text. Wheel ticks
  // repaint only this small widget.
  final ValueNotifier<String?> _liveKeyNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<String> _liveLabelNotifier =
      ValueNotifier<String>('');

  @override
  void initState() {
    super.initState();
    _liveKey = widget.selectedKey;
    _liveLabel = _labelFor(widget.selectedKey);
    _liveKeyNotifier.value = _liveKey;
    _liveLabelNotifier.value = _liveLabel;
    _rebuildChildren();
  }

  @override
  void didUpdateWidget(covariant InlinePickerRow old) {
    super.didUpdateWidget(old);
    if (!identical(old.items, widget.items)) {
      _rebuildChildren();
    }
    // If parent changed selectedKey while collapsed, sync live state.
    if (!_expanded && old.selectedKey != widget.selectedKey) {
      _liveKey = widget.selectedKey;
      _liveLabel = _labelFor(widget.selectedKey);
      _liveKeyNotifier.value = _liveKey;
      _liveLabelNotifier.value = _liveLabel;
    }
  }

  void _rebuildChildren() {
    _cachedChildren = widget.items
        .map((it) => Center(
              child: Text(
                it.label,
                style: const TextStyle(fontSize: 18, color: AppColors.textDark),
              ),
            ))
        .toList(growable: false);
  }

  String _labelFor(String? key) {
    if (key == null) return widget.value ?? '';
    final idx = widget.items.indexWhere((it) => it.key == key);
    if (idx < 0) return widget.value ?? '';
    return widget.items[idx].label;
  }

  void _toggle() {
    if (widget.disabled) return;
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        // Reset live to canonical when opening.
        _liveKey = widget.selectedKey;
        _liveLabel = _labelFor(widget.selectedKey);
        _liveKeyNotifier.value = _liveKey;
        _liveLabelNotifier.value = _liveLabel;
      } else {
        // Closing via row tap (not Selesai) — confirm.
        if (_liveKey != null) {
          widget.onConfirmed(_liveKey!, _liveLabel);
        }
      }
    });
  }

  int get _initialIndex {
    final key = _liveKey;
    if (key == null) return 0;
    final i = widget.items.indexWhere((it) => it.key == key);
    return i < 0 ? 0 : i;
  }

  void _onWheelChanged(int idx) {
    if (idx < 0 || idx >= widget.items.length) return;
    final it = widget.items[idx];
    _liveKey = it.key;
    _liveLabel = it.label;
    _liveKeyNotifier.value = it.key;
    _liveLabelNotifier.value = it.label;
  }

  void _onClose() {
    // Confirm current live selection to parent.
    if (_liveKey != null) {
      widget.onConfirmed(_liveKey!, _liveLabel);
    } else if (widget.selectedKey != null) {
      // Re-confirm previous selection so parent state stays consistent.
      widget.onConfirmed(widget.selectedKey!, _labelFor(widget.selectedKey));
    }
    setState(() => _expanded = false);
  }

  @override
  void dispose() {
    _liveKeyNotifier.dispose();
    _liveLabelNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
          additionalInfo: RepaintBoundary(
            child: ValueListenableBuilder<String?>(
              valueListenable: _liveKeyNotifier,
              builder: (_, key, _) {
                final hasValue = key != null && key.isNotEmpty;
                final text = hasValue
                    ? _liveLabelNotifier.value
                    : (widget.placeholder ?? widget.value ?? '');
                final color = hasValue
                    ? AppColors.textDark
                    : const Color(0xFF8E8E93);
                return Text(
                  text,
                  style: TextStyle(fontSize: 15, color: color),
                );
              },
            ),
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
                  cachedChildren: _cachedChildren,
                  initialIndex: _initialIndex,
                  onSelected: _onWheelChanged,
                  onClose: _onClose,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _PickerBody extends StatelessWidget {
  final List<Widget> cachedChildren;
  final int initialIndex;
  final void Function(int) onSelected;
  final VoidCallback onClose;

  const _PickerBody({
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
              onSelectedItemChanged: onSelected,
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

  /// Fired exactly once when the user closes the picker via the Selesai
  /// button. Parent should update its own state with the returned DateTime.
  /// This is the ONLY callback that should trigger a parent setState.
  final void Function(DateTime) onConfirmed;

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
    required this.onConfirmed,
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
  late DateTime _liveDate;
  final ValueNotifier<DateTime> _liveDateNotifier = ValueNotifier<DateTime>(
    DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _liveDate = widget.value ?? widget.initialDate;
    _liveDateNotifier.value = _liveDate;
  }

  @override
  void didUpdateWidget(covariant InlineDatePickerRow old) {
    super.didUpdateWidget(old);
    if (!_expanded && old.value != widget.value) {
      _liveDate = widget.value ?? widget.initialDate;
      _liveDateNotifier.value = _liveDate;
    }
  }

  void _toggle() {
    setState(() {
      _expanded = !_expanded;
      if (_expanded) {
        _liveDate = widget.value ?? widget.initialDate;
        _liveDateNotifier.value = _liveDate;
      } else {
        widget.onConfirmed(_liveDate);
      }
    });
  }

  void _onWheelChanged(DateTime d) {
    _liveDate = d;
    _liveDateNotifier.value = d;
  }

  void _onClose() {
    widget.onConfirmed(_liveDate);
    setState(() => _expanded = false);
  }

  @override
  void dispose() {
    _liveDateNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoListTile(
          leading: SquircleIcon(icon: widget.icon, color: widget.iconColor),
          title: Text(
            widget.label,
            style: const TextStyle(fontSize: 15, color: AppColors.textDark),
          ),
          additionalInfo: RepaintBoundary(
            child: ValueListenableBuilder<DateTime>(
              valueListenable: _liveDateNotifier,
              builder: (_, d, _) {
                final text = widget.value == null && !_expanded
                    ? (widget.placeholder ?? '')
                    : widget.formatValue(d);
                final color = widget.value == null && !_expanded
                    ? const Color(0xFF8E8E93)
                    : AppColors.textDark;
                return Text(
                  text,
                  style: TextStyle(fontSize: 15, color: color),
                );
              },
            ),
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
                  value: _liveDate,
                  minimumDate: widget.minimumDate,
                  maximumDate: widget.maximumDate,
                  minimumYear: widget.minimumYear,
                  maximumYear: widget.maximumYear,
                  onChanged: _onWheelChanged,
                  onClose: _onClose,
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
