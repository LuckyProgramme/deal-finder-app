import 'dart:convert';

import '../../domain/models/target.dart';
import '../../domain/models/money.dart';
import '../../domain/models/deal.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/audit.dart';

const priceHeaders = [
  'Item Name',
  'Category',
  'Search Mode',
  'Retail Price (PHP)',
  'Deal Price (PHP)',
  'Keyword for Condition Downsizing',
  'Keyword for Finding Freebies',
  'Notes',
  'Target Type',
  'Allow Bundle Check',
];
const currentHeaders = [
  'Item Name',
  'Listing Title',
  'Carousell Price',
  'Deal Price',
  'Savings',
  'Final Condition',
  'Freebies',
  'Issues / Defects',
  'Audit Source',
  'Confidence / Score',
  'Specs Matched',
  'Seller',
  'Seller Rating',
  'Likes',
  'Location',
  'Listing Date',
  'Thumbnail',
  'Category',
  'Link',
];
const listingHeaders = [
  'Listing ID',
  'Thumbnail',
  'Listing Title',
  'Carousell Price',
  'Price Status',
  'Original Condition',
  'Seller',
  'Seller Rating',
  'Likes',
  'Location',
  'Listing Date',
  'Category',
  'Description',
  'Link',
];
const historyHeaders = [
  'Listing ID',
  'Item Name',
  'Listing Title',
  'Carousell Price',
  'Deal Price',
  'Savings',
  'Final Condition',
  'Freebies',
  'Issues / Defects',
  'Audit Source',
  'Confidence / Score',
  'Seller',
  'Seller Rating',
  'Category',
  'Link',
  'First Seen Date',
  'Last Seen Date',
];
const managedTabs = {
  'Price List': priceHeaders,
  'Current Deals': currentHeaders,
  'All Listings': listingHeaders,
  'History': historyHeaders,
};

String spreadsheetId(String input) {
  final value = input.trim();
  if (RegExp(r'^[a-zA-Z0-9_-]{20,200}$').hasMatch(value)) return value;
  final uri = Uri.tryParse(value);
  if (uri != null &&
      uri.scheme == 'https' &&
      uri.host == 'docs.google.com' &&
      uri.userInfo.isEmpty &&
      uri.port == 443) {
    final parts = uri.pathSegments;
    if (parts.length >= 3 &&
        parts[0] == 'spreadsheets' &&
        parts[1] == 'd' &&
        RegExp(r'^[a-zA-Z0-9_-]{20,200}$').hasMatch(parts[2])) {
      return parts[2];
    }
  }
  throw const FormatException(
    'Enter a spreadsheet ID or an HTTPS docs.google.com/spreadsheets/d/ URL.',
  );
}

/// Explicit typed values keep marketplace text out of the formula parser.
final class SheetCell {
  const SheetCell(this.value, {this.formula = false});
  final Object? value;
  final bool formula;
  Map<String, Object?> get apiValue => value == null
      ? {}
      : {
          'userEnteredValue': {
            if (formula)
              'formulaValue': value
            else if (value is bool)
              'boolValue': value
            else if (value is num)
              'numberValue': value
            else
              'stringValue': value.toString(),
          },
        };
  static SheetCell image(String? url) {
    final uri = Uri.tryParse(url ?? '');
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        RegExp('["\r\n]').hasMatch(url!)) {
      return const SheetCell(null);
    }
    return SheetCell('=IMAGE("$uri")', formula: true);
  }
}

final class CellEdit {
  const CellEdit(this.row, this.column, this.cell);
  final int row, column;
  final SheetCell cell;
}

final class SheetSnapshot {
  SheetSnapshot({
    required this.id,
    required this.title,
    required List<List<Object?>> values,
    this.rowCapacity = 10000,
    this.columnCapacity = 702,
    Object? raw,
  }) : values = List.unmodifiable(
         values.map((r) => List<Object?>.unmodifiable(r)),
       ),
       fingerprint = jsonEncode([
         id,
         rowCapacity,
         columnCapacity,
         raw ?? values,
       ]);
  final int id;
  final int rowCapacity, columnCapacity;
  final String title, fingerprint;
  final List<List<Object?>> values;
  Object? at(int row, int column) =>
      row < values.length && column < values[row].length
      ? values[row][column]
      : null;
  String text(int row, int column) => at(row, column)?.toString().trim() ?? '';
  (int, List<String>) header(Iterable<String> required) {
    for (var i = 0; i < values.length; i++) {
      final names = values[i].map((v) => v?.toString().trim() ?? '').toList();
      if (required.every(names.contains)) {
        final used = names.where((n) => n.isNotEmpty).toList();
        if (used.toSet().length != used.length) {
          throw StateError('$title contains duplicate column headers.');
        }
        return (i, names);
      }
    }
    throw StateError(
      '$title is missing its required header row. Initialize an empty tab or correct its headers.',
    );
  }
}

