import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/dependency_info.dart';

const _logName = 'DependencyStatusService';

/// Servizio che verifica in background aggiornamenti e deprecazioni delle dipendenze.
class DependencyStatusService {
  DependencyStatusService();

  /// Esegue `flutter pub outdated --json` (o `dart pub outdated --json`) nella cartella del progetto
  /// e verifica su pub.dev se i pacchetti sono deprecati (per [directPackageNames] se fornito).
  /// Quando [directPackageNames] è fornito, outdated e deprecated vengono verificati in parallelo.
  Future<DependencyStatusInfo> check(String projectPath, {List<String>? directPackageNames}) async {
    developer.log('check: avvio per projectPath=$projectPath', name: _logName);
    if (directPackageNames != null && directPackageNames.isNotEmpty) {
      final results = await Future.wait([_runPubOutdated(projectPath), _fetchDeprecated(directPackageNames)]);
      final outdated = results[0] as Map<String, OutdatedPackageInfo>;
      final deprecated = results[1] as Set<String>;
      developer.log(
        'check: completato (parallelo) → outdated=${outdated.length}, deprecated=${deprecated.length}',
        name: _logName,
      );
      return DependencyStatusInfo(outdated: outdated, deprecated: deprecated);
    }
    final outdated = await _runPubOutdated(projectPath);
    final namesToCheck = outdated.keys.toList();
    developer.log(
      'check: outdated=${outdated.length} pacchetti, verifico deprecati per ${namesToCheck.length} nomi',
      name: _logName,
    );
    final deprecated = await _fetchDeprecated(namesToCheck);
    developer.log('check: completato → outdated=${outdated.length}, deprecated=${deprecated.length}', name: _logName);
    return DependencyStatusInfo(outdated: outdated, deprecated: deprecated);
  }

  /// Risolve l'eseguibile Flutter come in ProjectInfoService: FVM (.fvm/flutter_sdk/bin/flutter) poi PATH.
  Future<String?> _resolveFlutterExecutable(String projectPath) async {
    final fvmFlutter = Platform.isWindows
        ? File('$projectPath/.fvm/flutter_sdk/bin/flutter.bat')
        : File('$projectPath/.fvm/flutter_sdk/bin/flutter');
    if (await fvmFlutter.exists()) {
      developer.log('_resolveFlutterExecutable: uso FVM → ${fvmFlutter.path}', name: _logName);
      return fvmFlutter.path;
    }
    developer.log('_resolveFlutterExecutable: FVM non trovato, uso "flutter" da PATH', name: _logName);
    return 'flutter';
  }

  Future<Map<String, OutdatedPackageInfo>> _runPubOutdated(String projectPath) async {
    final executable = await _resolveFlutterExecutable(projectPath) ?? 'flutter';
    developer.log(
      '_runPubOutdated: eseguo "$executable pub outdated --json" in workingDirectory=$projectPath',
      name: _logName,
    );
    final result = await _runPubOutdatedWithExecutable(projectPath, executable, 90);
    if (result.isNotEmpty) return result;
    if (executable != 'flutter') return result;
    developer.log('_runPubOutdated: nessun risultato con flutter, provo "dart pub outdated --json"', name: _logName);
    return _runPubOutdatedWithExecutable(projectPath, 'dart', 60);
  }

  Future<Map<String, OutdatedPackageInfo>> _runPubOutdatedWithExecutable(
    String projectPath,
    String executable,
    int timeoutSeconds,
  ) async {
    const args = ['pub', 'outdated', '--json'];
    developer.log('_runPubOutdated: comando → $executable ${args.join(" ")}', name: _logName);
    developer.log('_runPubOutdated: workingDirectory=$projectPath, timeout=${timeoutSeconds}s', name: _logName);
    try {
      final processResult = await Process.run(
        executable,
        args,
        workingDirectory: projectPath,
        runInShell: true,
      ).timeout(Duration(seconds: timeoutSeconds));
      final stdout = processResult.stdout as String? ?? '';
      final stderr = processResult.stderr as String? ?? '';
      final exitCode = processResult.exitCode;
      final parsed = _parsePubOutdatedJson(stdout);

      if (exitCode == 0) {
        developer.log(
          '_runPubOutdated: SUCCESS exitCode=$exitCode, stdout.length=${stdout.length}, pacchetti parsati=${parsed.length}',
          name: _logName,
        );
        if (stderr.isNotEmpty) {
          developer.log('_runPubOutdated: stderr (exit 0): ${_truncate(stderr, 500)}', name: _logName);
        }
      } else {
        developer.log(
          '_runPubOutdated: FALLITO exitCode=$exitCode, stdout.length=${stdout.length}, stderr.length=${stderr.length}',
          name: _logName,
        );
        if (stdout.trim().isNotEmpty) {
          developer.log('_runPubOutdated: stdout: ${_truncate(stdout, 800)}', name: _logName);
        }
        if (stderr.trim().isNotEmpty) {
          developer.log('_runPubOutdated: stderr: ${_truncate(stderr, 800)}', name: _logName);
        }
      }

      if (exitCode != 0 && parsed.isEmpty) {
        return {};
      }
      return parsed;
    } on TimeoutException catch (e) {
      developer.log('_runPubOutdated: TIMEOUT dopo ${timeoutSeconds}s → $e', name: _logName);
      return {};
    } catch (e, st) {
      developer.log('_runPubOutdated: ECCEZIONE → $e', name: _logName, error: e, stackTrace: st);
      return {};
    }
  }

  static String _truncate(String s, int maxLen) {
    if (s.length <= maxLen) return s;
    return '${s.substring(0, maxLen)}... (${s.length} caratteri totali)';
  }

  Map<String, OutdatedPackageInfo> _parsePubOutdatedJson(String stdout) {
    final result = <String, OutdatedPackageInfo>{};
    if (stdout.trim().isEmpty) return result;
    try {
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
    } catch (_) {
      return {};
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
    if (packageNames.isEmpty) {
      developer.log('_fetchDeprecated: nessun pacchetto da verificare', name: _logName);
      return {};
    }
    developer.log(
      '_fetchDeprecated: verifico ${packageNames.length} pacchetti su pub.dev in parallelo',
      name: _logName,
    );
    final results = await Future.wait(packageNames.map((name) => _fetchDeprecatedSingle(name)));
    final deprecated = results.whereType<String>().toSet();
    developer.log('_fetchDeprecated: completato → ${deprecated.length} deprecati', name: _logName);
    return deprecated;
  }

  /// Verifica su pub.dev se il pacchetto è deprecato. Ritorna il [name] se deprecato, altrimenti null.
  Future<String?> _fetchDeprecatedSingle(String name) async {
    try {
      final uri = Uri.parse('https://pub.dev/api/packages/$name');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        developer.log('_fetchDeprecated: $name → HTTP ${response.statusCode}', name: _logName);
        return null;
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>?;
      if (json == null) return null;
      final discontinued = json['isDiscontinued'] as bool? ?? false;
      if (discontinued) {
        developer.log('_fetchDeprecated: $name → DEPRECATO (isDiscontinued=true)', name: _logName);
        return name;
      }
      return null;
    } catch (e) {
      developer.log('_fetchDeprecated: $name → errore: $e', name: _logName);
      return null;
    }
  }
}
