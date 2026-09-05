import 'package:flutter/cupertino.dart';

/// Apple HIG-compliant squircle icon — 29x29 pt with 6.5px continuous corner.
/// Used as the leading icon for inset-grouped form rows (Settings, Contacts,
/// Reminders, etc.). Icon symbol rendered in white, 16px, centered.
class SquircleIcon extends StatelessWidget {
  final IconData icon;
  final Color color;

  const SquircleIcon({super.key, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 29,
      height: 29,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6.5),
      ),
      child: Center(
        child: Icon(icon, color: CupertinoColors.white, size: 16),
      ),
    );
  }
}
