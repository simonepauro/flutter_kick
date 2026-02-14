import 'dart:io';

import 'package:macos_secure_bookmarks/macos_secure_bookmarks.dart';

/// Servizio per creare e risolvere security-scoped bookmarks su macOS,
/// così l'app può riaprire l'ultimo progetto senza che l'utente debba
/// trascinarlo di nuovo. Su altre piattaforme le chiamate sono no-op (ritornano null).
class SecureBookmarkService {
  SecureBookmarkService() : _bookmarks = SecureBookmarks();

  final SecureBookmarks _bookmarks;
  FileSystemEntity? _currentAccessedEntity;

  /// Crea un bookmark per la cartella [path] (es. root del progetto).
  /// Ritorna la stringa bookmark da salvare in prefs, o null se non supportato/errore.
  Future<String?> saveBookmarkForPath(String path) async {
    try {
      final dir = Directory(path.trim());
      final bookmark = await _bookmarks.bookmark(dir);
      return bookmark;
    } catch (_) {
      return null;
    }
  }

  /// Risolve il [bookmark] salvato, avvia l'accesso security-scoped e ritorna il path.
  /// Prima di usare il path l'app deve aver chiamato questo metodo (es. al load dell'ultimo progetto).
  /// Ritorna null se il bookmark non è valido o su piattaforme non macOS.
  Future<String?> resolveAndStartAccess(String? bookmark) async {
    if (bookmark == null || bookmark.trim().isEmpty) return null;
    try {
      await releaseAccess();
      final entity = await _bookmarks.resolveBookmark(bookmark.trim(), isDirectory: true);
      final started = await _bookmarks.startAccessingSecurityScopedResource(entity);
      if (!started) return null;
      _currentAccessedEntity = entity;
      return entity.path;
    } catch (_) {
      return null;
    }
  }

  /// Rilascia l'accesso security-scoped precedentemente ottenuto (es. quando si apre un altro progetto).
  Future<void> releaseAccess() async {
    final entity = _currentAccessedEntity;
    _currentAccessedEntity = null;
    if (entity != null) {
      try {
        await _bookmarks.stopAccessingSecurityScopedResource(entity);
      } catch (_) {}
    }
  }
}
