/// Credenziali per l'account Apple Developer (usate da Fastlane match/sigh).
class AppleDeveloperCredentials {
  const AppleDeveloperCredentials({
    this.appleId,
    required this.teamId,
    this.matchGitUrl,
    this.useApiKey = false,
    this.keyId,
    this.issuerId,
    this.p8Path,
  });

  /// Apple ID (email). Usato con password da keychain o prompt quando si esegue match.
  final String? appleId;

  /// Team ID Apple Developer (es. "ABCD1234").
  final String teamId;

  /// URL del repository Git usato da `fastlane match` per i certificati.
  final String? matchGitUrl;

  /// Se true, usa App Store Connect API Key (.p8) invece di Apple ID.
  final bool useApiKey;

  /// Key ID dell'API Key (App Store Connect).
  final String? keyId;

  /// Issuer ID (App Store Connect).
  final String? issuerId;

  /// Percorso del file .p8 (App Store Connect API Key).
  final String? p8Path;

  bool get isConnected =>
      teamId.trim().isNotEmpty &&
      (useApiKey ? (_hasApiKeyFields) : (appleId != null && appleId!.trim().isNotEmpty));

  bool get _hasApiKeyFields =>
      keyId != null &&
      keyId!.trim().isNotEmpty &&
      issuerId != null &&
      issuerId!.trim().isNotEmpty &&
      p8Path != null &&
      p8Path!.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'appleId': appleId,
        'teamId': teamId,
        'matchGitUrl': matchGitUrl,
        'useApiKey': useApiKey,
        'keyId': keyId,
        'issuerId': issuerId,
        'p8Path': p8Path,
      };

  static AppleDeveloperCredentials? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final teamId = json['teamId'] as String?;
    if (teamId == null || teamId.trim().isEmpty) return null;
    return AppleDeveloperCredentials(
      appleId: json['appleId'] as String?,
      teamId: teamId,
      matchGitUrl: json['matchGitUrl'] as String?,
      useApiKey: json['useApiKey'] as bool? ?? false,
      keyId: json['keyId'] as String?,
      issuerId: json['issuerId'] as String?,
      p8Path: json['p8Path'] as String?,
    );
  }

  AppleDeveloperCredentials copyWith({
    String? appleId,
    String? teamId,
    String? matchGitUrl,
    bool? useApiKey,
    String? keyId,
    String? issuerId,
    String? p8Path,
  }) {
    return AppleDeveloperCredentials(
      appleId: appleId ?? this.appleId,
      teamId: teamId ?? this.teamId,
      matchGitUrl: matchGitUrl ?? this.matchGitUrl,
      useApiKey: useApiKey ?? this.useApiKey,
      keyId: keyId ?? this.keyId,
      issuerId: issuerId ?? this.issuerId,
      p8Path: p8Path ?? this.p8Path,
    );
  }
}
