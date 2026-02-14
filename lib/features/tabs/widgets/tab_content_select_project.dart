import 'dart:convert';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_kick/features/select_project/constants/select_project_constants.dart';
import 'package:flutter_kick/features/select_project/providers/recent_projects_provider.dart';
import 'package:flutter_kick/features/select_project/providers/select_project_provider.dart';
import 'package:flutter_kick/features/select_project/widgets/select_project_drop_zone.dart';
import 'package:flutter_kick/features/select_project/widgets/select_project_header.dart';
import 'package:flutter_kick/features/select_project/widgets/select_project_path_field.dart';
import 'package:flutter_kick/features/select_project/widgets/select_project_use_button.dart';
import 'package:flutter_kick/core/l10n/translation.dart';
import 'package:flutter_kick/features/flutter_project_detection/flutter_project_detection.dart';
import 'package:flutter_kick/features/flutter_project_detection/widgets/fk_project_detection_status.dart';
import 'package:flutter_kick/features/tabs/providers/tabs_provider.dart';

/// Contenuto di una tab "vuota": selezione progetto (path, drop, recenti, Usa).
class TabContentSelectProject extends ConsumerStatefulWidget {
  const TabContentSelectProject({super.key, required this.tabId});

  final String tabId;

  @override
  ConsumerState<TabContentSelectProject> createState() => _TabContentSelectProjectState();
}

class _TabContentSelectProjectState extends ConsumerState<TabContentSelectProject> {
  final TextEditingController _pathController = TextEditingController();
  final FocusNode _pathFocusNode = FocusNode();
  bool _isDragging = false;
  bool _didLoadLastPath = false;

  @override
  void dispose() {
    _pathController.dispose();
    _pathFocusNode.dispose();
    super.dispose();
  }

