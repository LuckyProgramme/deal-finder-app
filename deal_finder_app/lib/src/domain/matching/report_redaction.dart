import 'text_cleaner.dart';

/// Redact values before JSON serialization, so replacements cannot corrupt JSON
/// syntax. Bound every container and string, including untrusted Gemini IDs.
Object? redactedReport(Object? value) {
  var textBudget = 65536, nodes = 12000;
  final secretField = RegExp(
    r'^(?:key|apikey|geminikey|privatekey|password|secret|authorization|accesstoken|refreshtoken|token|cookie|serviceaccount)$',
  );
  Object? visit(Object? item, int depth) {
    if (--nodes < 0 || depth > 12 || textBudget <= 0) return '[truncated]';
    if (item is String) {
      final safe = redactSecrets(redactPii(item));
      final limit = textBudget < 4096 ? textBudget : 4096;
      final result = safe.length <= limit
          ? safe
          : '${safe.substring(0, limit)}[truncated]';
      textBudget -= result.length;
      return result;
    }
    if (item is Map) {
      final result = <String, Object?>{};
      for (final entry in item.entries) {
        if (nodes <= 0 || textBudget <= 0 || result.length >= 2000) {
          result['__truncated'] = true;
          break;
        }
        final key = visit(entry.key.toString(), depth + 1) as String;
        final canonical = entry.key.toString().toLowerCase().replaceAll(
          RegExp(r'[^a-z]'),
          '',
        );
        result[key] = secretField.hasMatch(canonical)
            ? '[SECRET REDACTED]'
            : visit(entry.value, depth + 1);
      }
      return result;
    }
    if (item is Iterable) {
      final result = <Object?>[];
      for (final child in item) {
        if (nodes <= 0 || textBudget <= 0 || result.length >= 2000) {
          result.add('[truncated]');
          break;
        }
        result.add(visit(child, depth + 1));
      }
      return result;
    }
    if (item == null || item is bool || (item is num && item.isFinite)) {
      return item;
    }
    return '[unsupported]';
  }

  return visit(value, 0);
}
