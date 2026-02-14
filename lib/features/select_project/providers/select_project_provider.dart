import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'select_project_provider.freezed.dart';
part 'select_project_provider.g.dart';

const String _kLastProjectPathKey = 'last_project_path';

@freezed
abstract class SelectProjectState with _$SelectProjectState {
  factory SelectProjectState({@Default('') String path}) = _SelectProjectState;
}

@riverpod
class SelectProject extends _$SelectProject {
  @override
  SelectProjectState build() {
    return SelectProjectState();
  }

  void setPath(String path) {
    state = state.copyWith(path: path);
  }

  Future<void> loadLastPath() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kLastProjectPathKey);
    if (saved != null && saved.isNotEmpty) {
      state = state.copyWith(path: saved);
    }
  }

  Future<void> submitPath(String path) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLastProjectPathKey, trimmed);
    state = state.copyWith(path: trimmed);
  }
}
