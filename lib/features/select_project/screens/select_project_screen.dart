import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_kick/features/select_project/constants/select_project_constants.dart';
import 'package:flutter_kick/features/select_project/providers/select_project_provider.dart';
import 'package:flutter_kick/features/select_project/widgets/select_project_drop_zone.dart';
import 'package:flutter_kick/features/select_project/widgets/select_project_header.dart';
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

  @override
  void initState() {
    super.initState();
    ref.read(selectProjectProvider.notifier).loadLastPath();
  }

  @override
  void dispose() {
    _pathController.dispose();
    _pathFocusNode.dispose();
    super.dispose();
  }

  void _syncControllerFromState(String statePath) {
    if (statePath.isNotEmpty && _pathController.text != statePath) {
      _pathController.text = statePath;
      _pathController.selection = TextSelection.collapsed(offset: statePath.length);
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
      final path = detail.files.first.path;
      if (path.isEmpty) return;
      _pathController.text = path;
      notifier.setPath(path);
      notifier.submitPath(path);
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

    return FKScaffold(
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
                          child: Container(
                            decoration: cardDecoration,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SelectProjectHeader(),
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
                          ),
                        ),
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: kSelectProjectFormPadding),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: kSelectProjectFormMaxWidth),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SegmentedButton<int>(
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
                                ],
                                selected: {_selectedTabIndex},
                                onSelectionChanged: (Set<int> selected) =>
                                    setState(() => _selectedTabIndex = selected.first),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                child: ProjectInfoPanel(
                                  projectPath: _validatedProjectPath,
                                  tabIndex: _selectedTabIndex,
                                ),
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
    );
  }

  void _notifyProjectSelected(BuildContext context, FlutterProjectResult result) {
    final messenger = ScaffoldMessenger.of(context);
    if (result.isFlutterProject) {
      setState(() {
        _validatedProjectPath = result.path;
        _selectedTabIndex = 0;
      });
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
}
