import 'dart:async';

class RunCancelled implements Exception {
  const RunCancelled();
}

final class Cancellation {
  final _listeners = <void Function()>{};
  bool _cancelled = false;
  bool get cancelled => _cancelled;
  void cancel() {
    if (cancelled) return;
    _cancelled = true;
    final listeners = List.of(_listeners);
    _listeners.clear();
    for (final listener in listeners) {
      listener();
    }
  }

  /// Registers an abort hook; dispose it when the operation finishes.
  void Function() onCancel(void Function() listener) {
    if (cancelled) {
      listener();
    } else {
      _listeners.add(listener);
    }
    return () => _listeners.remove(listener);
  }

  void check() {
    if (cancelled) throw const RunCancelled();
  }

  Future<void> delay(Duration duration) async {
    check();
    final done = Completer<void>();
    final timer = Timer(duration, done.complete);
    final remove = onCancel(() {
      timer.cancel();
      if (!done.isCompleted) done.complete();
    });
    try {
      await done.future;
      check();
    } finally {
      timer.cancel();
      remove();
    }
  }
}