Map<String, SheetCell> targetCells(Target target) => {
  'Item Name': SheetCell(target.name),
  'Category': SheetCell(target.category),
  'Search Mode': SheetCell(
    target.searchMode == SearchMode.category ? 'Category' : 'Item Name',
  ),
  'Retail Price (PHP)': SheetCell(
    target.retailPrice == null ? null : target.retailPrice!.centavos / 100,
  ),
  'Deal Price (PHP)': SheetCell(target.dealPrice.centavos / 100),
  'Keyword for Condition Downsizing': SheetCell(
    target.downsizingKeywords.join(', '),
  ),
  'Keyword for Finding Freebies': SheetCell(target.freebieKeywords.join(', ')),
  'Notes': SheetCell(target.notes),
  'Target Type': SheetCell(
    target.type == TargetType.hardware ? 'Hardware' : 'Game',
  ),
  'Allow Bundle Check': SheetCell(target.allowBundle),
};

List<Target> readTargets(
  SheetSnapshot sheet,
  List<Target> local,
  String Function() nextId,
) {
  final required = priceHeaders.where(
    (h) => !{'Search Mode', 'Target Type', 'Allow Bundle Check'}.contains(h),
  );
  final (header, names) = sheet.header(required);
  final result = <Target>[], seen = <String>{};
  for (var row = header + 1; row < sheet.values.length; row++) {
    String cell(String name) =>
        names.contains(name) ? sheet.text(row, names.indexOf(name)) : '';
    final name = cell('Item Name');
    if (name.isEmpty) continue;
    if (!seen.add(name.toLowerCase())) {
      throw StateError('Price List contains duplicate target names.');
    }
    final existing = local
        .where((t) => t.name.toLowerCase() == name.toLowerCase())
        .firstOrNull;
    final mode = cell('Search Mode').toLowerCase(),
        type = cell('Target Type').toLowerCase(),
        bundle = cell('Allow Bundle Check').toLowerCase();
    if (!{'', 'category', 'item name'}.contains(mode)) {
      throw StateError('Invalid Search Mode on row ${row + 1}.');
    }
    if (!{'', 'hardware', 'game'}.contains(type)) {
      throw StateError('Invalid Target Type on row ${row + 1}.');
    }
    if (!{'', 'false', 'no', '0', 'true', 'yes', '1'}.contains(bundle)) {
      throw StateError('Invalid bundle policy on row ${row + 1}.');
    }
    List<String> keywords(String key) =>
        cell(key)
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
    try {
      result.add(
        Target(
          id: existing?.id ?? nextId(),
          name: name,
          category: cell('Category'),
          dealPrice: Money.parse(cell('Deal Price (PHP)')),
          retailPrice: Money.optional(cell('Retail Price (PHP)')),
          searchMode: mode == 'item name'
              ? SearchMode.itemName
              : SearchMode.category,
          type: type == 'game' ? TargetType.game : TargetType.hardware,
          allowBundle: {'true', 'yes', '1'}.contains(bundle),
          enabled: existing?.enabled ?? true,
          downsizingKeywords: keywords('Keyword for Condition Downsizing'),
          freebieKeywords: keywords('Keyword for Finding Freebies'),
          notes: cell('Notes'),
          revision: existing?.revision ?? 0,
        ),
      );
    } catch (_) {
      throw StateError(
        'Invalid target or price on Price List row ${row + 1}. No targets were imported.',
      );
    }
  }
  return result;
}

/// Updates matched names and appends new rows, never deletes remote-only targets.
List<CellEdit> targetExport(SheetSnapshot sheet, List<Target> targets) {
  final (header, names) = sheet.header(priceHeaders);
  final byName = <String, int>{};
  for (var row = header + 1; row < sheet.values.length; row++) {
    final name = sheet.text(row, names.indexOf('Item Name')).toLowerCase();
    if (name.isEmpty) continue;
    if (byName.containsKey(name)) {
      throw StateError('Price List contains duplicate target names.');
    }
    byName[name] = row;
  }
  var append = sheet.values.length;
  final edits = <CellEdit>[], seen = <String>{};
  for (final target in targets) {
    if (!seen.add(target.name.toLowerCase())) {
      throw StateError('Local targets contain duplicate names.');
    }
    final row = byName[target.name.toLowerCase()] ?? append++;
    for (final e in targetCells(target).entries) {
      edits.add(CellEdit(row, names.indexOf(e.key), e.value));
    }
  }
  return edits;
}

