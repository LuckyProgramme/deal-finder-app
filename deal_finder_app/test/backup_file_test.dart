import 'dart:async';

import 'package:deal_finder_app/src/platform/files/backup_files.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('file deadline is total, cancels subscription and leaves no timer', () {
    fakeAsync((clock) {
      var cancelled = false;
      Object? failure;
      // Return a zone-owned future: Dart's cached completed cancellation future
      // can belong to the outer test zone, outside this simulated clock.
      final stream = StreamController<List<int>>(
        onCancel: () async {
          cancelled = true;
        },
      );
      readBackupText(stream.stream).then<void>(
        (_) => fail('Expected timeout'),
        onError: (Object error) {
          failure = error;
        },
      );
      clock.elapse(const Duration(seconds: 20));
      stream.add([65]);
      clock.flushMicrotasks();
      expect(failure, isNull);
      clock.elapse(const Duration(seconds: 11));
      clock.flushMicrotasks();
      expect(failure, isA<TimeoutException>());
      expect(cancelled, isTrue);
      expect(clock.pendingTimers, isEmpty);
      stream.close();
      clock.flushMicrotasks();
    });
  });
}
