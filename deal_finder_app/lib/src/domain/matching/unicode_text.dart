import 'unicode_tables.g.dart';

// Python str.split/strip uses these whitespace codepoints, unlike Dart trim:
// U+0085 is included; U+FEFF is deliberately not whitespace.
const pythonSpaceBody =
    r'\x09-\x0d\x1c-\x20\x85\xa0\u1680\u2000-\u200a\u2028\u2029\u202f\u205f\u3000';
final pythonSpaces = RegExp('[$pythonSpaceBody]+', unicode: true);
final pythonSpace = RegExp('[$pythonSpaceBody]', unicode: true);
final _trailingSpace = RegExp('[$pythonSpaceBody]+\$', unicode: true);
final _edgeSpace = RegExp(
  '^[$pythonSpaceBody]+|[$pythonSpaceBody]+\$',
  unicode: true,
);
String pythonTrim(String value) => value.replaceAll(_edgeSpace, '');
String pythonTrimRight(String value) => value.replaceFirst(_trailingSpace, '');

final pythonWordBody = [
  for (var i = 0; i < pythonWordRanges.length; i += 2)
    '\\u{${pythonWordRanges[i].toRadixString(16)}}-\\u{${pythonWordRanges[i + 1].toRadixString(16)}}',
].join();
final pythonWords = RegExp('[$pythonWordBody]+', unicode: true);

String pythonCaseFold(String value) => String.fromCharCodes(
  value.runes.expand((c) => pythonCaseFolds[c]?.runes ?? [c]),
);
Set<String> evidenceTokens(String value) =>
    pythonWords.allMatches(pythonCaseFold(value)).map((m) => m[0]!).toSet();

int? _processRune(int code) {
  var low = 0, high = rapidFuzzProcessRanges.length ~/ 3 - 1;
  while (low <= high) {
    final mid = (low + high) ~/ 2, offset = mid * 3;
    if (code < rapidFuzzProcessRanges[offset]) {
      high = mid - 1;
    } else if (code > rapidFuzzProcessRanges[offset + 1]) {
      low = mid + 1;
    } else {
      return code + rapidFuzzProcessRanges[offset + 2];
    }
  }
  return null;
}

String rapidFuzzProcess(String value) =>
    String.fromCharCodes(value.runes.map((c) => _processRune(c) ?? 32)).trim();

int compareCodepoints(String a, String b) {
  final x = a.runes.iterator, y = b.runes.iterator;
  while (true) {
    final hasX = x.moveNext(), hasY = y.moveNext();
    if (!hasX || !hasY) return hasX ? 1 : (hasY ? -1 : 0);
    final comparison = x.current.compareTo(y.current);
    if (comparison != 0) return comparison;
  }
}
