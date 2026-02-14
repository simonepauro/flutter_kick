import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_kick/core/l10n/translation.dart';
import 'package:flutter_kick/core/widgets/fk_adaptive_tab_selector.dart';
import 'package:flutter_kick/core/widgets/fk_find_in_page_bar.dart';
import 'package:flutter_kick/features/project_info/project_info.dart';
import 'package:flutter_kick/features/project_info/screens/project_info_screen.dart';

/// Contenuto di una tab quando è aperto un progetto: segmented control + panel + find in page.
class TabContentProject extends ConsumerStatefulWidget {
  const TabContentProject({super.key, required this.projectPath});

  final String projectPath;

  @override
  ConsumerState<TabContentProject> createState() => _TabContentProjectState();
}

/// Numero di segmenti (Info, Env, Icons, Signing, Release).
const int _kSegmentCount = 5;

class _TabContentProjectState extends ConsumerState<TabContentProject> {
  int _selectedTabIndex = 0;
  bool _findBarVisible = false;
  String _searchQuery = '';
  int _searchMatchIndex = 0;

  /// Una lista di key per segmento, così tutti i segmenti restano montati (IndexedStack) senza conflitti.
  late final List<List<GlobalKey>> _sectionKeysPerSegment = List.generate(
    _kSegmentCount,
    (_) => List.generate(10, (_) => GlobalKey()),
  );
  final FocusNode _panelFocusNode = FocusNode();

  @override
  void dispose() {
    _panelFocusNode.dispose();
    super.dispose();
  }

  List<int> _computeSearchMatches() {
    if (widget.projectPath.isEmpty || _searchQuery.isEmpty) return [];
    final info = ref.read(projectInfoProvider(widget.projectPath)).value;
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
    final keys = _sectionKeysPerSegment[_selectedTabIndex];
    if (sectionIndex < 0 || sectionIndex >= keys.length) return;
    final ctx = keys[sectionIndex].currentContext;
    if (ctx != null && mounted) {
      Scrollable.ensureVisible(ctx, alignment: 0.2, duration: const Duration(milliseconds: 300));
    }
  }

  @override
  Widget build(BuildContext context) {
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
              setState(() {
                _findBarVisible = true;
                _searchMatchIndex = 0;
              });
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Focus(
            focusNode: _panelFocusNode,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Toolbar stile macOS: segmented control + pulsante ricerca
                Row(
                  children: [
                    Expanded(
                      child: FkAdaptiveTabSelector(
                        segments: [
                          (value: 0, label: t(context, 'projectInfo.tabInfo'), icon: CupertinoIcons.info_circle),
                          (value: 1, label: t(context, 'projectInfo.tabEnv'), icon: CupertinoIcons.cloud),
                          (value: 2, label: t(context, 'projectInfo.tabIcons'), icon: CupertinoIcons.photo),
                          (value: 3, label: t(context, 'projectInfo.tabSigning'), icon: CupertinoIcons.lock_shield),
                          (value: 4, label: t(context, 'projectInfo.tabRelease'), icon: CupertinoIcons.rocket),
                        ],
                        selected: _selectedTabIndex,
                        iconSize: 18,
                        onSelectionChanged: (index) {
                          setState(() {
                            _selectedTabIndex = index;
                            _searchMatchIndex = 0;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(CupertinoIcons.search, size: 20),
                      tooltip: '${t(context, 'findInPage.hint')} (⌘F)',
                      onPressed: () => setState(() {
                        _findBarVisible = true;
                        _searchMatchIndex = 0;
                      }),
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
                    child: IndexedStack(
                      index: _selectedTabIndex,
                      children: List.generate(_kSegmentCount, (index) {
                        return ProjectInfoPanel(
                          key: ValueKey('segment_$index'),
                          projectPath: widget.projectPath,
                          tabIndex: index,
                          sectionKeys: _sectionKeysPerSegment[index],
                          highlightSectionIndex: index == _selectedTabIndex && searchMatchCount > 0
                              ? searchMatches[searchMatchIndex]
                              : -1,
                        );
                      }),
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
}

class _FindInPageIntent extends Intent {
  const _FindInPageIntent();
}

class _CloseFindIntent extends Intent {
  const _CloseFindIntent();
}
