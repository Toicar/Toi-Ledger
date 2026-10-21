import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../features/ledger/ledger_home.dart';

class LedgerApp extends StatelessWidget {
  const LedgerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'MyLedger',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorSchemeSeed: const Color(0xff176b60),
      useMaterial3: true,
    ),
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    home: const LedgerHome(),
  );
}
