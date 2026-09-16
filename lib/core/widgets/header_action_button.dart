import 'package:flutter/cupertino.dart';
import '../theme/app_colors.dart';

/// Standard Apple HIG pill-shaped header action button for AppBars across tabs.
/// Matches the warm brand tint, 16px capsule radius, and 13pt w600 typography.
class HeaderActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final Key? buttonKey;

  const HeaderActionButton({
    super.key,
    required this.label,
    this.icon = CupertinoIcons.plus,
    required this.onPressed,
    this.buttonKey,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 16.0),
      child: CupertinoButton(
        key: buttonKey,
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.softPinkBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: AppColors.deepPinkText,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.deepPinkText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
