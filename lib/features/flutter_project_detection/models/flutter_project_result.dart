/// Risultato della verifica se una cartella è un progetto Flutter.
class FlutterProjectResult {
  const FlutterProjectResult({
    required this.path,
    required this.isFlutterProject,
    this.errorMessageKey,
    this.errorMessageParams,
    this.errorMessage,
  });

  final String path;
  final bool isFlutterProject;

  /// Chiave i18n per il messaggio di errore (es. errors.emptyPath).
  final String? errorMessageKey;

  /// Parametri per la traduzione (es. {'message': '...'}).
  final Map<String, String>? errorMessageParams;

  /// Messaggio raw, usato come fallback se [errorMessageKey] è null.
  final String? errorMessage;

  bool get isValid => isFlutterProject;
}
