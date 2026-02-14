import 'dart:convert';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_kick/features/select_project/constants/select_project_constants.dart';
import 'package:flutter_kick/features/select_project/providers/recent_projects_provider.dart';
import 'package:flutter_kick/features/select_project/providers/select_project_provider.dart';
import 'package:flutter_kick/features/select_project/widgets/select_project_drop_zone.dart';
import 'package:flutter_kick/features/select_project/widgets/select_project_header.dart';
import 'package:flutter_kick/core/widgets/fk_find_in_page_bar.dart';
import 'package:flutter_kick/core/widgets/fk_logo_app_bar.dart';
import 'package:flutter_kick/features/select_project/widgets/select_project_path_field.dart';
import 'package:flutter_kick/features/select_project/widgets/select_project_use_button.dart';
import 'package:flutter_kick/core/widgets/fk_scaffold.dart';
import 'package:flutter_kick/core/l10n/translation.dart';
import 'package:flutter_kick/features/flutter_project_detection/flutter_project_detection.dart';
import 'package:flutter_kick/features/project_info/project_info.dart';

class SelectProjectScreen extends ConsumerStatefulWidget {
  const SelectProjectScreen({super.key, this.title});

  final String? title;

  @override
  ConsumerState<SelectProjectScreen> createState() => _SelectProjectScreenState();
}

class _SelectProjectScreenState extends ConsumerState<SelectProjectScreen> {
  final TextEditingController _pathController = TextEditingController();
  final FocusNode _pathFocusNode = FocusNode();
  bool _isDragging = false;

  /// Set when user submits a valid Flutter project path; drives segmented control + panel.
  String _validatedProjectPath = '';
  int _selectedTabIndex = 0;

