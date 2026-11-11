import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_theme.dart';
import 'appearance_controller.dart';
import 'presentation_controller.dart';
import 'ledger_material.dart';
import '../features/ledger/ledger_home.dart';
import '../features/ledger/entry_editor.dart';
import '../features/statistics/statistics_page.dart';
import '../features/templates/templates_page.dart';
import '../features/categories/categories_page.dart';
import '../features/appearance/appearance_page.dart';
import '../features/sync/settings_page.dart';
import 'ledger_workspace.dart';
import 'providers.dart';
import 'language_controller.dart';
import '../l10n/app_strings.dart';

class LedgerApp extends ConsumerStatefulWidget {
  const LedgerApp({super.key});
  @override
  ConsumerState<LedgerApp> createState() => _LedgerAppState();
}

class _LedgerAppState extends ConsumerState<LedgerApp> {
  final navigator = GlobalKey<NavigatorState>();
  String route = '/';
  bool modalOpen = false;
  late final observer = WorkspaceObserver(
    (name) {
      if (mounted && name != route) setState(() => route = name);
    },
    (open) {
      if (mounted && open != modalOpen) setState(() => modalOpen = open);
    },
  );
  void navigate(String name) {
    if (name == route) return;
    if (name == '/') {
      navigator.currentState?.popUntil((r) => r.isFirst);
    } else {
      navigator.currentState?.pushNamedAndRemoveUntil(name, (r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    navigatorKey: navigator,
    navigatorObservers: [observer],
    title: 'MyLedger',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.resolve(
      Brightness.light,
      ref.watch(presentationProvider).style,
      accent: ref.watch(presentationProvider).accent,
    ),
    darkTheme: AppTheme.resolve(
      Brightness.dark,
      ref.watch(presentationProvider).style,
      accent: ref.watch(presentationProvider).accent,
    ),
    themeMode: ref.watch(appearanceProvider),
    builder: (context, child) => LedgerCanvas(
      child: LedgerWorkspace(
        route: route,
        modalOpen: modalOpen,
        onNavigate: navigate,
        onCreate: () async {
          final views = ref.read(entitiesProvider).asData?.value;
          final context = navigator.currentContext;
          if (views != null && context != null) {
            await showDialog<void>(
              context: context,
              builder: (_) => EntryEditor(views: views),
            );
            if (mounted) ref.read(syncRequestProvider.notifier).state++;
          }
        },
        child: child ?? const SizedBox(),
      ),
    ),
    routes: {
      '/statistics': (_) => const StatisticsPage(),
      '/templates': (_) => const TemplatesPage(),
      '/categories': (_) => const CategoriesPage(),
      '/settings': (_) => const SettingsPage(),
      '/appearance': (_) => const AppearancePage(),
    },
    locale: switch (ref.watch(languageProvider)) {
      LedgerLanguage.system => null,
      LedgerLanguage.zh => const Locale('zh', 'CN'),
      LedgerLanguage.en => const Locale('en'),
    },
    localeListResolutionCallback: (locales, supported) =>
        resolveLedgerLocale(locales),
    supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
    localizationsDelegates: const [
      AppStrings.delegate,
      ...GlobalMaterialLocalizations.delegates,
    ],
    home: const LedgerHome(),
  );
}
