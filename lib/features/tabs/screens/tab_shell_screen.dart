import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_kick/core/l10n/translation.dart';
import 'package:flutter_kick/core/widgets/fk_scaffold.dart';
import 'package:flutter_kick/features/tabs/models/app_tab.dart';
import 'package:flutter_kick/features/tabs/providers/tabs_provider.dart';
import 'package:flutter_kick/features/tabs/widgets/tab_content_project.dart';
import 'package:flutter_kick/features/tabs/widgets/tab_content_select_project.dart';

/// Nome visuale per una tab (nome progetto o "Nuovo").
String tabDisplayName(AppTab tab, String newLabel) {
  if (tab.projectPath != null && tab.projectPath!.isNotEmpty) {
    final segments = tab.projectPath!.replaceAll('\\', '/').split('/').where((e) => e.isNotEmpty);
    return segments.isEmpty ? tab.projectPath! : segments.last;
  }
  return newLabel;
}

class TabShellScreen extends ConsumerWidget {
  const TabShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tabsState = ref.watch(tabsProvider);
    final notifier = ref.read(tabsProvider.notifier);
    final tabs = tabsState.tabs;

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyT, meta: true): const _NewTabIntent(),
        const SingleActivator(LogicalKeyboardKey.keyW, meta: true): const _CloseTabIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _NewTabIntent: CallbackAction<_NewTabIntent>(
            onInvoke: (_) {
              notifier.addTab();
              return null;
            },
          ),
          _CloseTabIntent: CallbackAction<_CloseTabIntent>(
            onInvoke: (_) {
              if (tabsState.selectedIndex >= 0 && tabsState.selectedIndex < tabs.length) {
                notifier.closeTab(tabsState.selectedIndex);
              }
              return null;
            },
          ),
        },
        child: FKScaffold(
          body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tab bar stile browser
          Material(
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 40,
                child: Row(
                  children: [
                    Expanded(
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(left: 8, top: 4, bottom: 4),
                        children: [
                          for (var i = 0; i < tabs.length; i++) ...[
                            _TabChip(
                              label: tabDisplayName(tabs[i], t(context, 'app.tabNew')),
                              isSelected: i == tabsState.selectedIndex,
                              onTap: () => notifier.selectTab(i),
                              onClose: () => notifier.closeTab(i),
                            ),
                            const SizedBox(width: 4),
                          ],
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: IconButton(
                        icon: const Icon(Icons.add, size: 22),
                        tooltip: t(context, 'app.newTab'),
                        onPressed: () => notifier.addTab(),
                        style: IconButton.styleFrom(
                          minimumSize: const Size(36, 36),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: tabsState.selectedIndex.clamp(0, tabs.length > 0 ? tabs.length - 1 : 0),
              children: [
                for (var i = 0; i < tabs.length; i++)
                  KeyedSubtree(
                    key: ValueKey(tabs[i].id),
                    child: _buildTabContent(tabs[i]),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
    );
  }
}

class _NewTabIntent extends Intent {
  const _NewTabIntent();
}

class _CloseTabIntent extends Intent {
  const _CloseTabIntent();
}

/// Costruisce il contenuto di una tab. Usato in [IndexedStack] per tenere tutte
/// le tab in memoria (es. build in esecuzione in background).
Widget _buildTabContent(AppTab tab) {
  if (tab.projectPath != null && tab.projectPath!.isNotEmpty) {
    return TabContentProject(projectPath: tab.projectPath!);
  }
  return TabContentSelectProject(tabId: tab.id);
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.onClose,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isSelected
          ? theme.colorScheme.surface
          : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge,
                ),
              ),
              const SizedBox(width: 6),
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onClose,
                  child: Icon(
                    Icons.close,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
