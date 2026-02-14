import 'dependency_info.dart';

/// Script use-X-env.sh che imposta un ambiente (es. use-staging-env.sh → "staging").
class EnvScriptInfo {
  const EnvScriptInfo({required this.envName, required this.scriptFile});

  final String envName;
  final String scriptFile;
}

/// Informazioni estratte da un progetto Flutter (pubspec + struttura cartelle).
class FlutterProjectInfo {
  const FlutterProjectInfo({
    required this.projectPath,
    required this.name,
    this.description,
    this.version,
    this.publishTo,
    this.sdkConstraint,
    this.dependencies = const [],
    this.devDependencies = const [],
    this.platforms = const [],
    this.androidEnvFiles = const [],
    this.iosEnvFiles = const [],
    this.androidFlavors = const [],
    this.iosFlavors = const [],
    this.envScripts = const [],
    this.firebaseEnvs = const [],
    this.dartEnvSourceFiles = const [],
  });

  final String projectPath;
  final String name;
  final String? description;
  final String? version;
  final String? publishTo;
  final String? sdkConstraint;
  final List<DependencyInfo> dependencies;
  final List<DependencyInfo> devDependencies;
  final List<String> platforms;
  /// File .env rilevati per Android (root + android/).
  final List<String> androidEnvFiles;
  /// File .env rilevati per iOS (root + ios/).
  final List<String> iosEnvFiles;
  /// Flavor Android (productFlavors in build.gradle).
  final List<String> androidFlavors;
  /// Scheme iOS (xcshareddata/xcschemes).
  final List<String> iosFlavors;
  /// Script use-X-env.sh che copiano Firebase + modulo Dart (es. use-staging-env.sh).
  final List<EnvScriptInfo> envScripts;
  /// Cartelle env sotto firebase/ con config (google-services.json / GoogleService-Info.plist).
  final List<String> firebaseEnvs;
  /// File Dart sorgente env (es. lib/.../tablo_env_staging.txt) copiati dallo script.
  final List<String> dartEnvSourceFiles;
}
