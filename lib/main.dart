import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'app/accounts_store.dart';
import 'accounts/accounts_repository.dart';
import 'accounts/accounts_view_model.dart';

import 'package:madar_flutter_adapters/madar_flutter_adapters.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = AppPreferencesStore.native();
  final accountStore = AppAccountsStore.native();
  final accounts = AccountsViewModel(
    repository: AccountsRepository(store: accountStore),
  );
  runApp(
    DakhlRestaurantApp(
      preferencesStore: preferences,
      accounts: accounts,
      accountTransfer: NativeFileTransfer(
        maxBytes: 20 * 1024 * 1024,
        fileName: 'accounts.json',
        mimeType: 'application/json',
      ),
      closeAccounts: () async {
        accounts.dispose();
        await accountStore.close();
      },
      closePreferences: preferences.close,
    ),
  );
}
