import 'candidate_filter.dart' show tokenize;
import 'fuzzy_match.dart';

final class VariantIndex {
  VariantIndex(Iterable<String> names) {
    final list = names.where((n) => n.trim().isNotEmpty).toList();
    final used = <String>{};
    for (var i = 0; i < list.length; i++) {
      final name = list[i];
      if (!used.add(name)) continue;
      final family = [name];
      for (final other in list.skip(i + 1)) {
        if (!used.contains(other) &&
            tokenSortRatio(name.toLowerCase(), other.toLowerCase()) >= 55) {
          family.add(other);
          used.add(other);
        }
      }
      final shared = family.map(tokenize).reduce((a, b) => a.intersection(b));
      for (final member in family) {
        families[member] = List.unmodifiable(family);
        tokens[member] = tokenize(member).difference(shared);
      }
    }
  }
  final families = <String, List<String>>{};
  final tokens = <String, Set<String>>{};
  static const generic = {
    'apple',
    'mac',
    'macbook',
    'iphone',
    'ipad',
    'samsung',
    'sony',
    'nintendo',
    'switch',
    'playstation',
    'ps5',
    'xbox',
    'microsoft',
  };
  bool accepts(String title, String name) {
    final family = families[name];
    if (family == null) return false;
    final titleTokens = tokenize(title),
        required = tokenize(name).difference(generic);
    if (!titleTokens.containsAll(required)) return false;
    final mine = tokens[name] ?? {};
    final sibling = <String>{
      for (final other in family.where((s) => s != name))
        ...tokens[other] ?? {},
    };
    return titleTokens.containsAll(mine) &&
        titleTokens.intersection(sibling.difference(mine)).isEmpty;
  }
}
