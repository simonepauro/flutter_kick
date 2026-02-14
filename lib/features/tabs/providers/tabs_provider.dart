import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_kick/features/tabs/models/app_tab.dart';

/// Stato delle tab (lista + indice selezionato).
class TabsState {
  const TabsState({required this.tabs, this.selectedIndex = 0});

  final List<AppTab> tabs;
  final int selectedIndex;

  AppTab? get selectedTab {
    if (selectedIndex < 0 || selectedIndex >= tabs.length) return null;
    return tabs[selectedIndex];
  }
}

class TabsNotifier extends Notifier<TabsState> {
  static int _idCounter = 0;
  static String _nextId() => 'tab_${_idCounter++}';

  @override
  TabsState build() {
    return TabsState(tabs: [AppTab(id: _nextId())], selectedIndex: 0);
  }

  void addTab() {
    state = TabsState(
      tabs: [...state.tabs, AppTab(id: _nextId())],
      selectedIndex: state.tabs.length,
    );
  }

  void closeTab(int index) {
    if (index < 0 || index >= state.tabs.length) return;
    final newTabs = List<AppTab>.from(state.tabs)..removeAt(index);
    if (newTabs.isEmpty) return;
    var newIndex = state.selectedIndex;
    if (index < state.selectedIndex) {
      newIndex = state.selectedIndex - 1;
    } else if (index == state.selectedIndex) {
      newIndex = (state.selectedIndex >= newTabs.length) ? newTabs.length - 1 : state.selectedIndex;
    }
    state = TabsState(tabs: newTabs, selectedIndex: newIndex.clamp(0, newTabs.length - 1));
  }

  void closeTabById(String id) {
    final index = state.tabs.indexWhere((t) => t.id == id);
    if (index >= 0) closeTab(index);
  }

  void selectTab(int index) {
    if (index < 0 || index >= state.tabs.length) return;
    state = TabsState(tabs: state.tabs, selectedIndex: index);
  }

  void setTabPath(String tabId, String path) {
    state = TabsState(
      tabs: state.tabs.map((t) => t.id == tabId ? t.copyWith(path: path) : t).toList(),
      selectedIndex: state.selectedIndex,
    );
  }

  void setTabValidatedPath(String tabId, String validatedPath) {
    state = TabsState(
      tabs: state.tabs
          .map((t) => t.id == tabId ? t.copyWith(validatedPath: validatedPath) : t)
          .toList(),
      selectedIndex: state.selectedIndex,
    );
  }

  /// Imposta il progetto aperto nella tab (e resetta path/validatedPath).
  void setTabProjectPath(String tabId, String projectPath) {
    state = TabsState(
      tabs: state.tabs
          .map((t) =>
              t.id == tabId ? t.copyWith(projectPath: projectPath, path: '', validatedPath: '') : t)
          .toList(),
      selectedIndex: state.selectedIndex,
    );
  }

  void setTabPathAndValidated(String tabId, String path, String validatedPath) {
    state = TabsState(
      tabs: state.tabs
          .map((t) => t.id == tabId ? t.copyWith(path: path, validatedPath: validatedPath) : t)
          .toList(),
      selectedIndex: state.selectedIndex,
    );
  }
}

final tabsProvider = NotifierProvider<TabsNotifier, TabsState>(TabsNotifier.new);
