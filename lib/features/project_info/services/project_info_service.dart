import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:yaml/yaml.dart';

import '../models/dependency_info.dart';
import '../models/flutter_project_info.dart';

const _logName = 'ProjectInfoService';

/// Pattern per nomi flavor in build.gradle (Groovy/KTS): "flavorName" { oppure create("flavorName")
final _androidFlavorNameRegex = RegExp(
  r'(?:create\s*\(\s*["\x27](\w+)["\x27]\s*\)|["\x27](\w+)["\x27]\s*)\s*\{',
);

/// Nomi delle cartelle che indicano le piattaforme supportate.
const List<String> _platformDirs = [
  'android',
  'ios',
  'web',
  'macos',
  'windows',
  'linux',
];

/// Servizio che legge un progetto Flutter e ne estrae le informazioni.
class ProjectInfoService {
  ProjectInfoService();

  Future<FlutterProjectInfo> load(String projectPath) async {
    developer.log('load: inizio per $projectPath', name: _logName);

    final dir = Directory(projectPath);
    if (!await dir.exists()) {
      developer.log('load: cartella non trovata', name: _logName);
      throw Exception('Cartella non trovata: $projectPath');
    }

    final pubspecFile = File('${dir.path}/pubspec.yaml');
    if (!await pubspecFile.exists()) {
      developer.log('load: pubspec.yaml non trovato', name: _logName);
      throw Exception('pubspec.yaml non trovato');
    }

    final content = await pubspecFile.readAsString();
    final doc = loadYaml(content);
    if (doc == null || doc is! YamlMap) {
      developer.log('load: pubspec.yaml non valido', name: _logName);
      throw Exception('pubspec.yaml non valido');
    }

    final name = _string(doc['name']) ?? 'unknown';
    final description = _string(doc['description']);
    final version = _string(doc['version']);
    final publishTo = _string(doc['publish_to']);
    developer.log('load: pubspec letto → name=$name, version=$version', name: _logName);

    String? sdkConstraint;
    final env = doc['environment'];
    if (env is YamlMap) {
      sdkConstraint = _string(env['sdk']);
    }

    final dependencies = _dependencyEntries(doc['dependencies']);
    final devDependencies = _dependencyEntries(doc['dev_dependencies']);
    developer.log('load: dependencies=${dependencies.length}, devDependencies=${devDependencies.length}', name: _logName);

    final platforms = await _detectPlatforms(dir.path);
    final androidEnvFiles = await _detectEnvFilesForPlatform(dir.path, 'android');
    final iosEnvFiles = await _detectEnvFilesForPlatform(dir.path, 'ios');
    final androidFlavors = await _detectAndroidFlavors(dir.path);
    final iosFlavors = await _detectIosFlavors(dir.path);
    final envScripts = await _detectEnvScripts(dir.path);
    final firebaseEnvs = await _detectFirebaseEnvs(dir.path);
    final dartEnvSourceFiles = await _detectDartEnvSourceFiles(dir.path);
    final flutterVersion = await _getFlutterVersion(dir.path);
    final iosAppIconPath = await _detectIosAppIcon(dir.path);
    final androidAppIconPath = await _detectAndroidAppIcon(dir.path);
    final iosSplashPath = await _detectIosSplash(dir.path);
    final androidSplashPath = await _detectAndroidSplash(dir.path);
    final iosBuildSettings = await _readIosBuildSettings(dir.path);
    final androidGradleSettings = await _readAndroidGradleSettings(dir.path);
    final iosSigningSettings = await _readIosSigningSettings(dir.path);
    final androidSigningSettings = await _readAndroidSigningSettings(dir.path);

    developer.log('load: completato → platforms=$platforms, flutterVersion=$flutterVersion', name: _logName);

    return FlutterProjectInfo(
      projectPath: projectPath,
      name: name,
      description: description,
      version: version,
      publishTo: publishTo,
      sdkConstraint: sdkConstraint,
      flutterVersion: flutterVersion,
      dependencies: dependencies,
      devDependencies: devDependencies,
      platforms: platforms,
      androidEnvFiles: androidEnvFiles,
      iosEnvFiles: iosEnvFiles,
      androidFlavors: androidFlavors,
      iosFlavors: iosFlavors,
      envScripts: envScripts,
      firebaseEnvs: firebaseEnvs,
      dartEnvSourceFiles: dartEnvSourceFiles,
      iosAppIconPath: iosAppIconPath,
      androidAppIconPath: androidAppIconPath,
      iosSplashPath: iosSplashPath,
      androidSplashPath: androidSplashPath,
      iosBuildSettings: iosBuildSettings,
      androidGradleSettings: androidGradleSettings,
      iosSigningSettings: iosSigningSettings,
      androidSigningSettings: androidSigningSettings,
    );
  }

