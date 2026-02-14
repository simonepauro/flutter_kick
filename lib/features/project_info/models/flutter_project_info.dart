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
    this.flutterVersion,
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
    this.iosAppIconPath,
    this.androidAppIconPath,
    this.iosSplashPath,
    this.androidSplashPath,
    this.iosBuildSettings = const {},
    this.androidGradleSettings = const {},
    this.iosSigningSettings = const {},
    this.androidSigningSettings = const {},
  });

  final String projectPath;
  final String name;
  final String? description;
  final String? version;
  final String? publishTo;
  final String? sdkConstraint;
  /// Versione di Flutter usata nel progetto (da `flutter --version` nella cartella del progetto).
  final String? flutterVersion;
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
  /// Percorso a un'immagine dell'icona app iOS (AppIcon.appiconset).
  final String? iosAppIconPath;
  /// Percorso a un'immagine dell'icona app Android (mipmap/drawable).
  final String? androidAppIconPath;
  /// Percorso a un'immagine della splash screen iOS (LaunchImage.imageset o simile).
  final String? iosSplashPath;
  /// Percorso a un'immagine della splash screen Android (drawable).
  final String? androidSplashPath;
  /// Build settings iOS (da Xcode project.pbxproj), es. IPHONEOS_DEPLOYMENT_TARGET, PRODUCT_BUNDLE_IDENTIFIER.
  final Map<String, String> iosBuildSettings;
  /// Impostazioni Gradle Android (da build.gradle / build.gradle.kts), es. compileSdk, minSdk, applicationId.
  final Map<String, String> androidGradleSettings;
  /// Impostazioni di code signing iOS (CODE_SIGN_STYLE, DEVELOPMENT_TEAM, PROVISIONING_PROFILE_SPECIFIER, ecc.).
  final Map<String, String> iosSigningSettings;
  /// Impostazioni di signing Android (signingConfigs: storeFile, keyAlias, ecc.).
  final Map<String, String> androidSigningSettings;
}
