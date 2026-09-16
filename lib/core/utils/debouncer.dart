import 'dart:async';

/// Collapses a burst of rapid invocations into a single trailing call.
///
/// Typical use is a search field: every keystroke calls [run], but the
/// expensive query only fires once the user pauses typing for [delay].
///
/// ```dart
/// final _debouncer = Debouncer(); // 300 ms
///
/// void _onSearchChanged(String _) {
///   _debouncer.run(_fetchResults);
/// }
///
/// @override
/// void dispose() {
///   _debouncer.dispose();
///   super.dispose();
/// }
/// ```
class Debouncer {
  Debouncer({this.delay = const Duration(milliseconds: 300)});

  /// How long the caller must stay quiet before the action runs.
  final Duration delay;

  Timer? _timer;

  /// Whether an action is currently waiting out the debounce window.
  bool get isPending => _timer?.isActive ?? false;

  /// (Re)arms the timer.  Any previously scheduled action is discarded so
  /// only the most recent call wins.
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, () {
      _timer = null;
      action();
    });
  }

  /// Drops a pending action without running it.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }

  /// Cancels any pending action.  Call from `State.dispose`.
  void dispose() => cancel();
}
