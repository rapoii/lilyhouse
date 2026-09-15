import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';

/// Dynamic Island-style Apple HIG floating capsule toast.
/// Displays high-contrast transient notification at the top of the screen
/// with subtle haptic feedback and custom icon/color.
class IosToast {
  static void show(
    BuildContext context,
    String message, {
    IconData icon = CupertinoIcons.checkmark_circle_fill,
    Color? iconColor,
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}

    final overlay = Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.maybeOf(context);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _ToastOverlay(
        message: message,
        icon: icon,
        iconColor: iconColor,
        duration: duration,
        onDismissed: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );

    overlay.insert(entry);
  }
}

class _ToastOverlay extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color? iconColor;
  final Duration duration;
  final VoidCallback onDismissed;

  const _ToastOverlay({
    required this.message,
    required this.icon,
    this.iconColor,
    required this.duration,
    required this.onDismissed,
  });

  @override
  State<_ToastOverlay> createState() => _ToastOverlayState();
}

class _ToastOverlayState extends State<_ToastOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _exitController;
  late final Animation<double> _fadeIn;
  late final Animation<double> _translateIn;
  late final Animation<double> _fadeOut;
  late final Animation<double> _translateOut;

  static const _entryMs = 260;
  static const _exitMs = 200;

  bool _exiting = false;
  Timer? _exitTimer;

  @override
  void initState() {
    super.initState();

    // --- Entry controller: 260ms easeOutCubic ---
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _entryMs),
    );
    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );
    _translateIn = Tween<double>(begin: -20.0, end: 0.0).animate(
      CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic),
    );

    // --- Exit controller: 200ms easeIn ---
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _exitMs),
    );
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeIn),
    );
    _translateOut = Tween<double>(begin: 0.0, end: -12.0).animate(
      CurvedAnimation(parent: _exitController, curve: Curves.easeIn),
    );

    // Play entry animation
    _entryController.forward();

    // Schedule exit: after (duration - 200ms), trigger exit animation
    final holdTime = widget.duration - const Duration(milliseconds: _exitMs);
    final safeHold = holdTime.isNegative ? Duration.zero : holdTime;
    _exitTimer = Timer(safeHold, _startExit);
  }

  void _startExit() {
    if (_exiting || !mounted) return;
    _exiting = true;
    _exitController.forward().then((_) {
      if (mounted) widget.onDismissed();
    });
  }

  @override
  void dispose() {
    _exitTimer?.cancel();
    _entryController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 16,
      left: 24,
      right: 24,
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_entryController, _exitController]),
          builder: (context, child) {
            final double opacity;
            final double translateY;

            if (_exiting) {
              opacity = _fadeOut.value;
              translateY = _translateOut.value;
            } else {
              opacity = _fadeIn.value;
              translateY = _translateIn.value;
            }

            return Opacity(
              opacity: opacity.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, translateY),
                child: child,
              ),
            );
          },
          child: DefaultTextStyle(
            style: const TextStyle(
              decoration: TextDecoration.none,
            ),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xEE1C1C1E),
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(widget.icon,
                      color: widget.iconColor ?? AppColors.primaryPink,
                      size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.message,
                      style: const TextStyle(
                        fontFamily: '.SF Pro Text',
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
