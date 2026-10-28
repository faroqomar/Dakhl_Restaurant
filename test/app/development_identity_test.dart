import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const identifier = 'com.eros.dakhlrestaurant.phase00';

  test('Android app and namespace use the isolated development identifier', () {
    final config = File('android/app/build.gradle.kts').readAsStringSync();
    expect(config, contains('namespace = "$identifier"'));
    expect(config, contains('applicationId = "$identifier"'));
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(manifest, contains('android:label="Dakhl_Restaurant Dev"'));
    expect(manifest, isNot(contains('android.permission.INTERNET')));
  });

  test('Apple bundles use the isolated development identifier and name', () {
    final ios = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    expect(ios, contains('PRODUCT_BUNDLE_IDENTIFIER = $identifier;'));
    expect(
      ios,
      isNot(contains('PRODUCT_BUNDLE_IDENTIFIER = com.eros.daftar;')),
    );
    expect(
      File('ios/Runner/Info.plist').readAsStringSync(),
      contains('<string>Dakhl_Restaurant Dev</string>'),
    );
    final macos = File('macos/Runner/Configs/AppInfo.xcconfig')
        .readAsStringSync();
    expect(macos, contains('PRODUCT_BUNDLE_IDENTIFIER = $identifier'));
    expect(macos, contains('PRODUCT_NAME = Dakhl_Restaurant Dev'));
  });
}