String _rating(Listing l) => l.sellerRating == null
    ? ''
    : '${l.sellerRating!.toStringAsFixed(1)}${l.sellerRatingCount == null ? '' : ' (${l.sellerRatingCount})'}';
Map<String, SheetCell> listingCells(
  Listing l, {
  String priceStatus = 'Normal',
}) => {
  'Listing ID': SheetCell(l.id),
  'Thumbnail': SheetCell.image(l.thumbnailUrl),
  'Listing Title': SheetCell(l.title),
  'Carousell Price': SheetCell(
    l.price == null ? null : l.price!.centavos / 100,
  ),
  'Price Status': SheetCell(priceStatus),
  'Original Condition': SheetCell(l.condition),
  'Seller': SheetCell(l.seller),
  'Seller Rating': SheetCell(_rating(l)),
  'Likes': SheetCell(l.likeCount),
  'Location': SheetCell(l.location),
  'Listing Date': SheetCell(l.listedAt),
  'Category': SheetCell(l.category),
  'Description': SheetCell(l.description),
  'Link': SheetCell(l.link),
};
Map<String, SheetCell> dealCells(Deal d, String seenDate) => {
  ...listingCells(d.listing),
  'Item Name': SheetCell(d.target.name),
  'Carousell Price': SheetCell(d.price.centavos / 100),
  'Deal Price': SheetCell(d.target.dealPrice.centavos / 100),
  'Savings': SheetCell(d.savings.centavos / 100),
  'Final Condition': SheetCell(d.finalCondition),
  'Freebies': SheetCell(d.freebies.join(', ')),
  'Bundles': SheetCell(d.freebies.join(', ')),
  'Issues / Defects': SheetCell(d.issues.join(', ')),
  'Audit Source': SheetCell(
    d.provenance is GeminiProvenance ? 'Gemini' : 'Local Fallback',
  ),
  'Confidence / Score': SheetCell(switch (d.provenance) {
    GeminiProvenance(:final confidence) => '$confidence%',
    LocalProvenance(:final score) => '${score.toStringAsFixed(1)}%',
  }),
  'Specs Matched': SheetCell(switch (d.provenance) {
    GeminiProvenance(:final specsMatched) => specsMatched ? 'Yes' : 'No',
    LocalProvenance() => 'N/A',
  }),
  'Category': SheetCell(d.target.category),
  'First Seen Date': SheetCell(seenDate),
  'Last Seen Date': SheetCell(seenDate),
};

List<CellEdit> replaceManagedColumns(
  SheetSnapshot sheet,
  List<String> headers,
  List<Map<String, SheetCell>> records,
) {
  final (header, names) = sheet.header(headers);
  final edits = <CellEdit>[];
  final length = records.length > sheet.values.length - header - 1
      ? records.length
      : sheet.values.length - header - 1;
  for (var i = 0; i < length; i++) {
    for (final name in headers) {
      edits.add(
        CellEdit(
          header + 1 + i,
          names.indexOf(name),
          i < records.length
              ? records[i][name] ?? const SheetCell(null)
              : const SheetCell(null),
        ),
      );
    }
  }
  return edits;
}

List<CellEdit> historyUpdates(
  SheetSnapshot sheet,
  List<Deal> deals,
  String seenDate,
) {
  final (header, names) = sheet.header(['Listing ID', 'Last Seen Date']);
  final existing = <String, int>{};
  for (var row = header + 1; row < sheet.values.length; row++) {
    final id = sheet.text(row, names.indexOf('Listing ID'));
    if (id.isEmpty) continue;
    if (existing.containsKey(id)) {
      throw StateError(
        'History has duplicate Listing IDs. Resolve them before syncing.',
      );
    }
    existing[id] = row;
  }
  final edits = <CellEdit>[], seen = <String>{};
  var append = sheet.values.length;
  for (final d in deals) {
    if (!seen.add(d.id)) continue;
    final old = existing[d.id];
    if (old != null) {
      edits.add(
        CellEdit(old, names.indexOf('Last Seen Date'), SheetCell(seenDate)),
      );
      continue;
    }
    final fields = dealCells(d, seenDate), row = append++;
    for (var column = 0; column < names.length; column++) {
      if (fields.containsKey(names[column])) {
        edits.add(CellEdit(row, column, fields[names[column]]!));
      }
    }
  }
  return edits;
}
