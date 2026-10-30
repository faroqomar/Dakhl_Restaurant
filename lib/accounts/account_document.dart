/// A validated, deeply immutable canonical schema11 account document.
///
/// Restaurant record formats stay in the consumer. This model grants no sales,
/// stock, payment or posting operations; later phases own those workflows.
final class AccountDocument {
  AccountDocument.canonical(
    Map<String, Object?> canonical, {
    required this.sourceVersion,
  }) : _data = _freeze(canonical) as Map<String, Object?>,
       preferences = AccountPreferences.fromJson(
         canonical['preferences'] as Map<String, Object?>,
       );

  final Map<String, Object?> _data;
  final int sourceVersion;
  bool get migrated => sourceVersion != 11;
  int get version => 11;
  final AccountPreferences preferences;
  Map<String, Object?> toJson() => _data;

  List<Map<String, Object?>> get categories =>
      (_data['categories'] as List).cast<Map<String, Object?>>();
  Map<String, Object?> get days => _data['days'] as Map<String, Object?>;

  static Object? _freeze(Object? value) {
    if (value is Map) {
      return Map<String, Object?>.unmodifiable(
        value.map((k, v) => MapEntry(k as String, _freeze(v))),
      );
    }
    if (value is List) return List<Object?>.unmodifiable(value.map(_freeze));
    return value;
  }
}

final class AccountPreferences {
  AccountPreferences.fromJson(Map<String, Object?> json)
    : shortcuts = List<String>.unmodifiable(
        (json['shortcuts'] as List).cast<String>(),
      ),
      orderTypes = List<String>.unmodifiable(
        (json['orderTypes'] as List).cast<String>(),
      ),
      disabledOrderTypes = List<String>.unmodifiable(
        (json['disabledOrderTypes'] as List? ?? const []).cast<String>(),
      ),
      restaurant = Map<String, String>.unmodifiable(
        (json['restaurant'] as Map).cast<String, String>(),
      );
  final List<String> shortcuts;
  final List<String> orderTypes;
  final List<String> disabledOrderTypes;
  final Map<String, String> restaurant;
}
