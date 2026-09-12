import 'dart:convert';

/// Validate depth and duplicate (including escaped) keys before jsonDecode.
/// Syntax and field types are still checked by the decoder and model adapter.
void validateJsonStructure(
  String text, {
  int maxDepth = 24,
  int maxStructuralTokens = 500000,
}) {
  Never invalid() => throw const FormatException('Invalid JSON structure.');
  var depth = 0, structuralTokens = 0, stringStart = 0;
  final objectKeys = <Set<String>?>[];
  var quoted = false, escaped = false;
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (quoted) {
      if (escaped) {
        escaped = false;
      } else if (c == 92) {
        escaped = true;
      } else if (c == 34) {
        quoted = false;
        var next = i + 1;
        while (next < text.length &&
            {9, 10, 13, 32}.contains(text.codeUnitAt(next))) {
          next++;
        }
        if (next < text.length && text.codeUnitAt(next) == 58) {
          final keys = objectKeys.lastOrNull;
          final key = jsonDecode(text.substring(stringStart, i + 1)) as String;
          if (keys == null || !keys.add(key)) invalid();
        }
      }
    } else if (c == 34) {
      quoted = true;
      stringStart = i;
    } else if (c == 91 || c == 123) {
      if (++depth > maxDepth || ++structuralTokens > maxStructuralTokens) {
        invalid();
      }
      objectKeys.add(c == 123 ? <String>{} : null);
    } else if (c == 93 || c == 125) {
      depth--;
      if (objectKeys.isEmpty) invalid();
      objectKeys.removeLast();
    }
  }
}
