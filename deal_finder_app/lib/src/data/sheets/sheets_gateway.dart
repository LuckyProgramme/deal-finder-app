import 'dart:async';
import 'dart:convert';

import 'package:googleapis/sheets/v4.dart' as api;
import 'package:googleapis_auth/auth_io.dart' as auth;

import '../../application/pipeline/cancellation.dart';
import '../network/bounded_http_client.dart';
import 'sheet_models.dart';

abstract interface class SheetsGateway {
  Future<Map<String, int>> tabs(Cancellation cancellation);
  Future<SheetSnapshot> read(String title, Cancellation cancellation);
  Future<void> apply(
    SheetSnapshot expected,
    List<CellEdit> edits,
    Cancellation cancellation,
  );
  Future<void> initialize(Cancellation cancellation);
  void close();
}

final class GoogleSheetsGateway implements SheetsGateway {
  GoogleSheetsGateway(this.apiClient, this.id, {this._onClose});
  final api.SheetsApi apiClient;
  final String id;
  final void Function()? _onClose;
  static Future<GoogleSheetsGateway> connect(
    String accountJson,
    String spreadsheet,
    Cancellation cancellation,
  ) async {
    cancellation.check();
    final id = spreadsheetId(spreadsheet);
    final transport = BoundedHttpClient(
      cancellation: cancellation,
      allowedHosts: {'oauth2.googleapis.com', 'sheets.googleapis.com'},
    );
    try {
      if (accountJson.length > 100000) throw const FormatException();
      final account = jsonDecode(accountJson) as Map<String, dynamic>;
      if (account['type'] != 'service_account' ||
          account['client_email'] is! String ||
          account['private_key'] is! String ||
          (account['token_uri'] != null &&
              account['token_uri'] != 'https://oauth2.googleapis.com/token')) {
        throw const FormatException();
      }
      final client = await auth.clientViaServiceAccount(
        auth.ServiceAccountCredentials.fromJson(account),
        [api.SheetsApi.spreadsheetsScope],
        baseClient: transport,
      );
      if (cancellation.cancelled) {
        client.close();
        cancellation.check();
      }
      return GoogleSheetsGateway(
        api.SheetsApi(client),
        id,
        onClose: () {
          client.close();
          transport.close();
        },
      );
    } on RunCancelled {
      transport.close();
      rethrow;
    } catch (_) {
      transport.close();
      throw StateError(
        'Sheets sign-in failed. Check the service account, system clock, and network.',
      );
    }
  }

  @override
  void close() => _onClose?.call();

  Future<T> _request<T>(
    Future<T> Function() action,
    Cancellation c, {
    bool retry = true,
  }) async {
    for (var attempt = 0; ; attempt++) {
      c.check();
      try {
        final result = await action().timeout(const Duration(seconds: 30));
        c.check();
        return result;
      } on RunCancelled {
        rethrow;
      } on api.DetailedApiRequestError catch (e) {
        if (retry &&
            attempt < 2 &&
            (e.status == 429 || (e.status ?? 0) >= 500)) {
          await c.delay(Duration(seconds: 1 << attempt));
          continue;
        }
        throw StateError(
          'Sheets request failed (HTTP ${e.status ?? 'unknown'}). Check access and retry.',
        );
      } on TimeoutException {
        throw StateError(
          'Sheets request timed out. Retry will re-read the destination before writing.',
        );
      } catch (_) {
        throw StateError(
          'Sheets could not be reached. No sharing permissions were changed.',
        );
      }
    }
  }

  @override
  Future<Map<String, int>> tabs(Cancellation c) async {
    final result = await _request(
      () => apiClient.spreadsheets.get(
        id,
        $fields: 'sheets(properties(sheetId,title))',
      ),
      c,
    );
    return {
      for (final sheet in result.sheets ?? <api.Sheet>[])
        sheet.properties!.title!: sheet.properties!.sheetId!,
    };
  }

