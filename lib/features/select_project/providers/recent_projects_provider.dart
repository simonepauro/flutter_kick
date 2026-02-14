import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'recent_projects_provider.g.dart';

const String _kRecentProjectsKey = 'recent_project_paths';
const int maxRecentProjects = 15;

/// Provider per lo storico dei progetti aperti (solo progetti Flutter validi).
@riverpod
class RecentProjects extends _$RecentProjects {
  @override
  List<String> build() => [];

  Future<void> loadRecentProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kRecentProjectsKey) ?? [];
    state = list;
  }

  /// Aggiunge un percorso allo storico. Chiamare solo dopo aver verificato
  /// che il progetto sia valido (FlutterProjectResult.isFlutterProject).
  Future<void> addRecentProject(String path) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    var list = prefs.getStringList(_kRecentProjectsKey) ?? [];
    list = [trimmed, ...list.where((p) => p != trimmed)];
    list = list.take(maxRecentProjects).toList();
    await prefs.setStringList(_kRecentProjectsKey, list);
    state = list;
  }

  Future<void> removeRecentProject(String path) async {
    final prefs = await SharedPreferences.getInstance();
    var list = prefs.getStringList(_kRecentProjectsKey) ?? [];
    list = list.where((p) => p != path).toList();
    await prefs.setStringList(_kRecentProjectsKey, list);
    state = list;
  }
}
