import 'dart:convert';

import 'package:madar_application/madar_application.dart';
import 'package:madar_domain/madar_domain.dart';

import '../accounts/accounts_repository.dart';
import '../accounts/workspace_document.dart';

final class TicketLine {
  TicketLine({
    required this.productId,
    required this.quantityUnits,
    required this.price,
  }) {
    if (productId.isEmpty ||
        quantityUnits <= BigInt.zero ||
        quantityUnits > BigInt.from(1000000000000) ||
        price < 0 ||
        price > 1000000000000) {
      throw const FormatException('Invalid ticket line');
    }
  }
  final String productId;
  final BigInt quantityUnits;
  final int price;
  Map<String, Object?> toJson() => {
    'productId': productId,
    'quantityUnits': quantityUnits.toString(),
    'price': price,
  };
  factory TicketLine.fromJson(Map<String, dynamic> raw) {
    _keys(raw, {'productId', 'quantityUnits', 'price'});
    return TicketLine(
      productId: raw['productId'] as String,
      quantityUnits: ExactDecimal.parse(
        raw['quantityUnits'] as String,
        scale: 0,
        maxAbsUnits: BigInt.from(1000000000000),
        signed: false,
        positive: true,
      ).units,
      price: raw['price'] as int,
    );
  }
}

final class TicketDraft {
  TicketDraft({
    required this.id,
    required this.date,
    required this.orderType,
    required this.discount,
    required this.note,
    required Iterable<TicketLine> lines,
    this.heldLabel = '',
  }) : lines = List.unmodifiable(lines) {
    DateOnly.parse(date, minimumYear: 1, maximumYear: 9999);
    if (id.isEmpty || this.lines.length > 200) {
      throw const FormatException('Invalid ticket');
    }
  }
  final String id, date, orderType, discount, note, heldLabel;
  final List<TicketLine> lines;
  TicketDraft withHeldLabel(String label) => TicketDraft(
    id: id,
    date: date,
    orderType: orderType,
    discount: discount,
    note: note,
    lines: lines,
    heldLabel: label,
  );
  Map<String, Object?> toJson() => {
    'id': id,
    'date': date,
    'orderType': orderType,
    'discount': discount,
    'note': note,
    'heldLabel': heldLabel,
    'lines': lines.map((l) => l.toJson()).toList(),
  };
  factory TicketDraft.fromJson(Map<String, dynamic> raw) {
    _keys(raw, {
      'id',
      'date',
      'orderType',
      'discount',
      'note',
      'heldLabel',
      'lines',
    });
    return TicketDraft(
      id: raw['id'] as String,
      date: raw['date'] as String,
      orderType: raw['orderType'] as String,
      discount: raw['discount'] as String,
      note: raw['note'] as String,
      heldLabel: raw['heldLabel'] as String,
      lines: (raw['lines'] as List).map(
        (v) => TicketLine.fromJson(v as Map<String, dynamic>),
      ),
    );
  }
}

final class HeldTicket {
  HeldTicket({
    required this.id,
    required this.label,
    required this.savedAt,
    required this.draft,
  }) {
    if (id.isEmpty || label.length > 80 || DateTime.tryParse(savedAt) == null) {
      throw const FormatException('Invalid held ticket');
    }
  }
  final String id, label, savedAt;
  final TicketDraft draft;
  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'savedAt': savedAt,
    'draft': draft.toJson(),
  };
  factory HeldTicket.fromJson(Map<String, dynamic> raw) {
    _keys(raw, {'id', 'label', 'savedAt', 'draft'});
    return HeldTicket(
      id: raw['id'] as String,
      label: raw['label'] as String,
      savedAt: raw['savedAt'] as String,
      draft: TicketDraft.fromJson(raw['draft'] as Map<String, dynamic>),
    );
  }
}

void _keys(Map<String, dynamic> raw, Set<String> keys) {
  if (raw.keys.toSet().difference(keys).isNotEmpty ||
      keys.difference(raw.keys.toSet()).isNotEmpty) {
    throw const FormatException('Unsupported ticket fields');
  }
}