  /// Chiavi di build settings iOS relative alla firma (code sign, team, provisioning).
  static const _iosSigningKeys = {
    'CODE_SIGN_STYLE',
    'CODE_SIGN_IDENTITY',
    'CODE_SIGN_IDENTITY[sdk=iphoneos*]',
    'DEVELOPMENT_TEAM',
    'PROVISIONING_PROFILE_SPECIFIER',
    'PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*]',
    'CODE_SIGN_ENTITLEMENTS',
  };

  /// Legge le impostazioni di code signing iOS dal project.pbxproj (target Runner, tutti i blocchi buildSettings).
  Future<Map<String, String>> _readIosSigningSettings(String projectPath) async {
    final iosDir = Directory('$projectPath/ios');
    if (!await iosDir.exists()) return {};
    final result = <String, String>{};
    await for (final entity in iosDir.list(followLinks: false)) {
      if (entity is Directory && entity.path.endsWith('.xcodeproj')) {
        final pbxproj = File('${entity.path}/project.pbxproj');
        if (!await pbxproj.exists()) continue;
        try {
          final content = await pbxproj.readAsString();
          var inBlock = false;
          final current = <String, String>{};
          for (final line in content.split('\n')) {
            if (line.contains('buildSettings = {')) {
              inBlock = true;
              current.clear();
              continue;
            }
            if (inBlock) {
              final match = RegExp(r'^\s+([A-Za-z0-9_[\]"\s.-]+)\s*=\s*(.*);\s*$').firstMatch(line);
              if (match != null) {
                final key = match.group(1)!.trim();
                final value = match.group(2)!.trim();
                current[key] = value;
              }
              if (line.trim() == '};') {
                inBlock = false;
                final bundleId = current['PRODUCT_BUNDLE_IDENTIFIER'] ?? '';
                if (bundleId.isNotEmpty && !bundleId.contains('RunnerUITests')) {
                  for (final k in _iosSigningKeys) {
                    if (current.containsKey(k)) result[k] = current[k]!;
                  }
                }
              }
            }
          }
          if (result.isNotEmpty) {
            developer.log('_readIosSigningSettings: letti ${result.length}', name: _logName);
            return result;
          }
        } catch (e, st) {
          developer.log('_readIosSigningSettings: errore', name: _logName, error: e, stackTrace: st);
        }
        break;
      }
    }
    return result;
  }

  /// Legge le impostazioni di signing Android da build.gradle / build.gradle.kts (signingConfigs).
  Future<Map<String, String>> _readAndroidSigningSettings(String projectPath) async {
    final result = <String, String>{};
    for (final filename in ['build.gradle.kts', 'build.gradle']) {
      final file = File('$projectPath/android/app/$filename');
      if (!await file.exists()) continue;
      try {
        final content = await file.readAsString();
        final isKts = filename.endsWith('.kts');
        if (isKts) {
          _extractAndroidSigningKts(content, result);
        } else {
          _extractAndroidSigningGroovy(content, result);
        }
        if (result.isNotEmpty) {
          developer.log('_readAndroidSigningSettings: letti ${result.length} da $filename', name: _logName);
          return result;
        }
      } catch (e, st) {
        developer.log('_readAndroidSigningSettings: errore su $filename', name: _logName, error: e, stackTrace: st);
      }
      break;
    }
    return result;
  }

  void _extractAndroidSigningKts(String content, Map<String, String> out) {
    final signingBlock = _extractBlock(content, 'signingConfigs');
    if (signingBlock == null) return;
    final releaseMatch = RegExp(r'getByName\s*\(\s*[\x22\x27]release[\x22\x27]\s*\)\s*\{([^}]+)\}').firstMatch(signingBlock);
    final block = releaseMatch?.group(1) ?? signingBlock;
    _extractKtsSigningEntry(block, out);
    if (out.isEmpty) {
      final createMatch = RegExp(r'create\s*\(\s*[\x22\x27]\w+[\x22\x27]\s*\)\s*\{([^}]+)\}').firstMatch(signingBlock);
      if (createMatch != null) _extractKtsSigningEntry(createMatch.group(1)!, out);
    }
  }

  void _extractKtsSigningEntry(String block, Map<String, String> out) {
    final storeFile = RegExp(r'storeFile\s*=\s*file\s*\(\s*[\x22\x27]([^\x22\x27]+)[\x22\x27]\s*\)').firstMatch(block);
    if (storeFile != null) out['storeFile'] = storeFile.group(1)!.trim();
    final storePassword = RegExp(r'storePassword\s*=\s*[\x22\x27]([^\x22\x27]*)[\x22\x27]').firstMatch(block);
    if (storePassword != null) out['storePassword'] = storePassword.group(1)!.trim();
    final keyAlias = RegExp(r'keyAlias\s*=\s*[\x22\x27]([^\x22\x27]+)[\x22\x27]').firstMatch(block);
    if (keyAlias != null) out['keyAlias'] = keyAlias.group(1)!.trim();
    final keyPassword = RegExp(r'keyPassword\s*=\s*[\x22\x27]([^\x22\x27]*)[\x22\x27]').firstMatch(block);
    if (keyPassword != null) out['keyPassword'] = keyPassword.group(1)!.trim();
    final storeType = RegExp(r'storeType\s*=\s*[\x22\x27]([^\x22\x27]+)[\x22\x27]').firstMatch(block);
    if (storeType != null) out['storeType'] = storeType.group(1)!.trim();
  }