  /// Find in page (Cmd+F): barra di ricerca stile browser.
  bool _findBarVisible = false;
  String _searchQuery = '';
  int _searchMatchIndex = 0;
  final List<GlobalKey> _sectionKeys = List.generate(10, (_) => GlobalKey());
  final FocusNode _panelFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    ref.read(selectProjectProvider.notifier).loadLastPath();
    ref.read(recentProjectsProvider.notifier).loadRecentProjects();
  }

  void _openFindBar() {
    if (_validatedProjectPath.isNotEmpty) {
      setState(() {
        _findBarVisible = true;
        _searchMatchIndex = 0;
      });
    }
  }

  @override
  void dispose() {
    _pathController.dispose();
    _pathFocusNode.dispose();
    _panelFocusNode.dispose();
    super.dispose();
  }

  void _syncControllerFromState(String statePath) {
    if (statePath.isNotEmpty && _pathController.text != statePath) {
      _pathController.text = statePath;
      _pathController.selection = TextSelection.collapsed(offset: statePath.length);
    }
  }

  List<int> _computeSearchMatches() {
    if (_validatedProjectPath.isEmpty || _searchQuery.isEmpty) return [];
    final info = ref.read(projectInfoProvider(_validatedProjectPath)).value;
    if (info == null) return [];
    final sectionTexts = buildSectionTextsForTab(info, _selectedTabIndex);
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return [];
    final list = <int>[];
    for (var i = 0; i < sectionTexts.length; i++) {
      if (sectionTexts[i].toLowerCase().contains(q)) list.add(i);
    }
    return list;
  }

  void _scrollToSection(int sectionIndex) {
    if (sectionIndex < 0 || sectionIndex >= _sectionKeys.length) return;
    final ctx = _sectionKeys[sectionIndex].currentContext;
    if (ctx != null && mounted) {
      Scrollable.ensureVisible(ctx, alignment: 0.2, duration: const Duration(milliseconds: 300));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(selectProjectProvider);
    final notifier = ref.read(selectProjectProvider.notifier);

    if (state.path.isNotEmpty && _pathController.text.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncControllerFromState(state.path);
      });
    }

    void onPathSubmitted(String path) async {
      final trimmed = path.trim();
      if (trimmed.isEmpty) return;
      notifier.submitPath(trimmed);
      final result = await ref.read(flutterProjectDetectionProvider(trimmed).future);
      if (mounted) _notifyProjectSelected(context, result);
    }

    void onDropDone(DropDoneDetails detail) async {
      setState(() => _isDragging = false);
      if (detail.files.isEmpty) return;
      final item = detail.files.first;
      final path = item.path;
      if (path.isEmpty) return;
      // Crea il bookmark subito mentre abbiamo ancora accesso dal drag (macOS sandbox).
      // Preferiamo quello del plugin (stesso formato che resolve si aspetta); fallback su extraAppleBookmark.
      String? dropBookmark = await ref.read(secureBookmarkServiceProvider).saveBookmarkForPath(path);
      if (dropBookmark == null || dropBookmark.isEmpty) {
        final raw = item.extraAppleBookmark;
        if (raw != null && raw.isNotEmpty) dropBookmark = base64Encode(raw);
      }
      _pathController.text = path;
      notifier.setPath(path);
      await notifier.submitPath(path, preferredBookmark: dropBookmark);
      final result = await ref.read(flutterProjectDetectionProvider(path).future);
      if (mounted) _notifyProjectSelected(context, result);
    }

    final projectPath = state.path;

    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface.withOpacity(0.94);
    final cardDecoration = BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 24, offset: const Offset(0, 8))],
    );

    final searchMatches = _computeSearchMatches();
    final searchMatchCount = searchMatches.length;
    final searchMatchIndex = searchMatchCount == 0 ? 0 : (_searchMatchIndex % searchMatchCount);

    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true): const _FindInPageIntent(),
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): const _FindInPageIntent(),
        const SingleActivator(LogicalKeyboardKey.escape): const _CloseFindIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _FindInPageIntent: CallbackAction<_FindInPageIntent>(
            onInvoke: (_) {
              _openFindBar();
              return null;
            },
          ),
          _CloseFindIntent: CallbackAction<_CloseFindIntent>(
            onInvoke: (_) {
              setState(() => _findBarVisible = false);
              return null;
            },
          ),
        },
        child: FKScaffold(
          appBar: FKLogoAppBar(title: widget.title ?? t(context, 'app.title')),
          body: DropTarget(
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
                        onChanged: notifier.setPath,
                        onSubmitted: onPathSubmitted,
                        onClear: () {
                          _pathController.clear();
                          notifier.setPath('');
                          setState(() => _validatedProjectPath = '');
                        },
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: _validatedProjectPath.isEmpty
                      ? Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: kSelectProjectFormMaxWidth),
                            child: Padding(
                              padding: const EdgeInsets.all(kSelectProjectFormPadding),
                              child: Builder(
                                builder: (_) {
                                  WidgetsBinding.instance.addPostFrameCallback((_) {
                                    if (mounted && _validatedProjectPath.isEmpty) {
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
                                          onOpenProject: _openProject,
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
                                        SelectProjectUseButton(path: projectPath, onPressed: onPathSubmitted),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(horizontal: kSelectProjectFormPadding),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: kSelectProjectFormMaxWidth),
                              child: Focus(
                                focusNode: _panelFocusNode,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child:                                   SegmentedButton<int>(
                                    showSelectedIcon: false,
                                    segments: [
                                      ButtonSegment(
                                        value: 0,
                                        label: Text(t(context, 'projectInfo.tabInfo')),
                                        icon: const Icon(Icons.info_outline),
                                      ),
                                      ButtonSegment(
                                        value: 1,
                                        label: Text(t(context, 'projectInfo.tabEnv')),
                                        icon: const Icon(Icons.cloud_outlined),
                                      ),
                                      ButtonSegment(
                                        value: 2,
                                        label: Text(t(context, 'projectInfo.tabIcons')),
                                        icon: const Icon(Icons.image_outlined),
                                      ),
                                      ButtonSegment(
                                        value: 3,
                                        label: Text(t(context, 'projectInfo.tabSigning')),
                                        icon: const Icon(Icons.badge_outlined),
                                      ),
                                      ButtonSegment(
                                        value: 4,
                                        label: Text(t(context, 'projectInfo.tabRelease')),
                                        icon: const Icon(Icons.rocket_launch_outlined),
                                      ),
                                    ],
                                    selected: {_selectedTabIndex},
                                    onSelectionChanged: (Set<int> selected) {
                                      setState(() {
                                        _selectedTabIndex = selected.first;
                                        _searchMatchIndex = 0;
                                      });
                                    },
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.search),
                                          tooltip: '${t(context, 'findInPage.hint')} (⌘F)',
                                          onPressed: _openFindBar,
                                        ),
                                      ],
                                    ),
                                    if (_findBarVisible) ...[
                                    const SizedBox(height: 8),
                                    FKFindInPageBar(
                                      query: _searchQuery,
                                      onQueryChanged: (q) => setState(() {
                                        _searchQuery = q;
                                        _searchMatchIndex = 0;
                                      }),
                                      matchIndex: searchMatchCount == 0 ? 0 : searchMatchIndex + 1,
                                      matchCount: searchMatchCount,
                                      onPrevious: searchMatchCount > 0
                                          ? () {
                                              final prev = (searchMatchIndex - 1 + searchMatchCount) % searchMatchCount;
                                              setState(() => _searchMatchIndex = prev);
                                              _scrollToSection(searchMatches[prev]);
                                            }
                                          : () {},
                                      onNext: searchMatchCount > 0
                                          ? () {
                                              final next = (searchMatchIndex + 1) % searchMatchCount;
                                              setState(() => _searchMatchIndex = next);
                                              _scrollToSection(searchMatches[next]);
                                            }
                                          : () {},
                                      onClose: () => setState(() => _findBarVisible = false),
                                      hintText: t(context, 'findInPage.hint'),
                                      previousTooltip: t(context, 'findInPage.previous'),
                                      nextTooltip: t(context, 'findInPage.next'),
                                      closeTooltip: t(context, 'findInPage.close'),
                                      noResultsLabel: t(context, 'findInPage.noResults'),
                                    ),
                                  ],
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _panelFocusNode.requestFocus(),
                                      child: ProjectInfoPanel(
                                      projectPath: _validatedProjectPath,
                                      tabIndex: _selectedTabIndex,
                                      sectionKeys: _sectionKeys,
                                      highlightSectionIndex: searchMatchCount > 0
                                          ? searchMatches[searchMatchIndex]
                                          : -1,
                                    ),
                                    ),
                                  ),
                                ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _notifyProjectSelected(BuildContext context, FlutterProjectResult result) {
    final messenger = ScaffoldMessenger.of(context);
    if (result.isFlutterProject) {
      setState(() {
        _validatedProjectPath = result.path;
        _selectedTabIndex = 0;
      });
      ref.read(recentProjectsProvider.notifier).addRecentProject(result.path);
      messenger.showSnackBar(
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
      ref.read(recentProjectsProvider.notifier).removeRecentProject(result.path);
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result.errorMessageKey != null
                      ? t(context, result.errorMessageKey!, translationParams: result.errorMessageParams)
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

  Future<void> _openProject(String path) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return;
    final notifier = ref.read(selectProjectProvider.notifier);
    notifier.submitPath(trimmed);
    _pathController.text = trimmed;
    _pathController.selection = TextSelection.collapsed(offset: trimmed.length);
    final result = await ref.read(flutterProjectDetectionProvider(trimmed).future);
    if (mounted) _notifyProjectSelected(context, result);
  }
}

class _RecentProjectsSection extends StatelessWidget {
  const _RecentProjectsSection({required this.recentPaths, required this.onOpenProject});

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

class _FindInPageIntent extends Intent {
  const _FindInPageIntent();
}

class _CloseFindIntent extends Intent {
  const _CloseFindIntent();
}