/// Versioned typed payload inside the existing version1 string-map envelope.
/// Unknown legacy active/held maps fail closed; form drafts are retained verbatim.
final class TicketWorkspace {
  TicketWorkspace({
    required this.active,
    required Iterable<HeldTicket> held,
    required Map<String, String> form,
  }) : held = List.unmodifiable(held),
       form = Map.unmodifiable(form) {
    final ids = <String>{};
    final drafts = <String>{active.id};
    if (this.held.length > 40 ||
        this.held.any((h) => !ids.add(h.id) || !drafts.add(h.draft.id))) {
      throw const FormatException('Invalid held identity or count');
    }
  }
  final TicketDraft active;
  final List<HeldTicket> held;
  final Map<String, String> form;
  WorkspaceDocument toEnvelope() => WorkspaceDocument(
    active: {'ticketVersion': '1', 'payload': jsonEncode(active.toJson())},
    form: form,
    held: held
        .map((h) => {'ticketVersion': '1', 'payload': jsonEncode(h.toJson())})
        .toList(),
  );
  factory TicketWorkspace.fromEnvelope(
    WorkspaceDocument envelope,
    TicketDraft initial,
  ) {
    Map<String, dynamic> payload(Map<String, String> record) {
      if (record.length != 2 ||
          record['ticketVersion'] != '1' ||
          !record.containsKey('payload')) {
        throw const FormatException('Unsupported ticket workspace');
      }
      return jsonDecode(record['payload']!) as Map<String, dynamic>;
    }

    if (envelope.active.isEmpty && envelope.held.isEmpty) {
      return TicketWorkspace(active: initial, held: [], form: envelope.form);
    }
    return TicketWorkspace(
      active: TicketDraft.fromJson(payload(envelope.active)),
      held: envelope.held.map((h) => HeldTicket.fromJson(payload(h))),
      form: envelope.form,
    );
  }
}

/// No account posting: every transition writes one fenced workspace snapshot.
final class TicketWorkspaceController {
  TicketWorkspaceController(this.repository);
  final AccountsRepository repository;
  TicketWorkspace? _state;
  StorageFence? _fence;
  int? _revision;
  bool _busy = false;
  bool _containsFinalized(TicketWorkspace value) {
    final document = repository.document;
    if (document == null) return true;
    final ids = (document.toJson()['sales'] as List)
        .cast<Map<String, Object?>>()
        .map((s) => s['id'])
        .toSet();
    return ids.contains(value.active.id) ||
        value.held.any((h) => ids.contains(h.draft.id));
  }

  bool _snapshotMatches(WorkspaceDocument value) {
    final snapshot = repository.workspaceSnapshot;
    return snapshot == null
        ? value.active.isEmpty && value.held.isEmpty && value.form.isEmpty
        : WorkspaceDocument.decode(snapshot.payload).encode() == value.encode();
  }

  TicketWorkspace? get state => _state;
  bool get busy => _busy;
  CapabilityFailure<void> _failure(String code) =>
      CapabilityFailure(code, 'Ticket workspace operation was not confirmed.');
  CapabilityResult<void> _from(CapabilityResult<dynamic> result) =>
      result is CapabilityFailure
      ? _failure(result.code)
      : _failure('unavailable');
  Future<CapabilityResult<void>> load(TicketDraft initial) async {
    if (_busy) return _failure('busy');
    if (repository.hasUnknownWrite) return _failure('commit_unknown');
    _busy = true;
    _state = null;
    _fence = null;
    _revision = null;
    try {
      return await _read(initial);
    } on Object {
      return _failure('unavailable');
    } finally {
      _busy = false;
    }
  }

  Future<CapabilityResult<void>> _read(TicketDraft initial) async {
    final fence = repository.snapshot?.fence;
    if (fence == null) return _failure('no_document');
    final read = await repository.readWorkspace();
    if (read is! CapabilitySuccess<WorkspaceDocument>) return _from(read);
    if (repository.snapshot?.fence != fence) {
      return _failure('stale_generation');
    }
    try {
      if (!_snapshotMatches(read.value)) return _failure('stale_revision');
      final value = TicketWorkspace.fromEnvelope(read.value, initial);
      if (_containsFinalized(value)) return _failure('finalized_ticket');
      _state = value;
      _fence = fence;
      _revision = repository.workspaceSnapshot?.revision;
      return const CapabilitySuccess(null);
    } on Object {
      return _failure('unsupported_ticket_workspace');
    }
  }

