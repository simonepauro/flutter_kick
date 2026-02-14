import 'dart:io';

import 'package:yaml/yaml.dart';

import '../models/dependency_info.dart';
import '../models/flutter_project_info.dart';

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
    final dir = Directory(projectPath);
    if (!await dir.exists()) {
      throw Exception('Cartella non trovata: $projectPath');
    }

    final pubspecFile = File('${dir.path}/pubspec.yaml');
    if (!await pubspecFile.exists()) {
      throw Exception('pubspec.yaml non trovato');
    }

    final content = await pubspecFile.readAsString();
    final doc = loadYaml(content);
    if (doc == null || doc is! YamlMap) {
      throw Exception('pubspec.yaml non valido');
    }

    final name = _string(doc['name']) ?? 'unknown';
    final description = _string(doc['description']);
    final version = _string(doc['version']);
    final publishTo = _string(doc['publish_to']);

    String? sdkConstraint;
    final env = doc['environment'];
    if (env is YamlMap) {
      sdkConstraint = _string(env['sdk']);
    }

    final dependencies = _dependencyEntries(doc['dependencies']);
    final devDependencies = _dependencyEntries(doc['dev_dependencies']);
    final platforms = await _detectPlatforms(dir.path);
    final androidEnvFiles = await _detectEnvFilesForPlatform(dir.path, 'android');
    final iosEnvFiles = await _detectEnvFilesForPlatform(dir.path, 'ios');
    final androidFlavors = await _detectAndroidFlavors(dir.path);
    final iosFlavors = await _detectIosFlavors(dir.path);
    final envScripts = await _detectEnvScripts(dir.path);
    final firebaseEnvs = await _detectFirebaseEnvs(dir.path);
    final dartEnvSourceFiles = await _detectDartEnvSourceFiles(dir.path);

    return FlutterProjectInfo(
      projectPath: projectPath,
      name: name,
      description: description,
      version: version,
      publishTo: publishTo,
      sdkConstraint: sdkConstraint,
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
    );
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
    return list;
  }

  /// Rileva i flavor Android (productFlavors in build.gradle).
  Future<List<String>> _detectAndroidFlavors(String projectPath) async {
    for (final filename in ['build.gradle', 'build.gradle.kts']) {
      final file = File('$projectPath/android/app/$filename');
      if (await file.exists()) {
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
                return names.toList()..sort();
              }
            }
          }
        }
        break;
      }
    }
    return [];
  }

  /// Rileva gli scheme iOS (xcshareddata/xcschemes).
  Future<List<String>> _detectIosFlavors(String projectPath) async {
    final names = <String>[];
    final iosDir = Directory('$projectPath/ios');
    if (!await iosDir.exists()) return names;
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
    return result;
  }

  /// Rileva le cartelle env sotto firebase/ con config (google-services.json o GoogleService-Info.plist).
  Future<List<String>> _detectFirebaseEnvs(String projectPath) async {
    final result = <String>[];
    final firebaseDir = Directory('$projectPath/firebase');
    if (!await firebaseDir.exists()) return result;
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
    return result;
  }

  /// Rileva i file Dart *_env_*.txt in lib/ (sorgenti env copiate dallo script in *_env.dart).
  Future<List<String>> _detectDartEnvSourceFiles(String projectPath) async {
    final result = <String>[];
    final libDir = Directory('$projectPath/lib');
    if (!await libDir.exists()) return result;
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
    return result;
  }
}
