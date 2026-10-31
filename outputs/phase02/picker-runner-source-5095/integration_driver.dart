// Generated fixture-only host driver, no application installation.
import 'dart:convert';
import 'dart:io';
import 'package:integration_test/integration_test_driver.dart';
Future<void> main() async => integrationDriver(timeout: const Duration(minutes: 4), responseDataCallback: (data) async { stdout.writeln('PHASE02_HOST_DRIVER_RESULT ${jsonEncode(data)}'); });
