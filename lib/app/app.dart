import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Phase 00's offline development shell. Capability probes have another entrypoint.
class DakhlRestaurantApp extends StatelessWidget {
  const DakhlRestaurantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dakhl_Restaurant Dev',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF225E44),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFFAFAF6),
        fontFamily: 'Amiri',
      ),
      home: const Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('بيئة تطوير', textAlign: TextAlign.center),
                  Text('Dakhl_Restaurant Dev', textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
