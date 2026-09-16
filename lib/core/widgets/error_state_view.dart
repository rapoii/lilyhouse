import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';

/// Friendly, non-technical failure surface with a retry action.
///
/// Shown when a repository read throws — the alternative is a spinner that
/// never resolves (or a blank screen), which leaves the shop owner with no
/// idea what happened and no way to recover. Copy stays plain-language and
/// never leaks exception text.
class ErrorStateView extends StatelessWidget {
  /// Short, human sentence, e.g. 'Gagal memuat daftar kostum'.
  final String message;

  /// Optional gentle hint, e.g. 'Periksa koneksi lalu coba lagi.'
  final String? hint;

  /// Retry callback. When null the button is hidden (read-only surfaces).
  final VoidCallback? onRetry;

  /// Label for the retry button — kept short and verb-first.
  final String retryLabel;

  /// Optional key for the retry button so tests can tap it deterministically.
  final Key? retryKey;

  const ErrorStateView({
    super.key,
    required this.message,
    this.hint,
    this.onRetry,
    this.retryLabel = 'Coba Lagi',
    this.retryKey,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: hint == null ? message : '$message. $hint',
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                CupertinoIcons.exclamationmark_circle,
                size: 44,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 14),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                  height: 1.35,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: 6),
                Text(
                  hint!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 18),
                CupertinoButton(
                  key: retryKey,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                  minimumSize: const Size(44, 44),
                  borderRadius: BorderRadius.circular(22),
                  color: AppColors.softPinkBg,
                  onPressed: onRetry,
                  child: Text(
                    retryLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.deepPinkText,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
