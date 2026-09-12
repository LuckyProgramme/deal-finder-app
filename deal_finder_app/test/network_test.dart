import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:deal_finder_app/src/application/pipeline/cancellation.dart';
import 'package:deal_finder_app/src/data/network/bounded_http_client.dart';

class StreamClient extends http.BaseClient {
  StreamClient(this.handle);
  final Future<http.StreamedResponse> Function(http.BaseRequest) handle;
  bool closed = false;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handle(request);
  @override
  void close() => closed = true;
}

void main() {
  final url = Uri.parse('https://sheets.googleapis.com/test');

  test('response byte limit is enforced while consuming chunks', () async {
    var cancelled = false;
    final body = StreamController<List<int>>();
    body.onCancel = () => cancelled = true;
    final client = BoundedHttpClient(
      cancellation: Cancellation(),
      allowedHosts: {url.host},
      maxBytes: 4,
      inner: StreamClient((_) async => http.StreamedResponse(body.stream, 200)),
    );
    addTearDown(client.close);
    final result = expectLater(client.get(url), throwsFormatException);
    body.add([1, 2, 3]);
    body.add([4, 5]);
    await result;
    expect(cancelled, isTrue);
    await body.close();
  });

  test(
    'HTTPS host allowlist rejects redirects and credential destinations',
    () async {
      var calls = 0;
      final client = BoundedHttpClient(
        cancellation: Cancellation(),
        allowedHosts: {url.host},
        inner: StreamClient((r) async {
          calls++;
          expect(r.followRedirects, isFalse);
          return http.StreamedResponse(Stream.value([79, 75]), 200);
        }),
      );
      addTearDown(client.close);
      for (final bad in [
        'http://sheets.googleapis.com',
        'https://sheets.googleapis.com.evil.test',
        'https://user@sheets.googleapis.com',
        'https://sheets.googleapis.com:444',
      ]) {
        await expectLater(client.get(Uri.parse(bad)), throwsFormatException);
      }
      expect(calls, 0);
      expect((await client.get(url)).body, 'OK');
      expect(calls, 1);
    },
  );

  test('cancellation aborts an in-flight request immediately', () async {
    final cancellation = Cancellation();
    final started = Completer<void>(), aborted = Completer<void>();
    final client = BoundedHttpClient(
      cancellation: cancellation,
      allowedHosts: {url.host},
      inner: StreamClient((request) async {
        expect(request, isA<http.AbortableRequest>());
        started.complete();
        await (request as http.AbortableRequest).abortTrigger;
        aborted.complete();
        throw http.RequestAbortedException();
      }),
    );
    addTearDown(client.close);
    final result = expectLater(client.get(url), throwsA(isA<RunCancelled>()));
    await started.future;
    cancellation.cancel();
    await result;
    await aborted.future;
  });

  test(
    'total deadline aborts stalled requests and close owns transport',
    () async {
      final aborted = Completer<void>();
      final inner = StreamClient((request) async {
        await (request as http.AbortableRequest).abortTrigger;
        aborted.complete();
        throw http.RequestAbortedException();
      });
      final client = BoundedHttpClient(
        cancellation: Cancellation(),
        allowedHosts: {url.host},
        inner: inner,
        timeout: const Duration(milliseconds: 20),
      );
      await expectLater(client.get(url), throwsA(isA<TimeoutException>()));
      await aborted.future;
      client.close();
      expect(inner.closed, isTrue);
      await expectLater(client.get(url), throwsStateError);
    },
  );

  testWidgets('cancelling a long delay leaves no scheduled timer', (
    tester,
  ) async {
    final cancellation = Cancellation();
    final result = expectLater(
      cancellation.delay(const Duration(hours: 1)),
      throwsA(isA<RunCancelled>()),
    );
    cancellation.cancel();
    await result;
    var disposedCalled = false;
    final other = Cancellation();
    other.onCancel(() => disposedCalled = true)();
    other.cancel();
    expect(disposedCalled, isFalse);
  });
}
