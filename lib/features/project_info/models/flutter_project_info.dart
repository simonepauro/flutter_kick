import 'dependency_info.dart';

/// Voce nella lista delle icone app (iOS .appiconset o Android mipmap/drawable).
class AppIconEntry {
  const AppIconEntry({required this.path, required this.label, required this.isMain});

  final String path;
  final String label;
  final bool isMain;
}

/// Script use-X-env.sh che imposta un ambiente (es. use-staging-env.sh → "staging").
class EnvScriptInfo {
  const EnvScriptInfo({required this.envName, required this.scriptFile});

  final String envName;
  final String scriptFile;
}

/// Voce da .vscode/launch.json (nome configurazione e eventuale flavor da args).
class LaunchConfigEntry {
  const LaunchConfigEntry({required this.name, this.flavor});

  final String name;
  final String? flavor;
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
    this.launchJsonPath,
    this.launchConfigurations = const [],
    this.iosAppIconPath,
    this.androidAppIconPath,
    this.iosAppIcons = const [],
    this.androidAppIcons = const [],
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

  /// Percorso a .vscode/launch.json (configurazioni di launch/debug per i vari env).
  final String? launchJsonPath;

  /// Configurazioni lette da launch.json (nome e eventuale flavor).
  final List<LaunchConfigEntry> launchConfigurations;

  /// Percorso a un'immagine dell'icona app iOS (AppIcon.appiconset).
  final String? iosAppIconPath;

  /// Percorso a un'immagine dell'icona app Android (mipmap/drawable).
  final String? androidAppIconPath;

  /// Tutte le icone iOS rilevate (.appiconset), con etichetta e flag principale.
  final List<AppIconEntry> iosAppIcons;

  /// Tutte le icone Android rilevate (mipmap/drawable), con etichetta e flag principale.
  final List<AppIconEntry> androidAppIcons;

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
