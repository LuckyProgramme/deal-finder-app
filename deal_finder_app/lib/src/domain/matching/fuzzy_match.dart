import 'dart:math' as math;

import 'unicode_text.dart';

/// Normalized Indel similarity (LCS), as used by RapidFuzz's ratio.
double ratio(String left, String right) {
  final a = left.runes.toList(), b = right.runes.toList();
  if (a.isEmpty && b.isEmpty) return 100;
  var previous = List<int>.filled(b.length + 1, 0);
  for (final code in a) {
    final row = List<int>.filled(b.length + 1, 0);
    for (var j = 1; j <= b.length; j++) {
      row[j] = code == b[j - 1]
          ? previous[j - 1] + 1
          : math.max(previous[j], row[j - 1]);
    }
    previous = row;
  }
  return 200 * previous.last / (a.length + b.length);
}

String _sorted(Iterable<String> tokens) =>
    (tokens.toList()..sort(compareCodepoints)).join(' ');
// RapidFuzz 3.14.6's one-byte string path uses ASCII whitespace; its wider
// string path uses Unicode whitespace. In particular NEL/NBSP differ. Preserve
// the locked native oracle's scores, not the fuzz_py reference approximation.
final _latin1Spaces = RegExp(r'[\x09-\x0d\x1c-\x20]+');
List<String> _tokens(String s) => s
    .split(s.runes.every((c) => c <= 255) ? _latin1Spaces : pythonSpaces)
    .where((v) => v.isNotEmpty)
    .toList();
double tokenSortRatio(String a, String b) =>
    ratio(_sorted(_tokens(a)), _sorted(_tokens(b)));
double tokenSetRatio(String a, String b) {
  final x = _tokens(a).toSet(), y = _tokens(b).toSet();
  if (x.isEmpty || y.isEmpty) return 0;
  final common = _sorted(x.intersection(y));
  final left = [
    common,
    _sorted(x.difference(y)),
  ].where((s) => s.isNotEmpty).join(' ');
  final right = [
    common,
    _sorted(y.difference(x)),
  ].where((s) => s.isNotEmpty).join(' ');
  if (common.isEmpty) return ratio(left, right);
  return [
    ratio(left, right),
    ratio(common, left),
    ratio(common, right),
  ].reduce(math.max);
}

double partialRatio(String a, String b) {
  if (a.isEmpty || b.isEmpty) return a == b ? 100 : 0;
  final x = a.runes.toList(), y = b.runes.toList();
  if (x.length > y.length) return partialRatio(b, a);
  var best = 0.0;
  // Consider complete alignments plus clipped alignments at either edge.
  for (var start = 1 - x.length; start < y.length; start++) {
    final candidate = String.fromCharCodes(
      y,
      math.max(0, start),
      math.min(y.length, start + x.length),
    );
    best = math.max(best, ratio(a, candidate));
    if (best == 100) break;
  }
  if (x.length == y.length && a != b && best < 100) {
    for (var end = 1; end < x.length; end++) {
      best = math.max(best, ratio(b, String.fromCharCodes(x, 0, end)));
      best = math.max(best, ratio(b, String.fromCharCodes(x, end)));
    }
  }
  return best;
}

String defaultProcess(String value) => rapidFuzzProcess(value);
