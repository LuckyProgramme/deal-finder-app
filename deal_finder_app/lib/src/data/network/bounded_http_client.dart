import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../application/pipeline/cancellation.dart';

/// Bounds decoded response bytes while streaming, including OAuth responses.
/// Each request is abortable and has a total deadline, not only an idle timeout.
final class BoundedHttpClient extends http.BaseClient {
  BoundedHttpClient({
    required this.cancellation,
    required Set<String> allowedHosts,
    http.Client? inner,
    this.maxBytes = 8 * 1024 * 1024,
    this.timeout = const Duration(seconds: 30),
  }) : _inner = inner ?? http.Client(),
       _allowedHosts = Set.unmodifiable(allowedHosts);

  final Cancellation cancellation;
  final http.Client _inner;
  final Set<String> _allowedHosts;
  final int maxBytes;
  final Duration timeout;
  final _active = <void Function()>{};
  bool _closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    cancellation.check();
    if (_closed) throw StateError('HTTP client is closed');
    if (request.url.scheme != 'https' ||
        request.url.port != 443 ||
        request.url.userInfo.isNotEmpty ||
        !_allowedHosts.contains(request.url.host)) {
      throw const FormatException('Unexpected service endpoint');
    }
    final abort = Completer<void>();
    final result = Completer<http.StreamedResponse>();
    void stop(Object error) {
      if (!abort.isCompleted) abort.complete();
      if (!result.isCompleted) result.completeError(error);
    }

    void cancel() => stop(const RunCancelled());
    _active.add(cancel);
    final remove = cancellation.onCancel(cancel);
    final timer = Timer(
      timeout,
      () => stop(TimeoutException('Request deadline exceeded')),
    );

    Future<http.StreamedResponse> perform() async {
      final forwarded =
          http.AbortableRequest(
              request.method,
              request.url,
              abortTrigger: abort.future,
            )
            ..headers.addAll(request.headers)
            ..followRedirects = false
            ..persistentConnection = request.persistentConnection;
      forwarded.bodyBytes = await request.finalize().toBytes();
      if (forwarded.bodyBytes.length > maxBytes) {
        throw const FormatException('Request exceeds the safe size limit');
      }
      cancellation.check();
      final response = await _inner.send(forwarded);
      if ((response.contentLength ?? 0) > maxBytes) {
        await response.stream.listen(null).cancel();
        throw const FormatException('Response exceeds the safe size limit');
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response.stream) {
        if (bytes.length + chunk.length > maxBytes) {
          throw const FormatException('Response exceeds the safe size limit');
        }
        bytes.add(chunk);
      }
      return http.StreamedResponse(
        Stream.value(bytes.takeBytes()),
        response.statusCode,
        headers: response.headers,
        request: request,
        reasonPhrase: response.reasonPhrase,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
      );
    }

    // Attach both handlers immediately, including when a deadline wins the race.
    unawaited(
      perform().then(
        (value) {
          if (!result.isCompleted) result.complete(value);
        },
        onError: (Object error, StackTrace stack) {
          if (!result.isCompleted) result.completeError(error, stack);
        },
      ),
    );
    try {
      return await result.future;
    } finally {
      if (!abort.isCompleted) abort.complete();
      timer.cancel();
      remove();
      _active.remove(cancel);
    }
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    for (final cancel in List.of(_active)) {
      cancel();
    }
    _inner.close();
  }
}