  Future<CapabilityResult<void>> _change(
    TicketWorkspace Function(TicketWorkspace) change,
  ) async {
    if (_busy) return _failure('busy');
    if (repository.hasUnknownWrite) return _failure('commit_unknown');
    final old = _state;
    if (old == null) return _failure('not_loaded');
    final fence = _fence;
    if (fence == null || repository.snapshot?.fence != fence) {
      return _failure('stale_generation');
    }
    if (repository.workspaceSnapshot?.revision != _revision) {
      return _failure('stale_revision');
    }
    _busy = true;
    try {
      final next = change(old);
      if (_containsFinalized(next)) return _failure('finalized_ticket');
      // No await between revision comparison and repository CAS invocation.
      final result = await repository.saveWorkspace(next.toEnvelope(), fence);
      if (result is! CapabilitySuccess<void>) return _from(result);
      if (repository.snapshot?.fence != fence) {
        return _failure('stale_generation');
      }
      if (!_snapshotMatches(next.toEnvelope())) {
        return _failure('stale_revision');
      }
      // A same-generation account save may finalize a ticket while the
      // workspace acknowledgement is pending. Do not publish that draft.
      if (_containsFinalized(next)) return _failure('finalized_ticket');
      _state = next;
      _revision = repository.workspaceSnapshot?.revision;
      return const CapabilitySuccess(null);
    } on _TransitionFailure catch (e) {
      return _failure(e.code);
    } on Object {
      return _failure('invalid_ticket_workspace');
    } finally {
      _busy = false;
    }
  }

  Future<CapabilityResult<void>> saveActive(TicketDraft draft) => _change(
    (old) => TicketWorkspace(active: draft, held: old.held, form: old.form),
  );
  Future<CapabilityResult<void>> hold({
    required String label,
    required String heldId,
    required TicketDraft fresh,
    required String savedAt,
  }) => _change((old) {
    if (old.active.lines.isEmpty) {
      throw const _TransitionFailure('empty_ticket');
    }
    if (old.held.length >= 40) throw const _TransitionFailure('held_limit');
    if (fresh.lines.isNotEmpty) {
      throw const _TransitionFailure('fresh_ticket_required');
    }
    final trimmed = label.trim();
    final bounded = trimmed.length > 80 ? trimmed.substring(0, 80) : trimmed;
    return TicketWorkspace(
      active: fresh,
      held: [
        ...old.held,
        HeldTicket(
          id: heldId,
          label: bounded.isEmpty ? 'طلب ${old.held.length + 1}' : bounded,
          savedAt: savedAt,
          draft: old.active,
        ),
      ],
      form: old.form,
    );
  });
  Future<CapabilityResult<void>> resume(
    String id, {
    required String swapId,
    required String swapLabel,
    required String savedAt,
  }) => _change((old) {
    final matches = old.held.where((h) => h.id == id);
    if (matches.isEmpty) throw const _TransitionFailure('held_not_found');
    final record = matches.single;
    final held = old.held.where((h) => h.id != id).toList();
    if (old.active.lines.isNotEmpty) {
      held.add(
        HeldTicket(
          id: swapId,
          label: old.active.heldLabel.isEmpty
              ? swapLabel
              : old.active.heldLabel,
          savedAt: savedAt,
          draft: old.active,
        ),
      );
    }
    return TicketWorkspace(
      active: record.draft.withHeldLabel(record.label),
      held: held,
      form: old.form,
    );
  });
  Future<CapabilityResult<void>> deleteHeld(String id) => _change((old) {
    if (!old.held.any((h) => h.id == id)) {
      throw const _TransitionFailure('held_not_found');
    }
    return TicketWorkspace(
      active: old.active,
      held: old.held.where((h) => h.id != id),
      form: old.form,
    );
  });
  Future<CapabilityResult<void>> reconcile() async {
    if (_busy) return _failure('busy');
    if (!repository.hasUnknownWorkspaceWrite) {
      return _failure('no_pending_workspace');
    }
    final previous = _state;
    if (previous == null) return _failure('not_loaded');
    _busy = true;
    try {
      final result = await repository.reconcile();
      if (result is! CapabilitySuccess) return _from(result);
      if (repository.snapshot?.fence != _fence) {
        return _failure('stale_generation');
      }
      return await _read(previous.active);
    } on Object {
      return _failure('unavailable');
    } finally {
      _busy = false;
    }
  }
}

final class _TransitionFailure implements Exception {
  const _TransitionFailure(this.code);
  final String code;
}