  @override
  Future<SheetSnapshot> read(String title, Cancellation c) async {
    if (!managedTabs.containsKey(title)) {
      throw ArgumentError('Unknown managed tab');
    }
    final quoted = title.replaceAll("'", "''");
    final metadata = await _request(
      () => apiClient.spreadsheets.get(
        id,
        $fields: 'sheets(properties(sheetId,title,gridProperties(rowCount,columnCount)))',
      ),
      c,
    );
    final properties = metadata.sheets
        ?.map((s) => s.properties)
        .where((p) => p?.title == title)
        .firstOrNull;
    if (properties == null) {
      throw StateError(
        '$title was not found. Initialize the required tabs explicitly.',
      );
    }
    final rowCount = properties.gridProperties?.rowCount ?? 0;
    final columnCount = properties.gridProperties?.columnCount ?? 0;
    if (rowCount < 1 ||
        columnCount < 1 ||
        rowCount > 10000 ||
        columnCount > 702) {
      throw StateError(
        '$title exceeds the safe 10,000-row / 702-column grid limit. Resize or archive the tab before syncing.',
      );
    }
    final result = await _request(
      () => apiClient.spreadsheets.get(
        id,
        ranges: ["'$quoted'!A1:${columnLabel(columnCount)}$rowCount"],
        $fields: 'sheets(properties(sheetId,title),data(rowData(values(userEnteredValue,effectiveValue))))',
      ),
      c,
    );
    final sheet = result.sheets?.firstOrNull;
    if (sheet == null) {
      throw StateError(
        '$title was not found. Initialize the required tabs explicitly.',
      );
    }
    final rows = sheet.data?.firstOrNull?.rowData ?? <api.RowData>[];
    Object? value(api.ExtendedValue? v) =>
        v?.stringValue ?? v?.numberValue ?? v?.boolValue;
    final values = rows
        .map(
          (r) => (r.values ?? <api.CellData>[])
              .map(
                (cell) =>
                    value(cell.effectiveValue) ?? value(cell.userEnteredValue),
              )
              .toList(),
        )
        .toList();
    return SheetSnapshot(
      id: sheet.properties!.sheetId!,
      title: title,
      rowCapacity: rowCount,
      columnCapacity: columnCount,
      values: values,
      raw: rows
          .map(
            (r) => (r.values ?? <api.CellData>[])
                .map((v) => v.userEnteredValue?.toJson())
                .toList(),
          )
          .toList(),
    );
  }

  @override
  Future<void> apply(
    SheetSnapshot expected,
    List<CellEdit> edits,
    Cancellation c,
  ) async {
    if (edits.isEmpty) return;
    if ((await read(expected.title, c)).fingerprint != expected.fingerprint) {
      throw StateError(
        '${expected.title} changed after the preview. Review the latest values and retry.',
      );
    }
    final requests = gridRequests(expected, edits);
    // A single batch is atomic. Do not split a target preview across commits.
    if (utf8.encode(jsonEncode(requests)).length > 1800000) {
      throw StateError(
        'This write exceeds the safe batch limit. Reduce the scan size and retry.',
      );
    }
    await _request(
      () => apiClient.spreadsheets.batchUpdate(
        api.BatchUpdateSpreadsheetRequest(
          requests: requests.map(api.Request.fromJson).toList(),
        ),
        id,
      ),
      c,
      retry: false,
    );
  }

