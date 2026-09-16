import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lilyhouse/core/utils/debouncer.dart';

void main() {
  group('Debouncer', () {
    test('does not fire before the delay elapses', () {
      fakeAsync((async) {
        final debouncer = Debouncer(delay: const Duration(milliseconds: 300));
        var calls = 0;

        debouncer.run(() => calls++);
        async.elapse(const Duration(milliseconds: 299));
        expect(calls, 0);

        async.elapse(const Duration(milliseconds: 1));
        expect(calls, 1);

        debouncer.dispose();
      });
    });

    test('coalesces rapid calls into a single trailing invocation', () {
      fakeAsync((async) {
        final debouncer = Debouncer(delay: const Duration(milliseconds: 300));
        var calls = 0;

        debouncer.run(() => calls++);
        async.elapse(const Duration(milliseconds: 100));
        debouncer.run(() => calls++);
        async.elapse(const Duration(milliseconds: 100));
        debouncer.run(() => calls++);

        // Nothing has fired yet: the window keeps resetting.
        expect(calls, 0);
        expect(debouncer.isPending, isTrue);

        async.elapse(const Duration(milliseconds: 300));
        expect(calls, 1);
        expect(debouncer.isPending, isFalse);

        debouncer.dispose();
      });
    });

    test('only the latest action runs', () {
      fakeAsync((async) {
        final debouncer = Debouncer(delay: const Duration(milliseconds: 300));
        final fired = <String>[];

        debouncer.run(() => fired.add('first'));
        async.elapse(const Duration(milliseconds: 50));
        debouncer.run(() => fired.add('second'));
        async.elapse(const Duration(milliseconds: 300));

        expect(fired, ['second']);

        debouncer.dispose();
      });
    });

    test('cancel prevents the pending action from firing', () {
      fakeAsync((async) {
        final debouncer = Debouncer(delay: const Duration(milliseconds: 300));
        var calls = 0;

        debouncer.run(() => calls++);
        debouncer.cancel();
        async.elapse(const Duration(seconds: 1));

        expect(calls, 0);
        expect(debouncer.isPending, isFalse);

        debouncer.dispose();
      });
    });

    test('dispose prevents the pending action from firing', () {
      fakeAsync((async) {
        final debouncer = Debouncer(delay: const Duration(milliseconds: 300));
        var calls = 0;

        debouncer.run(() => calls++);
        debouncer.dispose();
        async.elapse(const Duration(seconds: 1));

        expect(calls, 0);
      });
    });

    test('defaults to a 300 ms delay', () {
      final debouncer = Debouncer();
      expect(debouncer.delay, const Duration(milliseconds: 300));
      debouncer.dispose();
    });
  });
}
