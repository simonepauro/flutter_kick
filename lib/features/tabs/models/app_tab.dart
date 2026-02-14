/// Una tab stile browser: può essere "vuota" (selezione progetto) o mostrare un progetto.
class AppTab {
  const AppTab({
    required this.id,
    this.projectPath,
    this.path = '',
    this.validatedPath = '',
  });

  final String id;
  /// Progetto aperto; se null la tab mostra la UI di selezione progetto.
  final String? projectPath;
  /// Path in digitazione (per tab senza projectPath).
  final String path;
  /// Path validato ma non ancora "confermato" come projectPath (mostra il panel).
  final String validatedPath;

  AppTab copyWith({
    String? id,
    String? projectPath,
    String? path,
    String? validatedPath,
  }) {
    return AppTab(
      id: id ?? this.id,
      projectPath: projectPath ?? this.projectPath,
      path: path ?? this.path,
      validatedPath: validatedPath ?? this.validatedPath,
    );
  }
}
