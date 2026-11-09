import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:madar_data/madar_data.dart';
import 'package:path/path.dart' as p;

import '../accounts/accounts_repository.dart';
import '../accounts/accounts_view_model.dart';
import '../app/accounts_store.dart';
import '../app/app.dart';
import '../app/bootstrap.dart';

/// Opt-in interactive QA composition. Never opens normal application storage.
/// Each launch owns a fresh temporary root retained for inspection after exit.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final allocated = await Directory.systemTemp.createTemp('dakhl-ui-qa-');
    final root = Directory(await allocated.resolveSymbolicLinks());
    final accountsRoot = await Directory(p.join(root.path, 'accounts'))
        .create();
    final store = AppAccountsStore(
      openStore: () => PowerSyncLocalDocumentWorkspaceStore.open(
        directoryPath: accountsRoot.path,
      ),
    );
    final preferences = AppPreferencesStore(
      openStore: () => PowerSyncLocalPreferencesStore.open(
        databasePath: p.join(root.path, 'shell.sqlite'),
      ),
      closeStore: (owner) async {
        if (owner is PowerSyncLocalPreferencesStore) await owner.close();
      },
    );
    final accounts = AccountsViewModel(
      repository: AccountsRepository(store: store),
    );
    // Only the allocated synthetic location is logged, never account payloads.
    stdout.writeln(jsonEncode({'event': 'ui_qa_storage', 'root': root.path}));
    runApp(
      DakhlRestaurantApp(
        preferencesStore: preferences,
        accounts: accounts,
        // No file picker/export capability: real account files cannot be
        // imported through this QA composition.
        closeAccounts: () async {
          accounts.dispose();
          await store.close();
        },
        closePreferences: preferences.close,
      ),
    );
  } on Object {
    // Fail closed; never fall back to the native/default persistence factories.
    runApp(
      const Directionality(
        textDirection: TextDirection.rtl,
        child: Center(child: Text('تعذر بدء جلسة الاختبار المعزولة')),
      ),
    );
  }
}
