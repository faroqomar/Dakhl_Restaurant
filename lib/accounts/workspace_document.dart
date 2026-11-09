import 'dart:convert';

/// Restaurant draft presentation only; operational hold/resume belongs to Phase04.
final class WorkspaceDocument {
  WorkspaceDocument({
    required Map<String, String> active,
    required Map<String, String> form,
    required List<Map<String, String>> held,
  }) : active = Map.unmodifiable(active),
       form = Map.unmodifiable(form),
       held = List.unmodifiable(
         held.map((item) => Map<String, String>.unmodifiable(item)),
       ) {
    if (held.length > 40) throw const FormatException('Too many held drafts');
  }
  factory WorkspaceDocument.empty() =>
      WorkspaceDocument(active: const {}, form: const {}, held: const []);
  final Map<String, String> active, form;
  final List<Map<String, String>> held;
  static const maxBytes = 20 * 1024 * 1024;
  String encode() {
    final payload = jsonEncode({
      'version': 1,
      'active': active,
      'form': form,
      'held': held,
    });
    if (utf8.encode(payload).length > maxBytes) {
      throw const FormatException('Workspace size limit');
    }
    return payload;
  }

  factory WorkspaceDocument.decode(String payload) {
    if (utf8.encode(payload).length > maxBytes) {
      throw const FormatException('Workspace size limit');
    }
    try {
      final raw = jsonDecode(payload) as Map<String, dynamic>;
      if (raw['version'] != 1 ||
          raw.keys.toSet().difference({
            'version',
            'active',
            'form',
            'held',
          }).isNotEmpty) {
        throw const FormatException('Unsupported workspace');
      }
      Map<String, String> strings(dynamic value) =>
          Map<String, String>.from(value as Map);
      return WorkspaceDocument(
        active: strings(raw['active']),
        form: strings(raw['form']),
        held: (raw['held'] as List).map(strings).toList(),
      );
    } on Object {
      throw const FormatException('Invalid workspace');
    }
  }
}
