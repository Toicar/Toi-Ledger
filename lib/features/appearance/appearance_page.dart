import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/appearance_controller.dart';
import '../../app/presentation_controller.dart';
import '../../app/theme_accent.dart';
import '../../app/ledger_material.dart';
import '../../app/ui_common.dart';
import '../../app/design_components.dart';
import '../../app/ledger_typography.dart';

class AppearancePage extends ConsumerStatefulWidget {
  const AppearancePage({super.key});
  @override
  ConsumerState<AppearancePage> createState() => _AppearancePageState();
}

class _AppearancePageState extends ConsumerState<AppearancePage> {
  bool saving = false;
  Future<void> save(Future<void> Function() action) async {
    setState(() => saving = true);
    try {
      await action();
    } catch (_) {
      if (mounted) notify(context, '外观设置保存失败，请重试');
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(appearanceProvider);
    final settings = ref.watch(presentationProvider);
    final theme = Theme.of(context), colors = theme.colorScheme;
    final controller = ref.read(presentationProvider.notifier);
    final dark = theme.brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('外观')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PageHeading(
                  eyebrow: 'MAKE YOURSELF AT HOME',
                  title: '舒适，随你选择。',
                  description: '选一种触感，留一抹喜欢的颜色。',
                ),
                LedgerSurface(
                  child: Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const LedgerMark(size: 32),
                            const SizedBox(width: 12),
                            Text(
                              'MyLedger',
                              style: LedgerTypography.of(context).title(27),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '一点一滴，皆是生活。',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '¥1,280.50',
                          style: LedgerTypography.of(
                            context,
                          ).number(size: 28, color: colors.primary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${settings.accent.label} · ${settings.style == LedgerStyle.satin ? '细腻磨砂' : '通透玻璃'}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text('界面材质', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text('纸面的安静，或光线的流动。', style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final style in LedgerStyle.values)
                        SizedBox(
                          width: constraints.maxWidth < 350
                              ? constraints.maxWidth
                              : (constraints.maxWidth - 12) / 2,
                          child: Semantics(
                            selected: settings.style == style,
                            button: true,
                            child: InkWell(
                              key: ValueKey('material-${style.name}'),
                              borderRadius: BorderRadius.circular(16),
                              onTap: saving
                                  ? null
                                  : () =>
                                        save(() => controller.setStyle(style)),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colors.surface.withValues(alpha: .65),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: settings.style == style
                                        ? colors.primary
                                        : colors.outlineVariant,
                                    width: settings.style == style ? 1.7 : .8,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    LedgerMaterialSample(
                                      style: style,
                                      seed: settings.accent.seed,
                                      dark: dark,
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            style == LedgerStyle.satin
                                                ? '细腻磨砂'
                                                : '通透玻璃',
                                            style: theme.textTheme.titleSmall,
                                          ),
                                        ),
                                        if (settings.style == style)
                                          Icon(
                                            Icons.check_circle,
                                            size: 19,
                                            color: colors.primary,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      style == LedgerStyle.satin
                                          ? '温润纸纹 · 不透明表面 · 柔和阴影'
                                          : '流动底色 · 半透明叠层 · 细亮边缘',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text('主题色', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text('取意中国色，随明暗模式呈现不同色阶。', style: theme.textTheme.bodySmall),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) => Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final accent in LedgerAccent.values)
                        SizedBox(
                          width: (constraints.maxWidth - 20) / 3,
                          child: Semantics(
                            selected: settings.accent == accent,
                            button: true,
                            child: InkWell(
                              key: ValueKey('accent-${accent.name}'),
                              borderRadius: BorderRadius.circular(12),
                              onTap: saving
                                  ? null
                                  : () => save(
                                      () => controller.setAccent(accent),
                                    ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 13,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.seed.withValues(
                                    alpha: dark ? .13 : .08,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: settings.accent == accent
                                        ? colors.primary
                                        : colors.outlineVariant,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: BoxDecoration(
                                        color: accent.seed,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: colors.onSurface.withValues(
                                            alpha: .10,
                                          ),
                                        ),
                                      ),
                                      child: settings.accent == accent
                                          ? Icon(
                                              Icons.check,
                                              size: 17,
                                              color:
                                                  accent.seed
                                                          .computeLuminance() >
                                                      .45
                                                  ? Colors.black87
                                                  : Colors.white,
                                            )
                                          : null,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      accent.label,
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                Text('明暗模式', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      for (final mode in ThemeMode.values) ...[
                        if (mode != ThemeMode.system)
                          const Divider(indent: 20, endIndent: 20),
                        ListTile(
                          enabled: !saving,
                          selected: selected == mode,
                          leading: Icon(switch (mode) {
                            ThemeMode.system => Icons.brightness_auto_outlined,
                            ThemeMode.light => Icons.light_mode_outlined,
                            ThemeMode.dark => Icons.dark_mode_outlined,
                          }),
                          title: Text(switch (mode) {
                            ThemeMode.system => '跟随系统',
                            ThemeMode.light => '浅色',
                            ThemeMode.dark => '深色',
                          }),
                          subtitle: mode == ThemeMode.system
                              ? const Text('随设备的外观自动切换')
                              : null,
                          trailing: selected == mode
                              ? Icon(Icons.check_circle, color: colors.primary)
                              : const Icon(Icons.circle_outlined, size: 22),
                          onTap: saving
                              ? null
                              : () => save(
                                  () => ref
                                      .read(appearanceProvider.notifier)
                                      .setMode(mode),
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('仅应用于这台设备，下次打开时保留。', style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