  void _syncControllerFromTab(String path) {
    if (path.isNotEmpty && _pathController.text != path) {
      _pathController.text = path;
      _pathController.selection = TextSelection.collapsed(offset: path.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabsState = ref.watch(tabsProvider);
    final index = tabsState.tabs.indexWhere((t) => t.id == widget.tabId);
    if (index < 0) return const SizedBox.shrink();
    final tab = tabsState.tabs[index];

    final notifier = ref.read(tabsProvider.notifier);
    final selectProjectNotifier = ref.read(selectProjectProvider.notifier);
    final projectPath = tab.path;

    // Prima tab e path vuoto: carica ultimo percorso
    final isFirstTab = tabsState.tabs.isNotEmpty && tabsState.tabs.first.id == widget.tabId;
    if (isFirstTab && !_didLoadLastPath) {
      _didLoadLastPath = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await selectProjectNotifier.loadLastPath();
        final state = ref.read(selectProjectProvider);
        if (mounted && state.path.isNotEmpty) {
          notifier.setTabPath(widget.tabId, state.path);
          _syncControllerFromTab(state.path);
        }
      });
    }

    if (projectPath.isNotEmpty && _pathController.text != projectPath) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncControllerFromTab(projectPath);
      });
    }

    Future<void> onPathSubmitted(String path) async {
      final trimmed = path.trim();
      if (trimmed.isEmpty) return;
      notifier.setTabPath(widget.tabId, trimmed);
      selectProjectNotifier.submitPath(trimmed);
      final result = await ref.read(flutterProjectDetectionProvider(trimmed).future);
      if (!mounted) return;
      if (result.isFlutterProject) {
        notifier.setTabProjectPath(widget.tabId, result.path);
        ref.read(recentProjectsProvider.notifier).addRecentProject(result.path);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(t(context, 'selectProject.validProject'))),
              ],
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } else {
        ref.read(recentProjectsProvider.notifier).removeRecentProject(trimmed);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.errorMessageKey != null
                        ? t(context, result.errorMessageKey!,
                            translationParams: result.errorMessageParams)
                        : (result.errorMessage ?? t(context, 'selectProject.notValidProject')),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    }

    Future<void> onDropDone(DropDoneDetails detail) async {
      setState(() => _isDragging = false);
      if (detail.files.isEmpty) return;
      final item = detail.files.first;
      final path = item.path;
      if (path.isEmpty) return;
      String? dropBookmark = await ref.read(secureBookmarkServiceProvider).saveBookmarkForPath(path);
      if (dropBookmark == null || dropBookmark.isEmpty) {
        final raw = item.extraAppleBookmark;
        if (raw != null && raw.isNotEmpty) dropBookmark = base64Encode(raw);
      }
      _pathController.text = path;
      notifier.setTabPath(widget.tabId, path);
      await selectProjectNotifier.submitPath(path, preferredBookmark: dropBookmark);
      final result = await ref.read(flutterProjectDetectionProvider(path).future);
      if (!mounted) return;
      if (result.isFlutterProject) {
        notifier.setTabProjectPath(widget.tabId, result.path);
        ref.read(recentProjectsProvider.notifier).addRecentProject(result.path);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(t(context, 'selectProject.validProject'))),
              ],
            ),
            backgroundColor: Colors.green.shade700,
          ),
        );
      } else {
        ref.read(recentProjectsProvider.notifier).removeRecentProject(path);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.errorMessageKey != null
                        ? t(context, result.errorMessageKey!,
                            translationParams: result.errorMessageParams)
                        : (result.errorMessage ?? t(context, 'selectProject.notValidProject')),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    }

    void onPathChanged(String path) {
      notifier.setTabPath(widget.tabId, path);
      selectProjectNotifier.setPath(path);
    }

    Future<void> openProject(String path) async {
      final trimmed = path.trim();
      if (trimmed.isEmpty) return;
      selectProjectNotifier.submitPath(trimmed);
      _pathController.text = trimmed;
      _pathController.selection = TextSelection.collapsed(offset: trimmed.length);
      notifier.setTabPath(widget.tabId, trimmed);
      final result = await ref.read(flutterProjectDetectionProvider(trimmed).future);
      if (mounted) {
        if (result.isFlutterProject) {
          notifier.setTabProjectPath(widget.tabId, result.path);
          ref.read(recentProjectsProvider.notifier).addRecentProject(result.path);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(child: Text(t(context, 'selectProject.validProject'))),
                ],
              ),
              backgroundColor: Colors.green.shade700,
            ),
          );
        } else {
          ref.read(recentProjectsProvider.notifier).removeRecentProject(trimmed);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      result.errorMessageKey != null
                          ? t(context, result.errorMessageKey!,
                              translationParams: result.errorMessageParams)
                          : (result.errorMessage ?? t(context, 'selectProject.notValidProject')),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.orange.shade800,
            ),
          );
        }
      }
    }

    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface.withOpacity(0.94);
    final cardDecoration = BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.12),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    );

    return DropTarget(
      onDragDone: onDropDone,
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(kSelectProjectFormPadding),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kSelectProjectFormMaxWidth),
                child: SelectProjectPathField(
                  controller: _pathController,
                  focusNode: _pathFocusNode,
                  path: projectPath,
                  onChanged: onPathChanged,
                  onSubmitted: onPathSubmitted,
                  onClear: () {
                    _pathController.clear();
                    onPathChanged('');
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kSelectProjectFormMaxWidth),
                child: Padding(
                  padding: const EdgeInsets.all(kSelectProjectFormPadding),
                  child: Builder(
                    builder: (_) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          ref.read(recentProjectsProvider.notifier).loadRecentProjects();
                        }
                      });
                      return Container(
                        decoration: cardDecoration,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SelectProjectHeader(),
                            const SizedBox(height: kSelectProjectFormPadding),
                            _RecentProjectsSection(
                              recentPaths: ref.watch(recentProjectsProvider),
                              onOpenProject: openProject,
                            ),
                            const SizedBox(height: kSelectProjectFormPadding),
                            FKProjectDetectionStatus(projectPath: projectPath),
                            const SizedBox(height: 16),
                            SelectProjectDropZone(
                              isDragging: _isDragging,
                              onDragEntered: () => setState(() => _isDragging = true),
                              onDragExited: () => setState(() => _isDragging = false),
                              onDropDone: onDropDone,
                            ),
                            const SizedBox(height: kSelectProjectFormPadding),
                            SelectProjectUseButton(
                              path: projectPath,
                              onPressed: onPathSubmitted,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentProjectsSection extends StatelessWidget {
  const _RecentProjectsSection({
    required this.recentPaths,
    required this.onOpenProject,
  });

  final List<String> recentPaths;
  final void Function(String path) onOpenProject;

  static String _displayName(String path) {
    final segments = path.replaceAll('\\', '/').split('/').where((e) => e.isNotEmpty);
    return segments.isEmpty ? path : segments.last;
  }

  @override
  Widget build(BuildContext context) {
    if (recentPaths.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            t(context, 'selectProject.recentProjects'),
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 160),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: recentPaths.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final path = recentPaths[index];
              final name = _displayName(path);
              return ListTile(
                dense: true,
                leading: const Icon(Icons.folder_outlined, size: 20),
                title: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                subtitle: path != name
                    ? Text(path, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall)
                    : null,
                onTap: () => onOpenProject(path),
              );
            },
          ),
        ),
      ],
    );
  }
}
