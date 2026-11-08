import 'dart:convert';
import 'dart:io';

import 'package:dakhl_restaurant/app/app.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'c1_restart_fixture.dart';

/// Opt-in QA binary. Never invokes production main or normal account factories.
/// A required run UUID selects one marked fixture across actual app launches.
Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  final semantics = binding.ensureSemantics();
  const id = String.fromEnvironment('C1_QA_FIXTURE');
  try {
    final support = await getApplicationSupportDirectory();
    await support.create(recursive: true);
    final namespace = Directory(
      p.join(await support.resolveSymbolicLinks(), 'dakhl_c1_restart_qa_v1'),
    );
    final fixture = await C1RestartFixture.open(
      namespace: namespace,
      fixtureId: id,
    );
    debugPrint(
      jsonEncode({
        'event': 'c1_restart_qa_ready',
        'fixtureId': id,
        'root': fixture.root.path,
        'pid': pid,
        'bootNonce': fixture.bootNonce,
        'initializedThisLaunch': fixture.initializedThisLaunch,
      }),
    );
    runApp(_QaHost(fixture: fixture, semantics: semantics));
  } on Object catch (error) {
    final code = error is C1QaException ? error.code : 'qa_start_failed';
    debugPrint(
      jsonEncode({'event': 'c1_restart_qa_refused', 'code': code, 'pid': pid}),
    );
    runApp(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ColoredBox(
          color: const Color(0xFFFFFFFF),
          child: Center(
            child: Text(
              'C1 QA refused: $code\npid: $pid',
              style: const TextStyle(color: Color(0xFF000000), fontSize: 18),
            ),
          ),
        ),
      ),
    );
  }
}

final class _QaHost extends StatefulWidget {
  const _QaHost({required this.fixture, required this.semantics});
  final C1RestartFixture fixture;
  final SemanticsHandle semantics;
  @override
  State<_QaHost> createState() => _QaHostState();
}

final class _QaHostState extends State<_QaHost> {
  Map<String, Object?>? _report;
  String _status = 'Ready';
  bool _expanded = true, _busy = false, _showTarget = false, _cleaned = false;
  int _epoch = 0;
  C1RestartFixture get fixture => widget.fixture;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final report = await fixture.report();
    if (mounted) setState(() => _report = report);
  }

  Future<void> _run(String label, Future<String> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _status = '$label running';
    });
    try {
      final result = await action();
      if (mounted) setState(() => _status = '$label: $result');
    } on Object catch (error) {
      final code = error is C1QaException ? error.code : 'qa_action_failed';
      if (mounted) setState(() => _status = '$label: $code');
    } finally {
      await _refresh();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cleanup() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _cleaned = true;
    });
    await WidgetsBinding.instance.endOfFrame;
    try {
      await fixture.cleanup();
      if (mounted) {
        setState(
          () => _status = 'Owned fixture removed; intent tombstone retained',
        );
      }
    } on Object {
      if (mounted) {
        setState(() => _status = 'Cleanup refused; preserve fixture for Lead');
      }
    }
  }

  @override
  void dispose() {
    widget.semantics.dispose();
    super.dispose();
  }

  Widget _button(String label, VoidCallback? action) => Semantics(
    label: label,
    button: true,
    enabled: action != null,
    excludeSemantics: true,
    child: GestureDetector(
      onTap: action,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: action == null
              ? const Color(0xFFE3E3E3)
              : const Color(0xFFE4F2EA),
          border: Border.all(color: const Color(0xFF1C603C)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.ltr,
    child: DefaultTextStyle(
      style: const TextStyle(color: Color(0xFF111111), fontSize: 12),
      child: Stack(
        children: [
          if (!_cleaned)
            Positioned.fill(
              child: DakhlRestaurantApp(
                key: ValueKey('${_showTarget ? 'target' : 'origin'}-$_epoch'),
                preferencesStore: fixture.preferences,
                accounts: _showTarget ? fixture.target : fixture.origin,
              ),
            )
          else
            const Positioned.fill(child: ColoredBox(color: Color(0xFFFFFFFF))),
          Positioned(
            top: 52,
            left: 8,
            right: 8,
            child: Align(
              alignment: Alignment.topLeft,
              child: _expanded
                  ? Container(
                      constraints: const BoxConstraints(maxHeight: 340),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FCF9),
                        border: Border.all(color: const Color(0xFF1C603C)),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'C1 QA | pid: $pid | boot: ${fixture.bootNonce}',
                            ),
                            Text('fixture: ${fixture.fixtureId}'),
                            Text(
                              'new: ${fixture.initializedThisLaunch} | view: ${_showTarget ? 'target' : 'origin'}',
                            ),
                            Text(
                              'checkpoint: ${_report?['checkpointExact']} | import: ${_report?['importExact']}',
                            ),
                            Text(
                              'products: ${(_report?['products'] as List?)?.length} | stock: ${_report?['stockEntries']}',
                            ),
                            Text('status: $_status'),
                            Text('QA_ROOT ${fixture.root.path}'),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                _button(
                                  'Prepare fixture',
                                  _busy || _cleaned
                                      ? null
                                      : () => _run('Prepare', () async {
                                          await fixture.prepare();
                                          if (mounted) setState(() => _epoch++);
                                          return 'prepared';
                                        }),
                                ),
                                _button(
                                  'Verify persisted',
                                  _busy || _cleaned
                                      ? null
                                      : () => _run('Verify', () async {
                                          final value = await fixture.report();
                                          return value['checkpointExact'] ==
                                                  true
                                              ? 'exact'
                                              : 'mismatch';
                                        }),
                                ),
                                _button(
                                  'Native export',
                                  _busy || _cleaned
                                      ? null
                                      : () => _run(
                                          'Export',
                                          () => fixture.exportUsing(
                                            fixture.nativeTransfer(),
                                          ),
                                        ),
                                ),
                                _button(
                                  'Native import',
                                  _busy || _cleaned
                                      ? null
                                      : () => _run(
                                          'Select import',
                                          () => fixture.selectImportUsing(
                                            fixture.nativeTransfer(),
                                          ),
                                        ),
                                ),
                                _button(
                                  'Confirm import',
                                  _busy || _cleaned
                                      ? null
                                      : () => _run(
                                          'Confirm import',
                                          fixture.confirmImport,
                                        ),
                                ),
                                _button(
                                  'Show imported',
                                  _busy || _cleaned
                                      ? null
                                      : () => _run('Show imported', () async {
                                          await fixture.ensureImportTarget();
                                          if (mounted) {
                                            setState(() {
                                              _showTarget = true;
                                              _epoch++;
                                            });
                                          }
                                          return 'ready';
                                        }),
                                ),
                                _button(
                                  'Show origin',
                                  _busy || _cleaned
                                      ? null
                                      : () => setState(() {
                                          _showTarget = false;
                                          _epoch++;
                                        }),
                                ),
                                _button(
                                  'Hide QA',
                                  () => setState(() => _expanded = false),
                                ),
                                _button(
                                  'Remove owned fixture',
                                  _busy || _cleaned ? null : _cleanup,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    )
                  : _button('Show QA', () => setState(() => _expanded = true)),
            ),
          ),
        ],
      ),
    ),
  );
}
