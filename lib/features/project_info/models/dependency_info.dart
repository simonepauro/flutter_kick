/// Informazioni su una dipendenza (nome + constraint dal pubspec).
class DependencyInfo {
  const DependencyInfo({required this.name, this.constraint});

  final String name;
  /// Vincolo di versione dal pubspec (es. ^1.0.0, sdk: flutter).
  final String? constraint;

  @override
  String toString() => constraint != null ? '$name $constraint' : name;
}

/// Stato di aggiornamento da `dart pub outdated --json`.
class OutdatedPackageInfo {
  const OutdatedPackageInfo({
    required this.package,
    this.current,
    this.upgradable,
    this.resolvable,
    this.latest,
  });

  final String package;
  final String? current;
  final String? upgradable;
  final String? resolvable;
  final String? latest;

  /// True se è possibile aggiornare con `pub upgrade` (current != upgradable).
  bool get hasUpgradable =>
      current != null &&
      upgradable != null &&
      current != upgradable;

  /// True se c'è una versione più nuova compatibile (current != latest quando resolvable/latest > current).
  bool get hasUpdate =>
      hasUpgradable ||
      (latest != null && current != null && current != latest);
}

/// Esito del check in background (outdated + deprecate).
class DependencyStatusInfo {
  const DependencyStatusInfo({
    this.outdated = const {},
    this.deprecated = const {},
  });

  final Map<String, OutdatedPackageInfo> outdated;
  final Set<String> deprecated;

  bool hasUpdate(String packageName) =>
      outdated[packageName]?.hasUpdate ?? false;

  bool isDeprecated(String packageName) => deprecated.contains(packageName);

  bool shouldHighlight(String packageName) =>
      hasUpdate(packageName) || isDeprecated(packageName);
}