  @override
  Future<void> initialize(Cancellation c) async {
    var existing = await tabs(c);
    final missing = managedTabs.keys.where(
      (name) => !existing.containsKey(name),
    );
    if (missing.isNotEmpty) {
      await _request(
        () => apiClient.spreadsheets.batchUpdate(
          api.BatchUpdateSpreadsheetRequest(
            requests: missing
                .map(
                  (name) => api.Request.fromJson({
                    'addSheet': {
                      'properties': {
                        'title': name,
                        'gridProperties': {
                          'rowCount': 10000,
                          'columnCount': 52,
                        },
                      },
                    },
                  }),
                )
                .toList(),
          ),
          id,
        ),
        c,
        retry: false,
      );
      existing = await tabs(c);
    }
    for (final entry in managedTabs.entries) {
      final snapshot = await read(entry.key, c);
      if (snapshot.values.any(
        (row) => row.any((v) => v != null && v.toString().trim().isNotEmpty),
      )) {
        continue;
      }
      await apply(snapshot, [
        for (var i = 0; i < entry.value.length; i++)
          CellEdit(0, i, SheetCell(entry.value[i])),
      ], c);
      await _request(
        () => apiClient.spreadsheets.batchUpdate(
          api.BatchUpdateSpreadsheetRequest(
            requests: [
              api.Request.fromJson({
                'updateSheetProperties': {
                  'properties': {
                    'sheetId': existing[entry.key],
                    'gridProperties': {'frozenRowCount': 1},
                  },
                  'fields': 'gridProperties.frozenRowCount',
                },
              }),
              api.Request.fromJson({
                'repeatCell': {
                  'range': {
                    'sheetId': existing[entry.key],
                    'startRowIndex': 0,
                    'endRowIndex': 1,
                    'startColumnIndex': 0,
                    'endColumnIndex': entry.value.length,
                  },
                  'cell': {
                    'userEnteredFormat': {
                      'backgroundColor': {
                        'red': .29,
                        'green': .49,
                        'blue': .35,
                      },
                      'textFormat': {
                        'bold': true,
                        'foregroundColor': {'red': 1, 'green': 1, 'blue': 1},
                      },
                    },
                  },
                  'fields': 'userEnteredFormat',
                },
              }),
              if (entry.key == 'Price List')
                api.Request.fromJson({
                  'setDataValidation': {
                    'range': {
                      'sheetId': existing[entry.key],
                      'startRowIndex': 1,
                      'startColumnIndex': 9,
                      'endColumnIndex': 10,
                    },
                    'rule': {
                      'condition': {'type': 'BOOLEAN'},
                      'strict': false,
                      'showCustomUi': true,
                    },
                  },
                }),
            ],
          ),
          id,
        ),
        c,
        retry: false,
      );
    }
  }
}

/// Groups adjacent cells into row updates; untouched/custom columns are omitted.
List<Map<String, dynamic>> cellRequests(int sheetId, List<CellEdit> edits) {
  for (final edit in edits) {
    if (edit.row < 0 ||
        edit.row >= 10000 ||
        edit.column < 0 ||
        edit.column >= 702) {
      throw ArgumentError('Cell outside safe sync range');
    }
  }
  final sorted = List<CellEdit>.of(edits)
    ..sort(
      (a, b) => a.row == b.row
          ? a.column.compareTo(b.column)
          : a.row.compareTo(b.row),
    );
  final requests = <Map<String, dynamic>>[];
  for (var i = 0; i < sorted.length;) {
    final first = sorted[i];
    if (first.row < 0 ||
        first.column < 0 ||
        first.row >= 10000 ||
        first.column >= 702) {
      throw ArgumentError('Cell outside safe sync range');
    }
    final cells = [first.cell.apiValue];
    i++;
    while (i < sorted.length &&
        sorted[i].row == first.row &&
        sorted[i].column == first.column + cells.length) {
      cells.add(sorted[i++].cell.apiValue);
    }
    requests.add({
      'updateCells': {
        'start': {
          'sheetId': sheetId,
          'rowIndex': first.row,
          'columnIndex': first.column,
        },
        'rows': [
          {'values': cells},
        ],
        'fields': 'userEnteredValue',
      },
    });
  }
  return requests;
}

String columnLabel(int oneBased) {
  if (oneBased < 1 || oneBased > 702) throw ArgumentError('Invalid column');
  var value = oneBased;
  var result = '';
  while (value > 0) {
    value--;
    result = String.fromCharCode(65 + value % 26) + result;
    value ~/= 26;
  }
  return result;
}

/// Extend only the required dimensions in the same atomic batch as the cells.
List<Map<String, dynamic>> gridRequests(
  SheetSnapshot sheet,
  List<CellEdit> edits,
) {
  final cells = cellRequests(sheet.id, edits);
  var rows = sheet.rowCapacity, columns = sheet.columnCapacity;
  for (final edit in edits) {
    if (edit.row >= rows) rows = edit.row + 1;
    if (edit.column >= columns) columns = edit.column + 1;
  }
  return [
    if (rows > sheet.rowCapacity)
      {
        'appendDimension': {
          'sheetId': sheet.id,
          'dimension': 'ROWS',
          'length': rows - sheet.rowCapacity,
        },
      },
    if (columns > sheet.columnCapacity)
      {
        'appendDimension': {
          'sheetId': sheet.id,
          'dimension': 'COLUMNS',
          'length': columns - sheet.columnCapacity,
        },
      },
    ...cells,
  ];
}
