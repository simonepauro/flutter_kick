import 'dart:convert';
import 'dart:io';

import 'package:flutter_kick/features/apple_developer/models/apple_developer_credentials.dart';

/// Tipo di certificato per `fastlane match`.
enum MatchType { development, adhoc, appstore, enterprise }

extension MatchTypeExt on MatchType {
  String get cliValue {
    switch (this) {
      case MatchType.development:
        return 'development';
      case MatchType.adhoc:
        return 'adhoc';
      case MatchType.appstore:
        return 'appstore';
      case MatchType.enterprise:
        return 'enterprise';
    }
  }
}

/// Risultato dell'esecuzione di fastlane match.
class FastlaneMatchResult {
  const FastlaneMatchResult({required this.exitCode, required this.output});

  final int exitCode;
  final String output;
}

/// Servizio per eseguire Fastlane match nel progetto iOS (gestione certificati).
class FastlaneMatchService {
  /// Callback opzionale quando Fastlane chiede input (es. codice 2FA a 6 cifre).
  /// Ritorna il valore da inviare allo stdin del processo.
  static bool _isPromptForCode(String line) {
    final lower = line.toLowerCase();
    return lower.contains('6 digit code') || lower.contains('digit code:') || lower.contains('enter the 6 digit');
  }

  /// Esegue `fastlane match [type]` nella cartella ios del progetto.
  /// [projectPath] = root del progetto Flutter (es. /path/to/my_app).
  /// [credentials] = credenziali Apple Developer collegate.
  /// [onOutput] = callback per ogni linea di output (stdout + stderr).
  /// [onNeedsInput] = se Fastlane chiede un input (es. codice 2FA), viene chiamato e il valore restituito viene inviato allo stdin.
  /// Ritorna il codice di uscita del processo.
  Future<FastlaneMatchResult> runMatch({
    required String projectPath,
    required AppleDeveloperCredentials credentials,
    required MatchType type,
    String? matchPassword,
    String? appIdentifier,
    void Function(String)? onOutput,
    Future<String?> Function(String prompt)? onNeedsInput,
  }) async {
    final iosDir = _iosPath(projectPath);
    if (!await Directory(iosDir).exists()) {
      return FastlaneMatchResult(exitCode: -1, output: 'Cartella ios non trovata: $iosDir');
    }

    final env = <String, String>{...Platform.environment, 'FASTLANE_TEAM_ID': credentials.teamId};
    if (matchPassword != null && matchPassword.isNotEmpty) {
      env['MATCH_PASSWORD'] = matchPassword;
    }

    if (credentials.useApiKey &&
        credentials.keyId != null &&
        credentials.issuerId != null &&
        credentials.p8Path != null) {
      env['APP_STORE_CONNECT_API_KEY_KEY_ID'] = credentials.keyId!;
      env['APP_STORE_CONNECT_API_KEY_ISSUER_ID'] = credentials.issuerId!;
      env['APP_STORE_CONNECT_API_KEY_KEY_FILEPATH'] = credentials.p8Path!;
      env['APP_STORE_CONNECT_API_KEY_IS_KEY_CONTENT'] = 'false';
    } else if (credentials.appleId != null && credentials.appleId!.trim().isNotEmpty) {
      env['FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD'] = ''; // Fastlane chiederà o userà keychain
      env['FASTLANE_USER'] = credentials.appleId!;
    }

    final args = <String>['match', type.cliValue];
    if (credentials.matchGitUrl != null && credentials.matchGitUrl!.trim().isNotEmpty) {
      args.addAll(['--git_url', credentials.matchGitUrl!.trim()]);
    }
    final bundleId = _stripQuotes(appIdentifier?.trim());
    if (bundleId != null && bundleId.isNotEmpty && !bundleId.contains(r'$(')) {
      args.addAll(['--app_identifier', bundleId]);
    }

    final buffer = StringBuffer();
    void append(String line) {
      buffer.writeln(line);
      onOutput?.call(line);
    }

    try {
      Process process;
      if (Platform.isMacOS || Platform.isLinux) {
        // fastlane può essere in rbenv/shims; workingDirectory imposta già la cwd nella cartella ios
        const fastlaneCmd = 'fastlane';
        final cmd = '$fastlaneCmd ${args.map((a) => a.contains(' ') ? "'$a'" : a).join(' ')}';
        process = await Process.start(
          '/bin/zsh',
          ['-l', '-c', cmd],
          environment: env,
          workingDirectory: iosDir,
          runInShell: false,
        );
      } else {
        process = await Process.start('fastlane', args, environment: env, workingDirectory: iosDir, runInShell: true);
      }

      void onLine(String line) {
        append(line);
        if (onNeedsInput != null && FastlaneMatchService._isPromptForCode(line)) {
          onNeedsInput(line).then((value) {
            if (value != null && value.trim().isNotEmpty) {
              process.stdin.writeln(value.trim());
              process.stdin.flush();
            }
          });
        }
      }

      process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(onLine);
      process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(onLine);

      final exitCode = await process.exitCode;
      return FastlaneMatchResult(exitCode: exitCode, output: buffer.toString());
    } catch (e) {
      append('Errore: $e');
      return FastlaneMatchResult(exitCode: -1, output: buffer.toString());
    }
  }

