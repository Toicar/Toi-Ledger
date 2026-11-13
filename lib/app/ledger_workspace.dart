import '../l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'design_components.dart';
import 'ledger_typography.dart';
import 'app_version.dart';

class LedgerWorkspace extends StatelessWidget {
  const LedgerWorkspace({
    super.key,
    required this.child,
    required this.route,
    required this.onNavigate,
    required this.onCreate,
    this.modalOpen = false,
  });
  final Widget child;
  final String route;
  final ValueChanged<String> onNavigate;
  final VoidCallback onCreate;
  final bool modalOpen;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 1000) return child;
      final scheme = Theme.of(context).colorScheme;
      Widget destination(String path, String title, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: ListTile(
          enabled: !modalOpen,
          selected: route == path || route.startsWith('$path/'),
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 3,
          ),
          leading: Icon(icon, size: 20),
          minLeadingWidth: 20,
          title: Text(title, style: const TextStyle(fontSize: 13)),
          onTap: modalOpen ? null : () => onNavigate(path),
        ),
      );
      return Row(
        // Paint the workspace after the Navigator: route BlockSemantics would
        // otherwise hide all sidebar destinations from screen readers.
        textDirection: TextDirection.rtl,
        children: [
          Expanded(child: child),
          SizedBox(
            width: 228,
            child: Material(
              color: scheme.surfaceContainerLow,
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(color: scheme.outlineVariant, width: .8),
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 28, 20, 30),
                        child: Row(
                          children: [
                            const LedgerMark(size: 32),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'MyLedger',
                                  style: TextStyle(
                                    fontFamily: LedgerTypography.of(
                                      context,
                                    ).englishTitleFamily,
                                    fontSize: 25,
                                    color: scheme.onSurface,
                                    letterSpacing: -.9,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: FilledButton.icon(
                          onPressed: modalOpen ? null : onCreate,
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(context.l10n.newEntry),
                        ),
                      ),
                      const SizedBox(height: 30),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(14, 0, 0, 12),
                              child: Text(
                                context.l10n.mySpace,
                                style: TextStyle(
                                  fontSize: 10,
                                  letterSpacing: 2,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            destination(
                              '/',
                              context.l10n.myLedger,
                              Icons.space_dashboard_outlined,
                            ),
                            destination(
                              '/statistics',
                              context.l10n.statistics,
                              Icons.bar_chart_rounded,
                            ),
                            destination(
                              '/templates',
                              context.l10n.quickTemplates,
                              Icons.bookmark_border_rounded,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 16,
                              ),
                              child: Divider(),
                            ),
                            destination(
                              '/categories',
                              context.l10n.categories,
                              Icons.grid_view_rounded,
                            ),
                            destination(
                              '/settings',
                              context.l10n.syncSettings,
                              Icons.cloud_sync_outlined,
                            ),
                            destination(
                              '/appearance',
                              context.l10n.appearance,
                              Icons.palette_outlined,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  size: 14,
                                  color: scheme.secondary,
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    context.l10n.localFirstSafelyRecorded,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              context.l10n.everyLittleEntryIsPartOf,
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'MYLEDGER  /  $currentVersionName',
                              style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 1.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Publish route changes after layout, so the outer workspace never rebuilds
/// while the nested Navigator is installing a route or dialog.
class WorkspaceObserver extends NavigatorObserver {
  WorkspaceObserver(this.onChanged, this.onModalChanged);
  final ValueChanged<String> onChanged;
  final ValueChanged<bool> onModalChanged;
  int _popups = 0;
  void update(Route<dynamic>? route) {
    if (route is! PageRoute) return;
    final name = route.settings.name ?? '/';
    WidgetsBinding.instance.addPostFrameCallback((_) => onChanged(name));
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) {
      _popups++;
      final open = _popups > 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => onModalChanged(open));
    }
    update(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PopupRoute) {
      _popups--;
      final open = _popups > 0;
      WidgetsBinding.instance.addPostFrameCallback((_) => onModalChanged(open));
    }
    update(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      update(newRoute);
}
