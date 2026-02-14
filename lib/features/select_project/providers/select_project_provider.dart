import 'dart:io';

import 'package:flutter_kick/core/services/secure_bookmark_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'select_project_provider.freezed.dart';
part 'select_project_provider.g.dart';

const String _kLastProjectPathKey = 'last_project_path';
const String _kLastProjectBookmarkKey = 'last_project_bookmark';

final secureBookmarkServiceProvider = Provider<SecureBookmarkService>((ref) => SecureBookmarkService());

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

  /// Carica l'ultimo percorso salvato. Su macOS usa il security-scoped bookmark
  /// se presente, così il path resta accessibile senza dover trascinare di nuovo il progetto.
  Future<void> loadLastPath() async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarkService = ref.read(secureBookmarkServiceProvider);

    // Su macOS: prova prima a risolvere il bookmark per riottenere l'accesso
    final savedBookmark = prefs.getString(_kLastProjectBookmarkKey);
    if (savedBookmark != null && savedBookmark.isNotEmpty) {
      final path = await bookmarkService.resolveAndStartAccess(savedBookmark);
      if (path != null && path.isNotEmpty) {
        state = state.copyWith(path: path);
        return;
      }
      await prefs.remove(_kLastProjectBookmarkKey);
    }

    // Fallback: path salvato come stringa (o primo avvio)
    final saved = prefs.getString(_kLastProjectPathKey);
    if (saved == null || saved.trim().isEmpty) return;

    final trimmed = saved.trim();
    bool canAccess = false;
    try {
      final dir = Directory(trimmed);
      canAccess = await dir.exists();
    } on PathAccessException {
      canAccess = false;
    } on FileSystemException {
      canAccess = false;
    }

    if (canAccess) {
      state = state.copyWith(path: trimmed);
    } else {
      await prefs.remove(_kLastProjectPathKey);
    }
  }

  /// Salva path e, su macOS, bookmark per riaprire senza trascinare di nuovo.
  /// [preferredBookmark]: se fornito (es. da desktop_drop extraAppleBookmark in base64),
  /// viene usato invece di creare un nuovo bookmark dal path — necessario perché il path
  /// da solo non ha contesto security-scoped dopo il drag.
  Future<void> submitPath(String path, {String? preferredBookmark}) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final bookmarkService = ref.read(secureBookmarkServiceProvider);

    await bookmarkService.releaseAccess();

    String? bookmark = preferredBookmark;
    if (bookmark == null || bookmark.isEmpty) {
      bookmark = await bookmarkService.saveBookmarkForPath(trimmed);
    }
    if (bookmark != null && bookmark.isNotEmpty) {
      await prefs.setString(_kLastProjectBookmarkKey, bookmark);
    } else {
      await prefs.remove(_kLastProjectBookmarkKey);
    }

    await prefs.setString(_kLastProjectPathKey, trimmed);
    state = state.copyWith(path: trimmed);
  }
}