  /// Esegue `fastlane match init` nella cartella ios del progetto.
  /// Crea il Matchfile e prepara il repository Git per i certificati.
  /// [gitUrl] opzionale: URL del repository Git (se già creato). Se null, match chiederà a terminale.
  /// [matchPassword] opzionale: password per cifrare i certificati nel repo (MATCH_PASSWORD).
  /// [onNeedsInput] = se Fastlane chiede un input (es. codice 2FA), viene chiamato e il valore viene inviato allo stdin.
  Future<FastlaneMatchResult> runMatchInit({
    required String projectPath,
    String? gitUrl,
    String? matchPassword,
    void Function(String)? onOutput,
    Future<String?> Function(String prompt)? onNeedsInput,
  }) async {
    final iosDir = _iosPath(projectPath);
    if (!await Directory(iosDir).exists()) {
      return FastlaneMatchResult(exitCode: -1, output: 'Cartella ios non trovata: $iosDir');
    }

    final env = <String, String>{...Platform.environment};
    if (matchPassword != null && matchPassword.isNotEmpty) {
      env['MATCH_PASSWORD'] = matchPassword;
    }

    final args = <String>['match', 'init'];
    if (gitUrl != null && gitUrl.trim().isNotEmpty) {
      args.addAll(['--git_url', gitUrl.trim()]);
    }

    final buffer = StringBuffer();
    void append(String line) {
      buffer.writeln(line);
      onOutput?.call(line);
    }

    try {
      Process process;
      if (Platform.isMacOS || Platform.isLinux) {
        const fastlaneCmd = 'fastlane';
        final cmd = '$fastlaneCmd ${args.map((a) => a.contains(' ') ? "'$a'" : a).join(' ')}';
        process = await Process.start(
          '/bin/zsh',
          ['-l', '-c', cmd],
          environment: env,
          workingDirectory: iosDir,
          runInShell: false,
        );
      } else {
        process = await Process.start('fastlane', args, environment: env, workingDirectory: iosDir, runInShell: true);
      }

      void onLine(String line) {
        append(line);
        if (onNeedsInput != null && FastlaneMatchService._isPromptForCode(line)) {
          onNeedsInput(line).then((value) {
            if (value != null && value.trim().isNotEmpty) {
              process.stdin.writeln(value.trim());
              process.stdin.flush();
            }
          });
        }
      }

      process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(onLine);
      process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(onLine);

      final exitCode = await process.exitCode;
      return FastlaneMatchResult(exitCode: exitCode, output: buffer.toString());
    } catch (e) {
      append('Errore: $e');
      return FastlaneMatchResult(exitCode: -1, output: buffer.toString());
    }
  }

  static String _iosPath(String projectPath) {
    final normalized = projectPath.replaceAll(RegExp(r'/+'), '/').replaceFirst(RegExp(r'/$'), '');
    return '$normalized/ios';
  }

  static String? _stripQuotes(String? value) {
    if (value == null || value.isEmpty) return value;
    final t = value.trim();
    if (t.length >= 2 && ((t.startsWith('"') && t.endsWith('"')) || (t.startsWith("'") && t.endsWith("'")))) {
      return t.substring(1, t.length - 1);
    }
    return t;
  }
}
