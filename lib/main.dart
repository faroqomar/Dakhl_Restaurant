import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = AppPreferencesStore.native();
  runApp(
    DakhlRestaurantApp(
      preferencesStore: preferences,
      closePreferences: preferences.close,
    ),
  );
}
