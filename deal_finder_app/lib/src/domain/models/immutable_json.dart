/// Deep-copy structured diagnostics so event subscribers cannot change the
/// recorded result through nested lists or maps after publication.
Object? immutableJson(Object? value) {
  if (value is Map) {
    return Map<String, Object?>.unmodifiable({
      for (final entry in value.entries)
        entry.key as String: immutableJson(entry.value),
    });
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(immutableJson));
  }
  return value;
}

Map<String, Object?> immutableJsonMap(Map<String, Object?> value) =>
    immutableJson(value) as Map<String, Object?>;
