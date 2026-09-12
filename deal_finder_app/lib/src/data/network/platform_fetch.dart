import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../../application/pipeline/cancellation.dart';

typedef CurlStarter = Future<Process> Function(
  String executable,
  List<String> arguments,
);

Future<Process> _startCurl(String executable, List<String> arguments) =>
    Process.start(executable, arguments);

/// Windows Schannel transport for public marketplace GETs, not credentialed APIs.
/// Only unavailable curl/non-Windows permits Dio fallback. Redirects are followed
/// manually after endpoint validation; limits apply while reading decoded bytes.
Future<String?> platformFetch(
  String url,
  Cancellation cancellation, {
  required Set<String> allowedHosts,
  Map<String, String>? headers,
  int maxBytes = 8 * 1024 * 1024,
  Duration timeout = const Duration(seconds: 30),
  CurlStarter startProcess = _startCurl,
  bool? isWindows,
}) async {
  if (!(isWindows ?? Platform.isWindows)) return null;
  if (maxBytes < 1 || timeout <= Duration.zero) {
    throw ArgumentError('Response limit and timeout must be positive');
  }
  final hosts = Set<String>.of(allowedHosts);
  final publicHeaders = Map<String, String>.of(headers ?? {});
  for (final entry in publicHeaders.entries) {
    // No secrets in process arguments, curl config files or redirect headers.
    if (!{
          'accept',
          'accept-language',
          'user-agent',
        }.contains(entry.key.toLowerCase()) ||
        RegExp(r'[\r\n\x00]').hasMatch(entry.value)) {
      throw const FormatException(
        'Only public marketplace headers are supported',
      );
    }
  }
  void validate(Uri uri) {
    if (uri.scheme != 'https' ||
        uri.port != 443 ||
        uri.userInfo.isNotEmpty ||
        !hosts.contains(uri.host)) {
      throw const FormatException('Unexpected service endpoint');
    }
  }

  var uri = Uri.parse(url);
  validate(uri);
  cancellation.check();
  final done = Completer<String?>(), watch = Stopwatch()..start();
  Process? active;
  Object? stopped;
  final readers = <void Function()>[];
  void fail(Object error) {
    stopped ??= error;
    active?.kill();
    if (!done.isCompleted) done.completeError(error);
  }

  void check() {
    cancellation.check();
    if (stopped != null) throw stopped!;
  }

  final timer = Timer(
    timeout,
    () => fail(
      DioException.receiveTimeout(
        timeout: timeout,
        requestOptions: RequestOptions(path: url),
      ),
    ),
  );
  final remove = cancellation.onCancel(() => fail(const RunCancelled()));
  // Do not search the workspace or PATH for an executable named curl.
  final executable =
      '${Platform.environment['SystemRoot'] ?? r'C:\Windows'}\\System32\\curl.exe';

  Future<void> drain(Stream<List<int>> stream, int cap, BytesBuilder? output) {
    final finished = Completer<void>();
    var count = 0;
    final subscription = stream.listen(
      (chunk) {
        count += chunk.length;
        if (count > cap) {
          fail(const FormatException('Response exceeds the safe size limit'));
        } else {
          output?.add(chunk);
        }
      },
      onError: (Object _) {
        fail(const FormatException('Could not read the platform response'));
        if (!finished.isCompleted) finished.complete();
      },
      onDone: () {
        if (!finished.isCompleted) finished.complete();
      },
    );
    readers.add(() {
      unawaited(subscription.cancel());
      if (!finished.isCompleted) finished.complete();
    });
    return finished.future;
  }

  Future<String?> perform() async {
    for (var redirects = 0; ; redirects++) {
      check();
      validate(uri);
      final marker = '\n---CURL_${const Uuid().v4()}---\n';
      final remaining = timeout - watch.elapsed;
      if (remaining <= Duration.zero) {
        throw DioException.receiveTimeout(
          timeout: timeout,
          requestOptions: RequestOptions(path: url),
        );
      }
      final args = <String>[
        '--disable', // Must be first: ignore user/workspace curl configuration.
        '--silent', '--show-error', '--compressed', '--globoff',
        '--proto', '=https', '--no-location', '--max-redirs', '0',
        '--max-time',
        (remaining.inMicroseconds / Duration.microsecondsPerSecond).toString(),
        '--write-out', '$marker%{http_code}\n%{redirect_url}',
        for (final entry in publicHeaders.entries) ...[
          '--header',
          '${entry.key}: ${entry.value}',
        ],
        '--url', uri.toString(),
      ];
      try {
        active = await startProcess(executable, args);
      } on ProcessException {
        check();
        if (redirects == 0) return null;
        throw DioException.connectionError(
          requestOptions: RequestOptions(path: url),
          reason: 'Platform transport unavailable during redirect',
        );
      }
      // A deadline/cancellation can win while process creation is still pending.
      if (stopped != null || cancellation.cancelled) {
        active!.kill();
        check();
      }
      final bytes = BytesBuilder(copy: false);
      // Reserve bounded space for status + redirect metadata, then check the
      // exact body byte length before UTF-8 decoding. Stderr is drained, not saved.
      await Future.wait([
        drain(active!.stdout, maxBytes + 8192, bytes),
        drain(active!.stderr, 64 * 1024, null),
        active!.exitCode.then((_) {}),
      ]);
      check();
      final exitCode = await active!.exitCode;
      if (exitCode != 0) {
        throw DioException.connectionError(
          requestOptions: RequestOptions(path: url),
          reason: 'Platform transport failed (exit $exitCode)',
        );
      }
      final raw = bytes.takeBytes();
      final markerBytes = ascii.encode(marker);
      var boundary = -1;
      // The trusted write-out suffix is last, even if HTML contains a marker.
      for (var i = raw.length - markerBytes.length; i >= 0; i--) {
        if (raw[i] != markerBytes.first) continue;
        var matches = true;
        for (var j = 1; j < markerBytes.length; j++) {
          if (raw[i + j] != markerBytes[j]) {
            matches = false;
            break;
          }
        }
        if (matches) {
          boundary = i;
          break;
        }
      }
      if (boundary < 0 || raw.length - boundary > 8192) {
        throw const FormatException('Invalid platform response metadata');
      }
      if (boundary > maxBytes) {
        throw const FormatException('Response exceeds the safe size limit');
      }
      final metadata = utf8
          .decode(Uint8List.sublistView(raw, boundary + markerBytes.length))
          .split('\n');
      if (metadata.length != 2 ||
          !RegExp(r'^[1-5][0-9]{2}$').hasMatch(metadata.first)) {
        throw const FormatException('Invalid platform response status');
      }
      final status = int.parse(metadata.first);
      if ({301, 302, 303, 307, 308}.contains(status)) {
        if (redirects >= 5 || metadata.last.isEmpty) {
          throw const FormatException('Invalid or excessive service redirects');
        }
        final next = uri.resolve(metadata.last);
        validate(next); // Before another process/network request is started.
        uri = next;
        for (final close in readers) {
          close();
        }
        readers.clear();
        continue;
      }
      if (status < 200 || status >= 300) {
        throw DioException.badResponse(
          statusCode: status,
          requestOptions: RequestOptions(path: url),
          response: Response<void>(
            requestOptions: RequestOptions(path: url),
            statusCode: status,
          ),
        );
      }
      return utf8.decode(Uint8List.sublistView(raw, 0, boundary));
    }
  }

  unawaited(
    perform().then(
      (value) {
        if (!done.isCompleted) done.complete(value);
      },
      onError: (Object error, StackTrace stack) {
        if (!done.isCompleted) done.completeError(error, stack);
      },
    ),
  );
  try {
    return await done.future;
  } finally {
    timer.cancel();
    remove();
    active?.kill();
    for (final close in readers) {
      close();
    }
    readers.clear();
  }
}
