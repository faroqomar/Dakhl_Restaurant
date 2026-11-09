/// Frozen consumer event keys supplied explicitly; comparison comes from the
/// qualified caller-owned collation session. Exact-key ties retain encounter
/// order. No lexical or ambient-locale fallback exists.
List<Map<String, Object?>> orderSourceEvents(
  Iterable<Map<String, Object?>> rows, {
  required List<String> keys,
  required bool descending,
  required int Function(String, String)? compareText,
}) {
  final indexed = rows.indexed.toList();
  indexed.sort((a, b) {
    for (final key in keys) {
      final left = (descending ? b.$2 : a.$2)[key]! as String,
          right = (descending ? a.$2 : b.$2)[key]! as String;
      final int result;
      if (compareText != null) {
        result = compareText(left, right);
      } else if (left == right) {
        result = 0;
      } else {
        throw const FormatException('collation_unavailable');
      }
      if (result != 0) return result;
    }
    return a.$1.compareTo(b.$1);
  });
  return indexed.map((r) => r.$2).toList(growable: false);
}
