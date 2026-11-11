import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'app/ledger_app.dart';
import 'app/app_theme.dart';
import 'app/appearance_controller.dart';
import 'app/presentation_controller.dart';
import 'app/providers.dart';
import 'data/database.dart';
import 'data/ledger_repository.dart';
import 'app/language_controller.dart';
import 'l10n/app_strings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final db = LedgerDatabase(
      NativeDatabase.createInBackground(
        File(path.join(directory.path, 'myledger.sqlite')),
      ),
    );
    final repository = LedgerRepository(db);
    await repository.ledgerId;
    await repository.deviceId;
    final themeMode = await AppearancePreferences(db).read();
    final presentation = await PresentationPreferences(db).read();
    final language = await LanguagePreferences(db).read();
    runApp(
      ProviderScope(
        overrides: [
          repositoryProvider.overrideWithValue(repository),
          initialThemeModeProvider.overrideWithValue(themeMode),
          initialPresentationProvider.overrideWithValue(presentation),
          initialLanguageProvider.overrideWithValue(language),
        ],
        child: const LedgerApp(),
      ),
    );
  } catch (_) {
    runApp(
      MaterialApp(
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
        localeListResolutionCallback: (locales, supported) =>
            resolveLedgerLocale(locales),
        localizationsDelegates: const [
          AppStrings.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: Text(context.l10n.couldNotOpenTheLocalDatabase),
            ),
          ),
        ),
      ),
    );
  }
}
