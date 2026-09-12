// Explicit, read-only transport probe. Never loads app settings/credentials,
// writes library data or calls Gemini/Sheets. Not compiled into the app.
import 'dart:io';

import 'package:dio/dio.dart';

import 'package:deal_finder_app/src/application/pipeline/cancellation.dart';
import 'package:deal_finder_app/src/data/carousell/carousell_service.dart';
import 'package:deal_finder_app/src/domain/models/money.dart';
import 'package:deal_finder_app/src/domain/models/target.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.length != 1 || arguments.single != '--live') {
    stderr.writeln(
      'Pass --live to fetch one public category page. No credentials or writes.',
    );
    exitCode = 2;
    return;
  }
  final client = Dio();
  try {
    final result = await CarousellService(client).scrape(
      [
        Target(
          id: 'public-transport-probe',
          name: 'Transport probe',
          category: 'Video Gaming',
          searchMode: SearchMode.category,
          dealPrice: const Money(100000),
          allowBundle: false,
        ),
      ],
      Cancellation(),
      (_) {},
      limit: 1,
    );
    for (final source in result.sources) {
      stdout.writeln(
        'source=${source.source.mode.name} fetched=${source.fetched} '
        'retained=${source.retained} failure=${source.failure?.name} status=${source.httpStatus}',
      );
    }
    if (!result.complete) exitCode = 1;
  } finally {
    client.close(force: true);
  }
}
