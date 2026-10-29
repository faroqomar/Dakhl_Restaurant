import 'package:madar_application/madar_application.dart';

/// Test-only consumer double, never runtime persistence.
final class MemoryPreferencesStore implements LocalPreferencesStore {
  MemoryPreferencesStore({this.snapshot, this.readFailure, this.writeFailure});
  PreferenceSnapshot? snapshot;
  String? readFailure;
  String? writeFailure;
  final List<String> writes = [];
  @override
  Future<CapabilityResult<PreferenceSnapshot?>> read(String namespace) async =>
      readFailure == null
      ? CapabilitySuccess(snapshot)
      : CapabilityFailure(readFailure!, 'Fixture failure');
  @override
  Future<CapabilityResult<PreferenceSnapshot>> replace(
    String namespace,
    String payload, {
    int? expectedRevision,
  }) async {
    if (writeFailure != null) {
      return CapabilityFailure(writeFailure!, 'Fixture write failure');
    }
    if (expectedRevision != snapshot?.revision) {
      return const CapabilityFailure(
        PreferenceErrorCodes.conflict,
        'Fixture conflict',
      );
    }
    writes.add(payload);
    snapshot = PreferenceSnapshot(
      payload: payload,
      revision: (snapshot?.revision ?? 0) + 1,
    );
    return CapabilitySuccess(snapshot!);
  }
}
