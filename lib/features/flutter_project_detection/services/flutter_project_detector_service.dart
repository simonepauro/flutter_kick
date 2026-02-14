import 'dart:io';

import 'package:yaml/yaml.dart';

import '../models/flutter_project_result.dart';

/// Servizio che legge una cartella e determina se è un progetto Flutter.
class FlutterProjectDetectorService {
  FlutterProjectDetectorService();

  /// Verifica se [path] è la root di un progetto Flutter.
  /// Controlla la presenza di pubspec.yaml e la dipendenza da Flutter SDK.
  Future<FlutterProjectResult> detect(String path) async {
    final trimmed = path.trim();
    if (trimmed.isEmpty) {
      return FlutterProjectResult(path: trimmed, isFlutterProject: false, errorMessageKey: 'errors.emptyPath');
    }

    final dir = Directory(trimmed);
    if (!await dir.exists()) {
      return FlutterProjectResult(path: trimmed, isFlutterProject: false, errorMessageKey: 'errors.folderNotFound');
    }

    final pubspecFile = File('${dir.path}/pubspec.yaml');
    if (!await pubspecFile.exists()) {
      return FlutterProjectResult(path: trimmed, isFlutterProject: false, errorMessageKey: 'errors.noPubspec');
    }

    try {
      final content = await pubspecFile.readAsString();
      final isFlutter = _hasFlutterDependency(content);
      return FlutterProjectResult(
        path: trimmed,
        isFlutterProject: isFlutter,
        errorMessageKey: isFlutter ? null : 'errors.noFlutterDependency',
      );
    } catch (e) {
      return FlutterProjectResult(
        path: trimmed,
        isFlutterProject: false,
        errorMessageKey: 'errors.readError',
        errorMessageParams: {'message': e.toString()},
      );
    }
  }

  /// Verifica nel contenuto di pubspec.yaml se c'è la dipendenza da Flutter SDK.
  bool _hasFlutterDependency(String pubspecContent) {
    try {
      final doc = loadYaml(pubspecContent);
      if (doc == null || doc is! YamlMap) return false;

      final dependencies = doc['dependencies'];
      if (dependencies == null || dependencies is! YamlMap) return false;

      final flutter = dependencies['flutter'];
      if (flutter == null) return false;

      // flutter: sdk: flutter
      if (flutter is YamlMap) {
        return flutter['sdk'] == 'flutter';
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
