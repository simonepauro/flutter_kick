import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:yaml/yaml.dart';

import '../models/dependency_info.dart';
import '../models/flutter_project_info.dart';

const _logName = 'ProjectInfoService';

/// Voce launcher grezza dal manifest Android (prima di assegnare isMain).
class _AndroidLauncherRaw {
  const _AndroidLauncherRaw({required this.iconRef, this.label, required this.isActivity, required this.enabled});
  final String iconRef;
  final String? label;
  final bool isActivity;
  final bool enabled;
}

/// Voce launcher dal manifest con flag principale (per UI).
class _AndroidLauncherEntry {
  const _AndroidLauncherEntry({required this.iconRef, this.label, required this.isMain});
  final String iconRef;
  final String? label;
  final bool isMain;
}

/// Pattern per nomi flavor in build.gradle (Groovy/KTS): "flavorName" { oppure create("flavorName")
final _androidFlavorNameRegex = RegExp(r'(?:create\s*\(\s*["\x27](\w+)["\x27]\s*\)|["\x27](\w+)["\x27]\s*)\s*\{');

/// Nomi delle cartelle che indicano le piattaforme supportate.
const List<String> _platformDirs = ['android', 'ios', 'web', 'macos', 'windows', 'linux'];

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
    developer.log(
      'load: dependencies=${dependencies.length}, devDependencies=${devDependencies.length}',
      name: _logName,
    );

    final platforms = await _detectPlatforms(dir.path);
    final androidEnvFiles = await _detectEnvFilesForPlatform(dir.path, 'android');
    final iosEnvFiles = await _detectEnvFilesForPlatform(dir.path, 'ios');
    final androidFlavors = await _detectAndroidFlavors(dir.path);
    final iosFlavors = await _detectIosFlavors(dir.path);
    final envScripts = await _detectEnvScripts(dir.path);
    final firebaseEnvs = await _detectFirebaseEnvs(dir.path);
    final dartEnvSourceFiles = await _detectDartEnvSourceFiles(dir.path);
    final (launchJsonPath, launchConfigurations) = await _readLaunchJson(dir.path);
    final flutterVersion = await _getFlutterVersion(dir.path);
    final iosAppIcons = await _detectIosAppIcons(dir.path);
    final androidAppIcons = await _detectAndroidAppIcons(dir.path);
    final iosAppIconPath = iosAppIcons.isNotEmpty
        ? iosAppIcons.firstWhere((e) => e.isMain, orElse: () => iosAppIcons.first).path
        : null;
    final androidAppIconPath = androidAppIcons.isNotEmpty
        ? androidAppIcons.firstWhere((e) => e.isMain, orElse: () => androidAppIcons.first).path
        : null;
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
      launchJsonPath: launchJsonPath,
      launchConfigurations: launchConfigurations,
      iosAppIconPath: iosAppIconPath,
      androidAppIconPath: androidAppIconPath,
      iosAppIcons: iosAppIcons,
      androidAppIcons: androidAppIcons,
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
    // Try named configs in order: release, production (usati per build release/flavor)
    for (final name in ['release', 'production']) {
      final pattern = RegExp(
        r'(?:getByName|create)\s*\(\s*[\x22\x27]' + name + r'[\x22\x27]\s*\)\s*\{',
        caseSensitive: false,
      );
      final match = pattern.firstMatch(signingBlock);
      if (match != null) {
        final start = match.end - 1; // index of '{'
        final block = _extractBalancedBraces(signingBlock, start);
        if (block != null) {
          _extractKtsSigningEntry(block, out);
          if (out.isNotEmpty) return;
        }
      }
    }
    // Try any create("...") { ... } block (brace-balanced per blocchi annidati)
    final createRegex = RegExp(r'create\s*\(\s*[\x22\x27]\w+[\x22\x27]\s*\)\s*\{');
    for (final match in createRegex.allMatches(signingBlock)) {
      final block = _extractBalancedBraces(signingBlock, match.end - 1);
      if (block != null) {
        _extractKtsSigningEntry(block, out);
        if (out.isNotEmpty) return;
      }
    }
  }

  /// Restituisce il contenuto tra la parentesi graffa aperta in [content] a [openBraceIndex] e la sua '}' di chiusura.
  String? _extractBalancedBraces(String content, int openBraceIndex) {
    if (openBraceIndex >= content.length || content[openBraceIndex] != '{') return null;
    var depth = 1;
    var i = openBraceIndex + 1;
    while (i < content.length && depth > 0) {
      if (content[i] == '{') depth++;
      if (content[i] == '}') depth--;
      i++;
    }
    if (depth != 0) return null;
    return content.substring(openBraceIndex + 1, i - 1);
  }

  void _extractKtsSigningEntry(String block, Map<String, String> out) {
    final storeFileLiteral = RegExp(
      r'storeFile\s*=\s*file\s*\(\s*[\x22\x27]([^\x22\x27]+)[\x22\x27]\s*\)',
    ).firstMatch(block);
    if (storeFileLiteral != null) {
      out['storeFile'] = storeFileLiteral.group(1)!.trim();
    } else {
      final storeFileProperty = RegExp(
        r'storeFile\s*=\s*file\s*\((?:rootProject\.)?file\s*\(\s*[\x22\x27]([^\x22\x27]+)[\x22\x27]\s*\)',
      ).firstMatch(block);
      if (storeFileProperty != null) out['storeFile'] = storeFileProperty.group(1)!.trim();
      if (!out.containsKey('storeFile') && RegExp(r'storeFile\s*=').hasMatch(block)) {
        out['storeFile'] = '(da proprietà / variabile)';
      }
    }
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
    for (final name in ['release', 'production']) {
      final nameMatch = RegExp(RegExp.escape(name) + r'\s*\{').firstMatch(signingBlock);
      if (nameMatch != null) {
        final block = _extractBalancedBraces(signingBlock, nameMatch.end - 1);
        if (block != null && _extractGroovySigningEntry(block, out)) return;
      }
    }
    // Qualsiasi blocco nome { ... } che contenga storeFile
    final blockStartRegex = RegExp(r'\b(\w+)\s*\{');
    for (final match in blockStartRegex.allMatches(signingBlock)) {
      final block = _extractBalancedBraces(signingBlock, match.end - 1);
      if (block != null && block.contains('storeFile') && _extractGroovySigningEntry(block, out)) return;
    }
  }

  bool _extractGroovySigningEntry(String block, Map<String, String> out) {
    final storeFile = RegExp(r'storeFile\s+file\s*\(\s*[\x22\x27]([^\x22\x27]+)[\x22\x27]\s*\)').firstMatch(block);
    if (storeFile != null) out['storeFile'] = storeFile.group(1)!.trim();
    if (!out.containsKey('storeFile') && RegExp(r'storeFile\s+').hasMatch(block)) {
      out['storeFile'] = '(da proprietà / variabile)';
    }
    final storePassword = RegExp(r'storePassword\s+[\x22\x27]([^\x22\x27]*)[\x22\x27]').firstMatch(block);
    if (storePassword != null) out['storePassword'] = storePassword.group(1)!.trim();
    final keyAlias = RegExp(r'keyAlias\s+[\x22\x27]([^\x22\x27]+)[\x22\x27]').firstMatch(block);
    if (keyAlias != null) out['keyAlias'] = keyAlias.group(1)!.trim();
    final keyPassword = RegExp(r'keyPassword\s+[\x22\x27]([^\x22\x27]*)[\x22\x27]').firstMatch(block);
    if (keyPassword != null) out['keyPassword'] = keyPassword.group(1)!.trim();
    final storeType = RegExp(r'storeType\s+[\x22\x27]([^\x22\x27]+)[\x22\x27]').firstMatch(block);
    if (storeType != null) out['storeType'] = storeType.group(1)!.trim();
    return out.isNotEmpty;
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
                  developer.log(
                    '_readIosBuildSettings: letti ${current.length} da ${entity.uri.pathSegments.last}',
                    name: _logName,
                  );
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
        : [RegExp('$key\\s+["\']([^"\']+)["\']'), RegExp('$key\\s+(\\d+)'), RegExp('$key\\s+([A-Za-z0-9_.]+)')];
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
        final isLaunchSplash =
            name == 'LaunchImage.imageset' ||
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
    final drawableDirs = [
      'drawable',
      'drawable-mdpi',
      'drawable-hdpi',
      'drawable-xhdpi',
      'drawable-xxhdpi',
      'drawable-xxxhdpi',
    ];
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

  /// Legge dal project.pbxproj iOS il nome dell'icona principale (ASSETCATALOG_COMPILER_APPICON_NAME).
  Future<String?> _readIosMainAppIconName(String projectPath) async {
    final iosDir = Directory('$projectPath/ios');
    if (!await iosDir.exists()) return null;
    await for (final entity in iosDir.list(followLinks: false)) {
      if (entity is Directory && entity.path.endsWith('.xcodeproj')) {
        final pbxproj = File('${entity.path}/project.pbxproj');
        if (!await pbxproj.exists()) continue;
        try {
          final content = await pbxproj.readAsString();
          // ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon; oppure = "AppIcon";
          final re = RegExp('ASSETCATALOG_COMPILER_APPICON_NAME\\s*=\\s*["\']?([^"\';\\s]+)["\']?\\s*;');
          final match = re.firstMatch(content);
          if (match != null) {
            final name = match.group(1)!.trim();
            developer.log('_readIosMainAppIconName: da pbxproj → $name', name: _logName);
            return name;
          }
        } catch (e, st) {
          developer.log('_readIosMainAppIconName: errore', name: _logName, error: e, stackTrace: st);
        }
        break;
      }
    }
    return null;
  }

  /// Restituisce tutte le icone iOS (.appiconset) con path, etichetta e flag principale.
  /// La principale è quella indicata in project.pbxproj (ASSETCATALOG_COMPILER_APPICON_NAME).
  Future<List<AppIconEntry>> _detectIosAppIcons(String projectPath) async {
    final assetsDir = Directory('$projectPath/ios/Runner/Assets.xcassets');
    if (!await assetsDir.exists()) {
      developer.log('_detectIosAppIcons: Assets.xcassets non trovato', name: _logName);
      return [];
    }
    final appIconSetPaths = <String>[];
    await for (final entity in assetsDir.list(followLinks: false)) {
      if (entity is Directory) {
        final name = entity.uri.pathSegments.last;
        if (name.endsWith('.appiconset')) appIconSetPaths.add(entity.path);
      }
    }
    appIconSetPaths.sort((a, b) => a.split('/').last.compareTo(b.split('/').last));
    final mainNameFromManifest = await _readIosMainAppIconName(projectPath);
    final result = <AppIconEntry>[];
    for (final dirPath in appIconSetPaths) {
      final path = _resolveFirstImageFromAppIconSet(dirPath);
      if (path != null) {
        final setName = dirPath.split('/').last.replaceAll('.appiconset', '');
        final isMain = mainNameFromManifest != null && setName == mainNameFromManifest;
        result.add(AppIconEntry(path: path, label: setName, isMain: isMain));
        developer.log('_detectIosAppIcons: $setName → $path (main=$isMain)', name: _logName);
      }
    }
    if (result.isNotEmpty && result.every((e) => !e.isMain) && mainNameFromManifest == null) {
      result[0] = AppIconEntry(path: result[0].path, label: result[0].label, isMain: true);
    }
    if (result.isEmpty) developer.log('_detectIosAppIcons: nessuna icona trovata', name: _logName);
    return result;
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

  /// Voce launcher letta dal manifest (icon ref es. @mipmap/ic_launcher, isMain se è l'activity principale).
  static final _androidIconRefRegex = RegExp('android:icon\\s*=\\s*["\']([^"\']+)["\']');
  static final _androidEnabledRegex = RegExp('android:enabled\\s*=\\s*["\']([^"\']+)["\']');
  static final _androidLabelRegex = RegExp('android:label\\s*=\\s*["\']([^"\']+)["\']');

  /// Legge dal manifest Android i launcher (activity/activity-alias con MAIN+LAUNCHER) e le relative icone.
  /// isMain = true per la prima <activity> (non alias) con launcher, oppure per l'<activity-alias> con enabled=true.
  Future<List<_AndroidLauncherEntry>> _readAndroidLauncherIconsFromManifest(String projectPath) async {
    final manifestFile = File('$projectPath/android/app/src/main/AndroidManifest.xml');
    if (!await manifestFile.exists()) {
      developer.log('_readAndroidLauncherIconsFromManifest: manifest non trovato', name: _logName);
      return [];
    }
    String content;
    try {
      content = await manifestFile.readAsString();
    } catch (e, st) {
      developer.log('_readAndroidLauncherIconsFromManifest: errore lettura', name: _logName, error: e, stackTrace: st);
      return [];
    }
    String? appIconRef;
    final appIconMatch = _androidIconRefRegex.firstMatch(content);
    if (appIconMatch != null) appIconRef = appIconMatch.group(1);

    final launchers = <_AndroidLauncherRaw>[];
    final activityRegex = RegExp(r'<activity(?:\s[^>]*)?>', caseSensitive: false, dotAll: false);
    final aliasRegex = RegExp(r'<activity-alias(?:\s[^>]*)?>', caseSensitive: false);
    final intentFilterRegex = RegExp(
      r'<intent-filter\s*[^>]*>.*?MAIN.*?LAUNCHER.*?</intent-filter>',
      caseSensitive: false,
      dotAll: true,
    );

    for (final match in activityRegex.allMatches(content)) {
      final tag = match.group(0)!;
      final endTag = content.indexOf('</activity>', match.end);
      if (endTag == -1) continue;
      final block = content.substring(match.start, endTag + '</activity>'.length);
      if (!intentFilterRegex.hasMatch(block)) continue;
      final iconMatch = _androidIconRefRegex.firstMatch(tag);
      final labelMatch = _androidLabelRegex.firstMatch(tag);
      final iconRef = iconMatch != null ? iconMatch.group(1)! : (appIconRef ?? '@mipmap/ic_launcher');
      launchers.add(
        _AndroidLauncherRaw(iconRef: iconRef, label: labelMatch?.group(1), isActivity: true, enabled: true),
      );
    }
    for (final match in aliasRegex.allMatches(content)) {
      final tag = match.group(0)!;
      final endTag = content.indexOf('</activity-alias>', match.end);
      if (endTag == -1) continue;
      final block = content.substring(match.start, endTag + '</activity-alias>'.length);
      if (!intentFilterRegex.hasMatch(block)) continue;
      final iconMatch = _androidIconRefRegex.firstMatch(tag);
      final enabledMatch = _androidEnabledRegex.firstMatch(tag);
      final enabled = enabledMatch == null || enabledMatch.group(1)!.toLowerCase() != 'false';
      final iconRef = iconMatch != null ? iconMatch.group(1)! : (appIconRef ?? '@mipmap/ic_launcher');
      final labelMatch = _androidLabelRegex.firstMatch(tag);
      launchers.add(
        _AndroidLauncherRaw(iconRef: iconRef, label: labelMatch?.group(1), isActivity: false, enabled: enabled),
      );
    }

    final result = <_AndroidLauncherEntry>[];
    final hasActivityLauncher = launchers.any((e) => e.isActivity);
    var mainAssigned = false;
    for (final e in launchers) {
      final isMain = !mainAssigned && (hasActivityLauncher ? e.isActivity : e.enabled);
      if (isMain) mainAssigned = true;
      result.add(_AndroidLauncherEntry(iconRef: e.iconRef, label: e.label, isMain: isMain));
    }
    developer.log('_readAndroidLauncherIconsFromManifest: ${result.length} launcher', name: _logName);
    return result;
  }

  /// Risolve un riferimento @mipmap/name o @drawable/name al primo file esistente in res (priorità densità alte).
  String? _resolveAndroidIconRef(String projectPath, String iconRef) {
    if (!iconRef.startsWith('@')) return null;
    final parts = iconRef.substring(1).split('/');
    if (parts.length != 2) return null;
    final type = parts[0];
    final name = parts[1];
    final base = '$projectPath/android/app/src/main/res';
    if (type == 'mipmap') {
      const densities = ['mipmap-xxxhdpi', 'mipmap-xxhdpi', 'mipmap-xhdpi', 'mipmap-hdpi', 'mipmap-mdpi'];
      for (final d in densities) {
        final f = File('$base/$d/$name.png');
        if (f.existsSync()) return f.path;
      }
    }
    if (type == 'drawable') {
      const densities = [
        'drawable-xxxhdpi',
        'drawable-xxhdpi',
        'drawable-xhdpi',
        'drawable-hdpi',
        'drawable-mdpi',
        'drawable',
      ];
      for (final d in densities) {
        final f = File('$base/$d/$name.png');
        if (f.existsSync()) return f.path;
      }
    }
    return null;
  }

  /// Restituisce tutte le icone Android dichiarate nel manifest (launcher): una per activity/alias con MAIN+LAUNCHER.
  /// La principale è quella dell'activity launcher (non alias) o l'alias abilitato se sono solo alias.
  Future<List<AppIconEntry>> _detectAndroidAppIcons(String projectPath) async {
    final manifestLaunchers = await _readAndroidLauncherIconsFromManifest(projectPath);
    final resDir = Directory('$projectPath/android/app/src/main/res');
    if (!await resDir.exists()) {
      developer.log('_detectAndroidAppIcons: res/ non trovato', name: _logName);
      return [];
    }
    if (manifestLaunchers.isNotEmpty) {
      final result = <AppIconEntry>[];
      for (final entry in manifestLaunchers) {
        final path = _resolveAndroidIconRef(projectPath, entry.iconRef);
        if (path != null) {
          final label = entry.label ?? entry.iconRef.replaceFirst('@', '');
          result.add(AppIconEntry(path: path, label: label, isMain: entry.isMain));
          developer.log('_detectAndroidAppIcons: ${entry.iconRef} → $path (main=${entry.isMain})', name: _logName);
        }
      }
      if (result.isNotEmpty) return result;
    }
    // Fallback: nessun launcher nel manifest o icone non risolte, elenca mipmap/drawable
    final result = <AppIconEntry>[];
    const mipmapDensities = ['mipmap-xxxhdpi', 'mipmap-xxhdpi', 'mipmap-xhdpi', 'mipmap-hdpi', 'mipmap-mdpi'];
    for (var i = 0; i < mipmapDensities.length; i++) {
      final density = mipmapDensities[i];
      for (final name in ['ic_launcher.png', 'ic_launcher_round.png']) {
        final file = File('$projectPath/android/app/src/main/res/$density/$name');
        if (await file.exists()) {
          final label = '$density · ${name.replaceAll('.png', '')}';
          result.add(AppIconEntry(path: file.path, label: label, isMain: result.isEmpty));
        }
      }
    }
    final drawableFile = File('$projectPath/android/app/src/main/res/drawable/ic_launcher.png');
    if (await drawableFile.exists()) {
      result.add(AppIconEntry(path: drawableFile.path, label: 'drawable · ic_launcher', isMain: result.isEmpty));
    }
    if (result.isEmpty) developer.log('_detectAndroidAppIcons: nessuna icona trovata', name: _logName);
    return result;
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
      final result = await Process.run(executable, ['--version'], workingDirectory: workingDirectory, runInShell: true);
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
    developer.log(
      '_detectEnvScripts: ${result.length} script → ${result.map((e) => e.scriptFile).toList()}',
      name: _logName,
    );
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

  /// Legge .vscode/launch.json e restituisce percorso e lista configurazioni (nome + eventuale flavor).
  Future<(String?, List<LaunchConfigEntry>)> _readLaunchJson(String projectPath) async {
    const relativePath = '.vscode/launch.json';
    final file = File('$projectPath/$relativePath');
    if (!await file.exists()) {
      developer.log('_readLaunchJson: file non presente', name: _logName);
      return (null, <LaunchConfigEntry>[]);
    }
    developer.log('_readLaunchJson: file trovato ${file.path}', name: _logName);
    final configs = <LaunchConfigEntry>[];
    try {
      String content = await file.readAsString();
      content = _stripJsonComments(content);
      final decoded = jsonDecode(content) as Map<String, dynamic>?;
      if (decoded == null) {
        developer.log('_readLaunchJson: decoded null', name: _logName);
        return (relativePath, configs);
      }
      final list = decoded['configurations'];
      developer.log('_readLaunchJson: configurations type=${list.runtimeType}, isList=${list is List}, length=${list is List ? list.length : "n/a"}', name: _logName);
      if (list is List) {
        for (var i = 0; i < list.length; i++) {
          final item = list[i];
          if (item is! Map) {
            developer.log('_readLaunchJson: [$i] skip (non Map, type=${item.runtimeType})', name: _logName);
            continue;
          }
          final map = Map<String, dynamic>.from(item);
          if (map['request'] != 'launch' || map['type'] != 'dart') {
            developer.log('_readLaunchJson: [$i] skip (request=${map['request']}, type=${map['type']})', name: _logName);
            continue;
          }
          final name = map['name']?.toString().trim();
          if (name == null || name.isEmpty) {
            developer.log('_readLaunchJson: [$i] skip (name vuoto o null)', name: _logName);
            continue;
          }
          String? flavor;
          final args = map['args'];
          if (args is List) {
            for (var j = 0; j < args.length - 1; j++) {
              if (args[j] == '--flavor' && args[j + 1] != null) {
                flavor = args[j + 1].toString().trim();
                break;
              }
            }
          }
          configs.add(LaunchConfigEntry(name: name, flavor: flavor?.isEmpty == true ? null : flavor));
          developer.log('_readLaunchJson: [$i] aggiunta "$name"${flavor != null && flavor.isNotEmpty ? " flavor=$flavor" : ""}', name: _logName);
        }
      }
    } catch (e, st) {
      developer.log('_readLaunchJson: parse error $e', name: _logName);
      developer.log('_readLaunchJson: $st', name: _logName);
    }
    developer.log('_readLaunchJson: totale ${configs.length} configurazioni', name: _logName);
    return (relativePath, configs);
  }

  /// Rimuove commenti // e /* */ (anche multiriga) e virgole finali, per parsare launch.json con commenti.
  static String _stripJsonComments(String text) {
    final buffer = StringBuffer();
    var i = 0;
    final len = text.length;
    var inDouble = false;
    var inSingle = false;
    while (i < len) {
      final c = text[i];
      if (inDouble || inSingle) {
        if (c == r'\' && i + 1 < len) {
          buffer.write(c);
          buffer.write(text[i + 1]);
          i += 2;
          continue;
        }
        if ((inDouble && c == '"') || (inSingle && c == "'")) {
          inDouble = false;
          inSingle = false;
        }
        buffer.write(c);
        i++;
        continue;
      }
      if (c == '"') {
        inDouble = true;
        buffer.write(c);
        i++;
        continue;
      }
      if (c == "'") {
        inSingle = true;
        buffer.write(c);
        i++;
        continue;
      }
      if (i < len - 1 && c == '/' && text[i + 1] == '/') {
        i += 2;
        while (i < len && text[i] != '\n') i++;
        if (i < len) buffer.write('\n');
        i++;
        continue;
      }
      if (i < len - 1 && c == '/' && text[i + 1] == '*') {
        i += 2;
        while (i < len - 1 && (text[i] != '*' || text[i + 1] != '/')) i++;
        i += 2;
        continue;
      }
      buffer.write(c);
      i++;
    }
    return _stripTrailingCommas(buffer.toString());
  }

  /// Rimuove virgole prima di ] o } (JSON standard non le ammette, ma launch.json spesso le ha).
  static String _stripTrailingCommas(String text) {
    return text.replaceAllMapped(
      RegExp(r',(\s*[}\]])'),
      (m) => m.group(1)!,
    );
  }
}