  void _extractAndroidSigningGroovy(String content, Map<String, String> out) {
    final signingBlock = _extractBlock(content, 'signingConfigs');
    if (signingBlock == null) return;
    final releaseMatch = RegExp(r'release\s*\{([^}]+)\}').firstMatch(signingBlock);
    final block = releaseMatch?.group(1) ?? signingBlock;
    final storeFile = RegExp(r'storeFile\s+file\s*\(\s*[\x22\x27]([^\x22\x27]+)[\x22\x27]\s*\)').firstMatch(block);
    if (storeFile != null) out['storeFile'] = storeFile.group(1)!.trim();
    final storePassword = RegExp(r'storePassword\s+[\x22\x27]([^\x22\x27]*)[\x22\x27]').firstMatch(block);
    if (storePassword != null) out['storePassword'] = storePassword.group(1)!.trim();
    final keyAlias = RegExp(r'keyAlias\s+[\x22\x27]([^\x22\x27]+)[\x22\x27]').firstMatch(block);
    if (keyAlias != null) out['keyAlias'] = keyAlias.group(1)!.trim();
    final keyPassword = RegExp(r'keyPassword\s+[\x22\x27]([^\x22\x27]*)[\x22\x27]').firstMatch(block);
    if (keyPassword != null) out['keyPassword'] = keyPassword.group(1)!.trim();
    final storeType = RegExp(r'storeType\s+[\x22\x27]([^\x22\x27]+)[\x22\x27]').firstMatch(block);
    if (storeType != null) out['storeType'] = storeType.group(1)!.trim();
    if (out.isEmpty) {
      final configMatch = RegExp(r'(\w+)\s*\{([^}]+storeFile[^}]+)\}').firstMatch(signingBlock);
      if (configMatch != null) {
        final inner = configMatch.group(2)!;
        final f = RegExp(r'storeFile\s+file\s*\(\s*[\x22\x27]([^\x22\x27]+)[\x22\x27]\s*\)').firstMatch(inner);
        if (f != null) out['storeFile'] = f.group(1)!.trim();
        final p = RegExp(r'storePassword\s+[\x22\x27]([^\x22\x27]*)[\x22\x27]').firstMatch(inner);
        if (p != null) out['storePassword'] = p.group(1)!.trim();
        final a = RegExp(r'keyAlias\s+[\x22\x27]([^\x22\x27]+)[\x22\x27]').firstMatch(inner);
        if (a != null) out['keyAlias'] = a.group(1)!.trim();
        final k = RegExp(r'keyPassword\s+[\x22\x27]([^\x22\x27]*)[\x22\x27]').firstMatch(inner);
        if (k != null) out['keyPassword'] = k.group(1)!.trim();
      }
    }
  }

  /// Estrae il contenuto del primo blocco con chiave [blockName] (es. signingConfigs { ... }).
  String? _extractBlock(String content, String blockName) {
    final start = content.indexOf(blockName);
    if (start == -1) return null;
    var depth = 0;
    var begun = false;
    for (var i = start; i < content.length; i++) {
      if (content[i] == '{') {
        depth++;
        begun = true;
      } else if (content[i] == '}') {
        depth--;
        if (begun && depth == 0) return content.substring(start, i + 1);
      }
    }
    return null;
  }

