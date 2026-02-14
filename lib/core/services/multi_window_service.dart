import 'dart:io';

import 'package:desktop_multi_window/desktop_multi_window.dart';

/// Servizio per gestire più finestre su desktop (macOS, Windows, Linux).
/// Su altre piattaforme le chiamate sono no-op.
class MultiWindowService {
  /// Crea e mostra una nuova finestra con la stessa UI dell'app.
  /// Su piattaforme non desktop non fa nulla.
  static Future<void> openNewWindow() async {
    if (!Platform.isMacOS && !Platform.isWindows && !Platform.isLinux) {
      return;
    }
    try {
      await WindowController.create(
        WindowConfiguration(
          arguments: 'main',
          hiddenAtLaunch: false,
        ),
      );
    } catch (_) {
      rethrow;
    }
  }

  /// Ritorna true se l'app è in esecuzione su un desktop che supporta più finestre.
  static bool get isSupported =>
      Platform.isMacOS || Platform.isWindows || Platform.isLinux;
}
