import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/dependency_info.dart';

/// Servizio che verifica in background aggiornamenti e deprecazioni delle dipendenze.
class DependencyStatusService {
  DependencyStatusService();

  /// Esegue `dart pub outdated --json` nella cartella del progetto e verifica
  /// su pub.dev se i pacchetti sono deprecati (per [directPackageNames] se fornito).
  Future<DependencyStatusInfo> check(
    String projectPath, {
    List<String>? directPackageNames,
  }) async {
    final outdated = await _runPubOutdated(projectPath);
    final namesToCheck = directPackageNames ?? outdated.keys.toList();
    final deprecated = await _fetchDeprecated(namesToCheck);
    return DependencyStatusInfo(outdated: outdated, deprecated: deprecated);
  }

  Future<Map<String, OutdatedPackageInfo>> _runPubOutdated(String projectPath) async {
    final dartResult = await _runPubOutdatedWithExecutable(projectPath, 'dart', 60);
    if (dartResult.isNotEmpty) return dartResult;
    return _runPubOutdatedWithExecutable(projectPath, 'flutter', 90);
  }

  Future<Map<String, OutdatedPackageInfo>> _runPubOutdatedWithExecutable(
    String projectPath,
    String executable,
    int timeoutSeconds,
  ) async {
    try {
      final processResult = await Process.run(
        executable,
        ['pub', 'outdated', '--json'],
        workingDirectory: projectPath,
        runInShell: true,
      ).timeout(Duration(seconds: timeoutSeconds));
      if (processResult.exitCode != 0) return {};
      return _parsePubOutdatedJson(processResult.stdout as String? ?? '');
    } catch (_) {
      return {};
    }
  }

  Map<String, OutdatedPackageInfo> _parsePubOutdatedJson(String stdout) {
    final result = <String, OutdatedPackageInfo>{};
    final json = jsonDecode(stdout) as Map<String, dynamic>?;
    if (json == null) return result;
    final packages = json['packages'] as List<dynamic>?;
    if (packages == null) return result;
    for (final p in packages) {
      if (p is! Map<String, dynamic>) continue;
      final name = p['package'] as String?;
      if (name == null) continue;
      result[name] = OutdatedPackageInfo(
        package: name,
        current: _versionFrom(p['current']),
        upgradable: _versionFrom(p['upgradable']),
        resolvable: _versionFrom(p['resolvable']),
        latest: _versionFrom(p['latest']),
      );
    }
    return result;
  }

  String? _versionFrom(dynamic v) {
    if (v == null) return null;
    if (v is String) return v;
    if (v is Map<String, dynamic>) return v['version'] as String?;
    return null;
  }

  Future<Set<String>> _fetchDeprecated(List<String> packageNames) async {
    final deprecated = <String>{};
    for (final name in packageNames) {
      try {
        final uri = Uri.parse('https://pub.dev/api/packages/$name');
        final response = await http.get(uri).timeout(
          const Duration(seconds: 5),
        );
        if (response.statusCode != 200) continue;
        final json = jsonDecode(response.body) as Map<String, dynamic>?;
        if (json == null) continue;
        final discontinued = json['isDiscontinued'] as bool? ?? false;
        if (discontinued) deprecated.add(name);
      } catch (_) {
        // Ignora errori di rete per singolo pacchetto
      }
    }
    return deprecated;
  }
}
