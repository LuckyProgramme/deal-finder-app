import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:deal_finder_app/src/application/pipeline/cancellation.dart';
import 'package:deal_finder_app/src/data/network/platform_fetch.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeCurl implements Process {
  FakeCurl(this.stdout, {Stream<List<int>>? errors, int code = 0, this.onKill})
    : stderr = errors ?? const Stream.empty(),
      exitCode = Future.value(code);
  @override
  final Stream<List<int>> stdout;
  @override
  final Stream<List<int>> stderr;
  @override
  final Future<int> exitCode;
  final void Function()? onKill;
  bool killed = false;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    killed = true;
    onKill?.call();
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

FakeCurl reply(
  List<String> args, {
  String body = 'Hello 🎮',
  int status = 200,
  String redirect = '',
  int code = 0,
  Stream<List<int>>? errors,
}) {
  final footer = args[args.indexOf('--write-out') + 1]
      .replaceAll('%{http_code}', '$status')
      .replaceAll('%{redirect_url}', redirect);
  return FakeCurl(
    Stream.fromIterable([
      for (final byte in utf8.encode(body + footer)) [byte],
    ]),
    code: code,
    errors: errors,
  );
}

void main() {
  const url = 'https://www.carousell.ph/p/public-item/';
  const hosts = {'www.carousell.ph', 'carousell.ph'};
  Future<String?> fetch(
    CurlStarter starter, {
    Cancellation? cancellation,
    int maxBytes = 1024,
    Duration timeout = const Duration(seconds: 2),
    Map<String, String>? headers,
    String endpoint = url,
  }) => platformFetch(
    endpoint,
    cancellation ?? Cancellation(),
    allowedHosts: hosts,
    startProcess: starter,
    isWindows: true,
    maxBytes: maxBytes,
    timeout: timeout,
    headers: headers,
  );
  test('native curl arguments disable config, shell/PATH lookup and automatic redirects', () async {
    expect(
      await fetch((exe, args) async {
        expect(exe.toLowerCase(), endsWith(r'\system32\curl.exe'));
        expect(args.first, '--disable');
        expect(
          args,
          containsAll(['--compressed', '--globoff', '--no-location']),
        );
        expect(args, isNot(contains('--location')));
        expect(args[args.indexOf('--proto') + 1], '=https');
        expect(args.last, url);
        return reply(args);
      }, headers: {'Accept': 'text/html'}),
      'Hello 🎮',
    );
  });
  for (final bad in [
    'http://www.carousell.ph/',
    'https://evil.invalid/',
    'https://www.carousell.ph:444/',
    'https://user@www.carousell.ph/',
  ]) {
    test('reject initial endpoint $bad before process startup', () async {
      var calls = 0;
      await expectLater(
        fetch((_, args) async {
          calls++;
          return reply(args);
        }, endpoint: bad),
        throwsFormatException,
      );
      expect(calls, 0);
    });
    test('reject redirect $bad before a second process', () async {
      var calls = 0;
      await expectLater(
        fetch((_, args) async {
          calls++;
          return reply(args, status: 301, redirect: bad);
        }),
        throwsFormatException,
      );
      expect(calls, 1);
    });
  }
  test(
    'follow relative and allowlisted canonical redirects manually',
    () async {
      final requests = <String>[];
      expect(
        await fetch((_, args) async {
          requests.add(args.last);
          return requests.length == 1
              ? reply(args, status: 301, redirect: '/p/canonical/')
              : reply(args, body: 'canonical');
        }),
        'canonical',
      );
      expect(requests, [url, 'https://www.carousell.ph/p/canonical/']);
    },
  );
  test('redirect loops stop after five hops', () async {
    var calls = 0;
    await expectLater(
      fetch((_, args) async {
        calls++;
        return reply(args, status: 302, redirect: url);
      }),
      throwsFormatException,
    );
    expect(calls, 6);
  });
  test('byte limit counts UTF-8, not UTF-16 string length', () async {
    await expectLater(
      fetch((_, args) async => reply(args, body: '🎮🎮🎮'), maxBytes: 10),
      throwsFormatException,
    );
    expect(
      await fetch((_, args) async => reply(args, body: '🎮🎮🎮'), maxBytes: 12),
      '🎮🎮🎮',
    );
  });
  test('oversized stream is killed before full buffering', () async {
    var delivered = 0;
    late FakeCurl child;
    await expectLater(
      fetch((_, args) async {
        child = FakeCurl(
          Stream.fromIterable(List.generate(100, (_) => List.filled(1024, 97)))
              .map((chunk) {
                delivered++;
                return chunk;
              }),
        );
        return child;
      }),
      throwsFormatException,
    );
    expect(child.killed, isTrue);
    expect(delivered, lessThan(100));
  });
  test('stderr is drained with a cap and never added to exceptions', () async {
    await expectLater(
      fetch(
        (_, args) async =>
            reply(args, errors: Stream.value(List.filled(65537, 97))),
      ),
      throwsFormatException,
    );
  });
  test('nonzero exit is not silently retried through Dio', () async {
    await expectLater(
      fetch(
        (_, args) async => reply(
          args,
          code: 7,
          errors: Stream.value(utf8.encode('provider-private-text')),
        ),
      ),
      throwsA(
        isA<DioException>().having(
          (e) => e.toString().contains('provider-private-text'),
          'redacted',
          false,
        ),
      ),
    );
  });
  test('HTTP errors keep status without retaining response body', () async {
    await expectLater(
      fetch(
        (_, args) async =>
            reply(args, status: 429, body: 'provider-private-text'),
      ),
      throwsA(
        isA<DioException>()
            .having((e) => e.response?.statusCode, 'status', 429)
            .having((e) => e.response?.data, 'no body', isNull),
      ),
    );
  });
  test('only unavailable curl and non-Windows permit fallback', () async {
    expect(
      await fetch((_, _) async => throw const ProcessException('curl', [])),
      isNull,
    );
    expect(
      await platformFetch(
        url,
        Cancellation(),
        allowedHosts: hosts,
        isWindows: false,
        startProcess: (_, _) async => throw StateError('must not start'),
      ),
      isNull,
    );
  });
  test(
    'credentials and header injection never reach process arguments',
    () async {
      for (final headers in [
        {'Authorization': 'Bearer test-only'},
        {'Cookie': 'test-only'},
        {'Accept': 'text/html\r\nX: injected'},
      ]) {
        await expectLater(
          fetch(
            (_, _) async => throw StateError('must not start'),
            headers: headers,
          ),
          throwsFormatException,
        );
      }
    },
  );
  test('cancellation stops a stalled stream', () async {
    final stream = StreamController<List<int>>(),
        started = Completer<void>(),
        cancellation = Cancellation();
    late FakeCurl child;
    final assertion = expectLater(
      fetch((_, _) async {
        child = FakeCurl(stream.stream);
        started.complete();
        return child;
      }, cancellation: cancellation),
      throwsA(isA<RunCancelled>()),
    );
    await started.future;
    await Future<void>.delayed(Duration.zero);
    cancellation.cancel();
    await assertion;
    expect(child.killed, isTrue);
    await stream.close();
  });
  test('total deadline stops a stalled stream independently of curl', () async {
    final stream = StreamController<List<int>>();
    late FakeCurl child;
    await expectLater(
      fetch(
        (_, _) async => child = FakeCurl(stream.stream),
        timeout: const Duration(milliseconds: 50),
      ),
      throwsA(
        isA<DioException>().having(
          (e) => e.type,
          'type',
          DioExceptionType.receiveTimeout,
        ),
      ),
    );
    expect(child.killed, isTrue);
    await stream.close();
  });
  test(
    'process created after cancellation is killed without starting readers',
    () async {
      final startup = Completer<Process>(),
          started = Completer<void>(),
          cancellation = Cancellation();
      final assertion = expectLater(
        fetch((_, _) {
          started.complete();
          return startup.future;
        }, cancellation: cancellation),
        throwsA(isA<RunCancelled>()),
      );
      await started.future;
      cancellation.cancel();
      await assertion;
      final child = FakeCurl(const Stream.empty());
      startup.complete(child);
      await Future<void>.delayed(Duration.zero);
      expect(child.killed, isTrue);
    },
  );
}