  /// Legge le build settings iOS dal primo project.pbxproj (target Runner, esclusi RunnerUITests).
  Future<Map<String, String>> _readIosBuildSettings(String projectPath) async {
    final iosDir = Directory('$projectPath/ios');
    if (!await iosDir.exists()) return {};
    final result = <String, String>{};
    await for (final entity in iosDir.list(followLinks: false)) {
      if (entity is Directory && entity.path.endsWith('.xcodeproj')) {
        final pbxproj = File('${entity.path}/project.pbxproj');
        if (!await pbxproj.exists()) continue;
        try {
          final content = await pbxproj.readAsString();
          var inBlock = false;
          final current = <String, String>{};
          for (final line in content.split('\n')) {
            if (line.contains('buildSettings = {')) {
              inBlock = true;
              current.clear();
              continue;
            }
            if (inBlock) {
              final idx = line.indexOf(' = ');
              if (idx > 0 && line.trimRight().endsWith(';')) {
                final key = line.substring(0, idx).trim();
                final valuePart = line.substring(idx + 3, line.length - 1).trim();
                if (key.isNotEmpty && valuePart.isNotEmpty && !valuePart.startsWith('(')) {
                  current[key] = valuePart;
                }
              }
              if (line.trim() == '};') {
                inBlock = false;
                final bundleId = current['PRODUCT_BUNDLE_IDENTIFIER'] ?? '';
                if (bundleId.isNotEmpty && !bundleId.contains('RunnerUITests') && result.isEmpty) {
                  result.addAll(current);
                  developer.log('_readIosBuildSettings: letti ${current.length} da ${entity.uri.pathSegments.last}', name: _logName);
                  return result;
                }
              }
            }
          }
        } catch (e, st) {
          developer.log('_readIosBuildSettings: errore', name: _logName, error: e, stackTrace: st);
        }
        break;
      }
    }
    return result;
  }

  /// Legge le impostazioni principali da build.gradle o build.gradle.kts (android/app).
  Future<Map<String, String>> _readAndroidGradleSettings(String projectPath) async {
    final result = <String, String>{};
    for (final filename in ['build.gradle.kts', 'build.gradle']) {
      final file = File('$projectPath/android/app/$filename');
      if (!await file.exists()) continue;
      try {
        final content = await file.readAsString();
        final isKts = filename.endsWith('.kts');
        _extractGradleKey(content, result, 'namespace', isKts);
        _extractGradleKey(content, result, 'compileSdk', isKts);
        _extractGradleKey(content, result, 'ndkVersion', isKts);
        _extractGradleKey(content, result, 'minSdkVersion', isKts);
        _extractGradleKey(content, result, 'targetSdkVersion', isKts);
        _extractGradleKey(content, result, 'versionCode', isKts);
        _extractGradleKey(content, result, 'versionName', isKts);
        _extractGradleKey(content, result, 'applicationId', isKts);
        _extractGradleKey(content, result, 'sourceCompatibility', isKts);
        _extractGradleKey(content, result, 'targetCompatibility', isKts);
        _extractGradleKey(content, result, 'jvmTarget', isKts);
        if (result.isNotEmpty) {
          developer.log('_readAndroidGradleSettings: letti ${result.length} da $filename', name: _logName);
        }
        return result;
      } catch (e, st) {
        developer.log('_readAndroidGradleSettings: errore su $filename', name: _logName, error: e, stackTrace: st);
      }
      break;
    }
    return result;
  }

  void _extractGradleKey(String content, Map<String, String> out, String key, bool isKts) {
    if (out.containsKey(key)) return;
    final patterns = isKts
        ? [
            RegExp('$key\\s*=\\s*["\']([^"\']+)["\']'),
            RegExp('$key\\s*=\\s*(\\d+)'),
            RegExp('$key\\s*=\\s*([A-Za-z0-9_.]+)'),
          ]
        : [
            RegExp('$key\\s+["\']([^"\']+)["\']'),
            RegExp('$key\\s+(\\d+)'),
            RegExp('$key\\s+([A-Za-z0-9_.]+)'),
          ];
    for (final re in patterns) {
      final m = re.firstMatch(content);
      if (m != null && m.group(1) != null) {
        out[key] = m.group(1)!.trim();
        return;
      }
    }
  }

  /// Restituisce il percorso a un'immagine della splash screen iOS (LaunchImage.imageset o simile in Assets.xcassets).
  /// Considera anche l'immagine referenziata in LaunchScreen.storyboard (es. LaunchBackground.imageset).
  Future<String?> _detectIosSplash(String projectPath) async {
    final assetsDir = Directory('$projectPath/ios/Runner/Assets.xcassets');
    if (!await assetsDir.exists()) {
      developer.log('_detectIosSplash: Assets.xcassets non trovato', name: _logName);
      return null;
    }
    // Nomi imageset da storyboard (es. LaunchScreen con image="LaunchBackground" → LaunchBackground.imageset)
    final storyboardImageNames = await _getLaunchImageNamesFromStoryboard(projectPath);
    // Cerca image set: Launch*, Splash* o nome letto dallo storyboard
    final toCheck = <String>[];
    await for (final entity in assetsDir.list(followLinks: false)) {
      if (entity is Directory) {
        final name = entity.uri.pathSegments.last;
        final baseName = name.replaceAll('.imageset', '');
        final isLaunchSplash = name == 'LaunchImage.imageset' ||
            name == 'Splash.imageset' ||
            name.toLowerCase().contains('launch') ||
            name.toLowerCase().contains('splash');
        final isFromStoryboard = storyboardImageNames.isNotEmpty && storyboardImageNames.contains(baseName);
        if (isLaunchSplash || isFromStoryboard) {
          toCheck.add(entity.path);
        }
      }
    }
    for (final dirPath in toCheck) {
      final path = await _resolveFirstImageFromImageset(dirPath);
      if (path != null) {
        developer.log('_detectIosSplash: trovato $path', name: _logName);
        return path;
      }
    }
    developer.log('_detectIosSplash: nessuna splash trovata', name: _logName);
    return null;
  }

