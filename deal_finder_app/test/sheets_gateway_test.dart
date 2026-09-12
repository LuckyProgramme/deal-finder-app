import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/sheets/v4.dart' as api;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:deal_finder_app/src/application/pipeline/cancellation.dart';
import 'package:deal_finder_app/src/data/sheets/sheet_models.dart';
import 'package:deal_finder_app/src/data/sheets/sheets_gateway.dart';

void main() {
  test(
    'read respects default grid bounds instead of requesting ZZ10000',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        final range = request.url.queryParameters['ranges'];
        if (range != null) expect(range, "'Price List'!A1:Z1000");
        return http.Response(
          jsonEncode({
            'sheets': [
              {
                'properties': {
                  'title': 'Price List',
                  'sheetId': 3,
                  'gridProperties': {'rowCount': 1000, 'columnCount': 26},
                },
                if (range != null)
                  'data': [
                    {
                      'rowData': [
                        {
                          'values': [
                            {
                              'userEnteredValue': {'stringValue': 'Item Name'},
                            },
                          ],
                        },
                      ],
                    },
                  ],
              },
            ],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      addTearDown(client.close);
      final sheet = await GoogleSheetsGateway(
        api.SheetsApi(client),
        'id',
      ).read('Price List', Cancellation());
      expect(requests, hasLength(2));
      expect(sheet.rowCapacity, 1000);
      expect(sheet.columnCapacity, 26);
      expect(sheet.text(0, 0), 'Item Name');
    },
  );

  test('append grows necessary dimensions before atomic cell writes', () {
    final sheet = SheetSnapshot(
      id: 3,
      title: 'History',
      values: [],
      rowCapacity: 10,
      columnCapacity: 17,
    );
    final requests = gridRequests(sheet, [
      const CellEdit(10, 17, SheetCell('value')),
    ]);
    expect(requests[0], {
      'appendDimension': {'sheetId': 3, 'dimension': 'ROWS', 'length': 1},
    });
    expect(requests[1], {
      'appendDimension': {'sheetId': 3, 'dimension': 'COLUMNS', 'length': 1},
    });
    expect(requests[2].containsKey('updateCells'), isTrue);
    expect(
      gridRequests(sheet, [const CellEdit(1, 0, SheetCell('value'))]),
      hasLength(1),
    );
  });

  test('every edit is bounds checked, including adjacent grouped cells', () {
    expect(
      () => cellRequests(1, [
        const CellEdit(1, 701, SheetCell('valid')),
        const CellEdit(1, 702, SheetCell('outside')),
      ]),
      throwsArgumentError,
    );
    expect(
      () => cellRequests(1, [const CellEdit(10000, 0, SheetCell('outside'))]),
      throwsArgumentError,
    );
    expect(columnLabel(1), 'A');
    expect(columnLabel(26), 'Z');
    expect(columnLabel(27), 'AA');
    expect(columnLabel(702), 'ZZ');
  });

  test('grid resize and tab replacement invalidate a preview', () {
    SheetSnapshot snapshot(int id, int rows) => SheetSnapshot(
      id: id,
      title: 'History',
      values: [
        ['same'],
      ],
      rowCapacity: rows,
    );
    expect(snapshot(1, 1000).fingerprint, isNot(snapshot(1, 1001).fingerprint));
    expect(snapshot(1, 1000).fingerprint, isNot(snapshot(2, 1000).fingerprint));
  });
}
