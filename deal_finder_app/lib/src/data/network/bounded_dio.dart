import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../application/pipeline/cancellation.dart';

/// Reads decoded bytes with a total deadline and no automatic redirects.
Future<String> boundedDioText(
  Dio client,
  String url,
  Cancellation cancellation, {
  required Set<String> allowedHosts,
  String method = 'GET',
  Map<String, String>? headers,
  Object? data,
  int maxBytes = 8 * 1024 * 1024,
  Duration timeout = const Duration(seconds: 30),
  void Function(int?)? onResponseStatus,
}) async {
  cancellation.check();
  final uri = Uri.parse(url);
  if (uri.scheme != 'https' ||
      uri.port != 443 ||
      uri.userInfo.isNotEmpty ||
      !allowedHosts.contains(uri.host)) {
    throw const FormatException('Unexpected service endpoint');
  }
  final token = CancelToken(), done = Completer<String>();
  void fail(Object error) {
    token.cancel('Request stopped');
    if (!done.isCompleted) done.completeError(error);
  }

  final remove = cancellation.onCancel(() => fail(const RunCancelled()));
  final timer = Timer(
    timeout,
    () => fail(
      DioException.receiveTimeout(
        timeout: timeout,
        requestOptions: RequestOptions(path: url),
      ),
    ),
  );

  Future<String> perform() async {
    final response = await client.request<ResponseBody>(
      url,
      data: data,
      cancelToken: token,
      options: Options(
        method: method,
        headers: headers,
        responseType: ResponseType.stream,
        receiveTimeout: timeout,
        sendTimeout: timeout,
        followRedirects: false,
        // Do not let a failed response bypass the streamed byte limit.
        validateStatus: (_) => true,
      ),
    );
    onResponseStatus?.call(response.statusCode);
    final body = response.data;
    if (body == null) throw const FormatException('Empty service response');
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in body.stream) {
      cancellation.check();
      if (bytes.length + chunk.length > maxBytes) {
        throw const FormatException('Response exceeds the safe size limit');
      }
      bytes.add(chunk);
    }
    final status = response.statusCode ?? 0;
    if (status < 200 || status >= 300) {
      // Do not attach the service response body or authentication headers.
      throw DioException.badResponse(
        statusCode: status,
        requestOptions: RequestOptions(path: url),
        response: Response<void>(
          requestOptions: RequestOptions(path: url),
          statusCode: status,
        ),
      );
    }
    return utf8.decode(bytes.takeBytes());
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
    token.cancel('Request finished');
  }
}