  /// Legge LaunchScreen.storyboard e restituisce i nomi delle immagini referenziate (es. ["LaunchBackground"]).
  Future<List<String>> _getLaunchImageNamesFromStoryboard(String projectPath) async {
    final storyboard = File('$projectPath/ios/Runner/Base.lproj/LaunchScreen.storyboard');
    if (!await storyboard.exists()) return [];
    try {
      final content = await storyboard.readAsString();
      final matches = RegExp(r'image name="([^"]+)"').allMatches(content);
      return matches.map((m) => m.group(1)!).where((s) => s.isNotEmpty).toList();
    } catch (_) {}
    return [];
  }

  /// Restituisce il percorso al primo file immagine trovato in un .imageset (Contents.json o primo PNG).
  Future<String?> _resolveFirstImageFromImageset(String dirPath) async {
    final contentsJson = File('$dirPath/Contents.json');
    if (await contentsJson.exists()) {
      try {
        final content = await contentsJson.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>?;
        final images = json?['images'];
        if (images is List) {
          for (final entry in images) {
            if (entry is Map && entry['filename'] != null) {
              final path = '$dirPath/${entry['filename']}';
              if (await File(path).exists()) return path;
            }
          }
        }
      } catch (_) {}
    }
    final dir = Directory(dirPath);
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.png')) {
        return entity.path;
      }
    }
    return null;
  }

  /// Restituisce il percorso a un'immagine della splash screen Android (drawable o da launch_background.xml).
  Future<String?> _detectAndroidSplash(String projectPath) async {
    final resDir = Directory('$projectPath/android/app/src/main/res');
    if (!await resDir.exists()) {
      developer.log('_detectAndroidSplash: res/ non trovato', name: _logName);
      return null;
    }
    // Nomi file comuni per splash
    const splashNames = ['splash.png', 'launch_background.png', 'splash_logo.png', 'flutter_logo.png'];
    final drawableDirs = ['drawable', 'drawable-mdpi', 'drawable-hdpi', 'drawable-xhdpi', 'drawable-xxhdpi', 'drawable-xxxhdpi'];
    for (final dirName in drawableDirs) {
      for (final name in splashNames) {
        final file = File('$projectPath/android/app/src/main/res/$dirName/$name');
        if (await file.exists()) {
          developer.log('_detectAndroidSplash: trovato ${file.path}', name: _logName);
          return file.path;
        }
      }
    }
    // Prova a leggere launch_background.xml per @drawable/xxx
    final launchBgXml = File('$projectPath/android/app/src/main/res/drawable/launch_background.xml');
    if (await launchBgXml.exists()) {
      try {
        final content = await launchBgXml.readAsString();
        final drawableRef = RegExp(r'@drawable/(\w+)').firstMatch(content);
        if (drawableRef != null) {
          final drawableName = drawableRef.group(1)!;
          for (final dirName in drawableDirs) {
            final file = File('$projectPath/android/app/src/main/res/$dirName/$drawableName.png');
            if (await file.exists()) {
              developer.log('_detectAndroidSplash: da launch_background → ${file.path}', name: _logName);
              return file.path;
            }
          }
        }
      } catch (_) {}
    }
    developer.log('_detectAndroidSplash: nessuna splash trovata', name: _logName);
    return null;
  }

  /// Restituisce il percorso a un'immagine dell'icona iOS (AppIcon.appiconset o *.appiconset).
  /// Cerca in ios/Runner/Assets.xcassets: prima AppIcon.appiconset, poi default.appiconset,
  /// poi il primo .appiconset trovato (per progetti con flavor/schemi che usano set diversi).
  Future<String?> _detectIosAppIcon(String projectPath) async {
    final assetsDir = Directory('$projectPath/ios/Runner/Assets.xcassets');
    if (!await assetsDir.exists()) {
      developer.log('_detectIosAppIcon: Assets.xcassets non trovato', name: _logName);
      return null;
    }
    final appIconSetPaths = <String>[];
    await for (final entity in assetsDir.list(followLinks: false)) {
      if (entity is Directory) {
        final name = entity.uri.pathSegments.last;
        if (name.endsWith('.appiconset')) appIconSetPaths.add(entity.path);
      }
    }
    // Ordine preferito: AppIcon > default > altri (alfabetico)
    appIconSetPaths.sort((a, b) {
      final nameA = a.split('/').last;
      final nameB = b.split('/').last;
      final orderA = nameA == 'AppIcon.appiconset' ? 0 : (nameA == 'default.appiconset' ? 1 : 2);
      final orderB = nameB == 'AppIcon.appiconset' ? 0 : (nameB == 'default.appiconset' ? 1 : 2);
      if (orderA != orderB) return orderA.compareTo(orderB);
      return nameA.compareTo(nameB);
    });
    for (final dirPath in appIconSetPaths) {
      final path = _resolveFirstImageFromAppIconSet(dirPath);
      if (path != null) {
        developer.log('_detectIosAppIcon: trovato $path', name: _logName);
        return path;
      }
    }
    developer.log('_detectIosAppIcon: nessuna icona trovata', name: _logName);
    return null;
  }

  /// Risolve il percorso al primo file immagine valido in un .appiconset (Contents.json o primo PNG).
  String? _resolveFirstImageFromAppIconSet(String appIconSetPath) {
    final contentsJson = File('$appIconSetPath/Contents.json');
    if (!contentsJson.existsSync()) return null;
    try {
      final content = contentsJson.readAsStringSync();
      final json = jsonDecode(content) as Map<String, dynamic>?;
      final images = json?['images'];
      if (images is List) {
        for (final entry in images) {
          if (entry is Map && entry['filename'] != null) {
            final path = '$appIconSetPath/${entry['filename']}';
            if (File(path).existsSync()) return path;
          }
        }
      }
    } catch (_) {}
    final dir = Directory(appIconSetPath);
    for (final entity in dir.listSync(followLinks: false)) {
      if (entity is File && entity.path.toLowerCase().endsWith('.png')) {
        return entity.path;
      }
    }
    return null;
  }

  /// Restituisce il percorso a un'immagine dell'icona Android (mipmap o drawable).
  Future<String?> _detectAndroidAppIcon(String projectPath) async {
    final resDir = Directory('$projectPath/android/app/src/main/res');
    if (!await resDir.exists()) {
      developer.log('_detectAndroidAppIcon: res/ non trovato', name: _logName);
      return null;
    }
    // Ordine preferito: xxxhdpi > xxhdpi > xhdpi > hdpi > mdpi (per avere icona ad alta risoluzione)
    const mipmapDensities = ['mipmap-xxxhdpi', 'mipmap-xxhdpi', 'mipmap-xhdpi', 'mipmap-hdpi', 'mipmap-mdpi'];
    for (final density in mipmapDensities) {
      for (final name in ['ic_launcher.png', 'ic_launcher_round.png']) {
        final file = File('$projectPath/android/app/src/main/res/$density/$name');
        if (await file.exists()) {
          developer.log('_detectAndroidAppIcon: trovato ${file.path}', name: _logName);
          return file.path;
        }
      }
    }
    // drawable fallback
    final drawableFile = File('$projectPath/android/app/src/main/res/drawable/ic_launcher.png');
    if (await drawableFile.exists()) return drawableFile.path;
    developer.log('_detectAndroidAppIcon: nessuna icona trovata', name: _logName);
    return null;
  }

  /// Esegue `flutter --version` nella cartella del progetto e restituisce la prima riga (es. "Flutter 3.24.5 • channel stable").
  /// Prova: 1) .fvm/flutter_sdk/bin/flutter, 2) comando `flutter` in PATH, 3) versione da .fvmrc o .fvm/fvm_config.json.
  Future<String?> _getFlutterVersion(String projectPath) async {
    final fvmFlutter = Platform.isWindows
        ? File('$projectPath/.fvm/flutter_sdk/bin/flutter.bat')
        : File('$projectPath/.fvm/flutter_sdk/bin/flutter');
    if (await fvmFlutter.exists()) {
      developer.log('_getFlutterVersion: uso FVM SDK ${fvmFlutter.path}', name: _logName);
      final value = await _runFlutterVersion(fvmFlutter.path, projectPath);
      if (value != null) return value;
    }
    developer.log('_getFlutterVersion: esecuzione flutter --version (PATH) in $projectPath', name: _logName);
    final fromPath = await _runFlutterVersion('flutter', projectPath);
    if (fromPath != null) return fromPath;
    final fromFvmConfig = _readFlutterVersionFromFvmConfig(projectPath);
    if (fromFvmConfig != null) {
      developer.log('_getFlutterVersion: versione da FVM config → $fromFvmConfig', name: _logName);
      return fromFvmConfig;
    }
    return null;
  }

  /// Legge la versione Flutter da .fvmrc (campo "flutter") o .fvm/fvm_config.json (campo "version" o "flutter").
  String? _readFlutterVersionFromFvmConfig(String projectPath) {
    final fvmrc = File('$projectPath/.fvmrc');
    if (fvmrc.existsSync()) {
      try {
        final content = fvmrc.readAsStringSync();
        final json = jsonDecode(content) as Map<String, dynamic>?;
        final v = json?['flutter']?.toString().trim();
        if (v != null && v.isNotEmpty) return 'Flutter $v (FVM)';
      } catch (_) {}
    }
    final configFile = File('$projectPath/.fvm/fvm_config.json');
    if (configFile.existsSync()) {
      try {
        final content = configFile.readAsStringSync();
        final json = jsonDecode(content) as Map<String, dynamic>?;
        final v = (json?['flutter'] ?? json?['version'])?.toString().trim();
        if (v != null && v.isNotEmpty) return 'Flutter $v (FVM)';
      } catch (_) {}
    }
    return null;
  }

  Future<String?> _runFlutterVersion(String executable, String workingDirectory) async {
    try {
      final result = await Process.run(
        executable,
        ['--version'],
        workingDirectory: workingDirectory,
        runInShell: true,
      );
      if (result.exitCode != 0) {
        developer.log('_runFlutterVersion: exitCode=${result.exitCode}, stderr=${result.stderr}', name: _logName);
        return null;
      }
      final stdout = (result.stdout as String).trim();
      final firstLine = stdout.split('\n').first.trim();
      final value = firstLine.isNotEmpty ? firstLine : null;
      if (value != null) developer.log('_getFlutterVersion: ok → $value', name: _logName);
      return value;
    } catch (e, st) {
      developer.log('_runFlutterVersion: errore ($executable)', name: _logName, error: e, stackTrace: st);
      return null;
    }
  }

  String? _string(dynamic value) {
    if (value == null) return null;
    return value.toString().trim();
  }

  List<DependencyInfo> _dependencyEntries(dynamic deps) {
    if (deps == null || deps is! YamlMap) return [];
    final list = <DependencyInfo>[];
    for (final key in deps.keys) {
      final name = key.toString();
      final value = deps[key];
      final constraint = _constraintString(value);
      list.add(DependencyInfo(name: name, constraint: constraint));
    }
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  String? _constraintString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.trim();
    if (value is YamlMap) {
      if (value.containsKey('sdk')) return 'sdk: ${value['sdk']}';
      if (value.containsKey('version')) return value['version'].toString();
      if (value.containsKey('path')) return 'path: ${value['path']}';
      if (value.containsKey('git')) return 'git';
    }
    return value.toString();
  }

  Future<List<String>> _detectPlatforms(String projectPath) async {
    final result = <String>[];
    for (final name in _platformDirs) {
      final dir = Directory('$projectPath/$name');
      if (await dir.exists()) result.add(name);
    }
    developer.log('_detectPlatforms: trovate ${result.length} → $result', name: _logName);
    return result;
  }

  /// Rileva i file .env per una piattaforma: root + eventuale sottocartella android/ o ios/.
  Future<List<String>> _detectEnvFilesForPlatform(String projectPath, String platform) async {
    final result = <String>{};
    // Root del progetto
    final rootDir = Directory(projectPath);
    if (await rootDir.exists()) {
      await for (final entity in rootDir.list(followLinks: false)) {
        if (entity is File) {
          final name = entity.uri.pathSegments.last;
          if (name == '.env' || (name.startsWith('.env.') && name.length > 5)) {
            result.add(name);
          }
        }
      }
    }
    // Sottocartella piattaforma (android/ o ios/)
    final platformDir = Directory('$projectPath/$platform');
    if (await platformDir.exists()) {
      await for (final entity in platformDir.list(followLinks: false)) {
        if (entity is File) {
          final name = entity.uri.pathSegments.last;
          if (name == '.env' || (name.startsWith('.env.') && name.length > 5)) {
            result.add('$platform/$name');
          }
        }
      }
    }
    final list = result.toList()..sort();
    developer.log('_detectEnvFilesForPlatform($platform): ${list.length} file → $list', name: _logName);
    return list;
  }

  /// Rileva i flavor Android (productFlavors in build.gradle).
  Future<List<String>> _detectAndroidFlavors(String projectPath) async {
    for (final filename in ['build.gradle', 'build.gradle.kts']) {
      final file = File('$projectPath/android/app/$filename');
      if (await file.exists()) {
        developer.log('_detectAndroidFlavors: trovato $filename', name: _logName);
        final content = await file.readAsString();
        final productFlavorsStart = content.indexOf('productFlavors');
        if (productFlavorsStart != -1) {
          final block = content.substring(productFlavorsStart);
          var depth = 0;
          var start = -1;
          for (var i = 0; i < block.length; i++) {
            if (block[i] == '{') {
              depth++;
              if (start == -1) start = i;
            } else if (block[i] == '}') {
              depth--;
              if (depth == 0 && start != -1) {
                final productFlavorsBlock = block.substring(start, i + 1);
                final names = <String>{};
                for (final match in _androidFlavorNameRegex.allMatches(productFlavorsBlock)) {
                  final name = match.group(1) ?? match.group(2);
                  if (name != null && name.isNotEmpty) names.add(name);
                }
                final list = names.toList()..sort();
                developer.log('_detectAndroidFlavors: ${list.length} flavor → $list', name: _logName);
                return list;
              }
            }
          }
        }
        developer.log('_detectAndroidFlavors: productFlavors non trovato in $filename', name: _logName);
        break;
      }
    }
    developer.log('_detectAndroidFlavors: nessun build.gradle in android/app/', name: _logName);
    return [];
  }

  /// Rileva gli scheme iOS (xcshareddata/xcschemes).
  Future<List<String>> _detectIosFlavors(String projectPath) async {
    final names = <String>[];
    final iosDir = Directory('$projectPath/ios');
    if (!await iosDir.exists()) {
      developer.log('_detectIosFlavors: cartella ios/ non presente', name: _logName);
      return names;
    }
    await for (final xcodeproj in iosDir.list(followLinks: false)) {
      if (xcodeproj is Directory && xcodeproj.path.endsWith('.xcodeproj')) {
        final schemesDir = Directory('${xcodeproj.path}/xcshareddata/xcschemes');
        if (await schemesDir.exists()) {
          await for (final scheme in schemesDir.list(followLinks: false)) {
            if (scheme is File && scheme.path.endsWith('.xcscheme')) {
              final name = scheme.uri.pathSegments.last.replaceAll('.xcscheme', '');
              if (name.isNotEmpty) names.add(name);
            }
          }
        }
      }
    }
    names.sort();
    developer.log('_detectIosFlavors: ${names.length} scheme → $names', name: _logName);
    return names;
  }

  /// Pattern per script use-<env>-env.sh (es. use-staging-env.sh → staging).
  static final _envScriptNameRegex = RegExp(r'^use-(.+)-env\.sh$', caseSensitive: false);

  /// Rileva gli script use-X-env.sh nella root che impostano Firebase + modulo Dart.
  Future<List<EnvScriptInfo>> _detectEnvScripts(String projectPath) async {
    final result = <EnvScriptInfo>[];
    final rootDir = Directory(projectPath);
    if (!await rootDir.exists()) return result;
    await for (final entity in rootDir.list(followLinks: false)) {
      if (entity is File) {
        final name = entity.uri.pathSegments.last;
        final match = _envScriptNameRegex.firstMatch(name);
        if (match != null) {
          final envName = match.group(1)?.trim() ?? '';
          if (envName.isNotEmpty) {
            result.add(EnvScriptInfo(envName: envName, scriptFile: name));
          }
        }
      }
    }
    result.sort((a, b) => a.envName.compareTo(b.envName));
    developer.log('_detectEnvScripts: ${result.length} script → ${result.map((e) => e.scriptFile).toList()}', name: _logName);
    return result;
  }

  /// Rileva le cartelle env sotto firebase/ con config (google-services.json o GoogleService-Info.plist).
  Future<List<String>> _detectFirebaseEnvs(String projectPath) async {
    final result = <String>[];
    final firebaseDir = Directory('$projectPath/firebase');
    if (!await firebaseDir.exists()) {
      developer.log('_detectFirebaseEnvs: cartella firebase/ non presente', name: _logName);
      return result;
    }
    await for (final entity in firebaseDir.list(followLinks: false)) {
      if (entity is Directory) {
        final dirName = entity.uri.pathSegments.last;
        if (dirName.startsWith('.')) continue;
        final hasAndroid = await File('${entity.path}/google-services.json').exists();
        final hasIos = await File('${entity.path}/GoogleService-Info.plist').exists();
        if (hasAndroid || hasIos) result.add(dirName);
      }
    }
    result.sort();
    developer.log('_detectFirebaseEnvs: ${result.length} env → $result', name: _logName);
    return result;
  }

  /// Rileva i file Dart *_env_*.txt in lib/ (sorgenti env copiate dallo script in *_env.dart).
  Future<List<String>> _detectDartEnvSourceFiles(String projectPath) async {
    final result = <String>[];
    final libDir = Directory('$projectPath/lib');
    if (!await libDir.exists()) {
      developer.log('_detectDartEnvSourceFiles: cartella lib/ non presente', name: _logName);
      return result;
    }
    await for (final entity in libDir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        final name = entity.uri.pathSegments.last;
        if (name.contains('_env_') && name.endsWith('.txt')) {
          final relative = entity.path.substring(projectPath.length + 1);
          result.add(relative);
        }
      }
    }
    result.sort();
    developer.log('_detectDartEnvSourceFiles: ${result.length} file → $result', name: _logName);
    return result;
  }
}
