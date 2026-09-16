import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

/// Apple HIG confirmation dialog shown before discarding unsaved form edits.
///
/// Returns `true` when the user confirms leaving the form (discard), and
/// `false` when they choose to keep editing or dismiss the dialog by tapping
/// outside it. Callers should treat a `false` result as "stay on the form".
Future<bool> confirmDiscardChanges(
  BuildContext context, {
  String title = 'Batalkan Perubahan?',
  String message = 'Perubahan yang belum disimpan akan hilang.',
  String keepLabel = 'Lanjut Mengisi',
  String leaveLabel = 'Keluar',
}) async {
  final result = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(keepLabel),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () {
            try {
              HapticFeedback.mediumImpact();
            } catch (_) {}
            Navigator.pop(ctx, true);
          },
          child: Text(leaveLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
