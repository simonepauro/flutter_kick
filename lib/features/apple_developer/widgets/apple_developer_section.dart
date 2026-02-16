import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_kick/core/l10n/translation.dart';
import 'package:flutter_kick/core/widgets/fk_expandable_section.dart';
import 'package:flutter_kick/features/apple_developer/models/apple_developer_credentials.dart';
import 'package:flutter_kick/features/apple_developer/providers/apple_developer_provider.dart';
import 'package:flutter_kick/features/apple_developer/services/fastlane_match_service.dart';

/// Sezione "Account Apple Developer" nella tab Signing: stato connessione e azioni Match.
class AppleDeveloperSection extends ConsumerWidget {
  const AppleDeveloperSection({
    super.key,
    required this.projectPath,
    this.sectionKey,
    this.highlightSection = false,
    this.projectTeamId,
    this.projectAppIdentifier,
  });

  final String projectPath;
  final GlobalKey? sectionKey;
  final bool highlightSection;

  /// Team ID letto dal progetto (es. DEVELOPMENT_TEAM da Xcode). Usato per precompilare il dialog "Collega account".
  final String? projectTeamId;

  /// Bundle ID iOS (PRODUCT_BUNDLE_IDENTIFIER). Passato a Fastlane match come --app_identifier.
  final String? projectAppIdentifier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credsAsync = ref.watch(appleDeveloperCredentialsProvider);
    final theme = Theme.of(context);

    Widget content = credsAsync.when(
      data: (creds) {
        final connected = creds?.isConnected ?? false;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  connected ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.person_crop_circle_badge_exclam,
                  size: 20,
                  color: connected ? Colors.green : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  connected ? t(context, 'appleDeveloper.connected') : t(context, 'appleDeveloper.notConnected'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: connected ? Colors.green.shade700 : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                if (connected && creds != null) ...[
                  Text(
                    'Team: ${creds.teamId}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            if (connected && creds != null)
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () => _showMatchDialog(context, ref, projectPath, creds, projectAppIdentifier: projectAppIdentifier),
                    icon: const Icon(CupertinoIcons.arrow_2_circlepath, size: 18),
                    label: Text(t(context, 'appleDeveloper.syncCertificates')),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showMatchInitDialog(context, projectPath, creds.matchGitUrl),
                    icon: const Icon(CupertinoIcons.plus_circle, size: 18),
                    label: Text(t(context, 'appleDeveloper.initMatch')),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () async {
                      await ref.read(appleDeveloperCredentialsProvider.notifier).clear();
                    },
                    child: Text(t(context, 'appleDeveloper.disconnect')),
                  ),
                ],
              )
            else
              FilledButton.icon(
                onPressed: () => _showConnectDialog(context, ref, projectTeamId: projectTeamId),
                icon: const Icon(CupertinoIcons.person_add, size: 18),
                label: Text(t(context, 'appleDeveloper.connect')),
              ),
            if (connected) ...[
              const SizedBox(height: 8),
              Text(
                t(context, 'appleDeveloper.syncCertificatesHint'),
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Errore: $e', style: TextStyle(color: theme.colorScheme.error)),
      ),
    );

    Widget section = FkExpandableSection(
      title: t(context, 'appleDeveloper.sectionTitle'),
      child: content,
    );

    if (highlightSection) {
      section = Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.primary, width: 2),
        ),
        child: section,
      );
    }
    if (sectionKey != null) {
      section = KeyedSubtree(key: sectionKey, child: section);
    }
    return section;
  }

  static void _showConnectDialog(BuildContext context, WidgetRef ref, {String? projectTeamId}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _ConnectAppleDeveloperDialog(ref: ref, projectTeamId: projectTeamId),
    );
  }

  static void _showMatchDialog(
    BuildContext context,
    WidgetRef ref,
    String projectPath,
    AppleDeveloperCredentials credentials, {
    String? projectAppIdentifier,
  }) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _MatchRunDialog(
        projectPath: projectPath,
        credentials: credentials,
        appIdentifier: projectAppIdentifier,
      ),
    );
  }

  static void _showMatchInitDialog(BuildContext context, String projectPath, String? existingGitUrl) {
    showDialog<void>(
      context: context,
      builder: (ctx) => _MatchInitDialog(
        projectPath: projectPath,
        initialGitUrl: existingGitUrl ?? '',
      ),
    );
  }
}

/// Dialog per collegare l'account Apple Developer (Apple ID o API Key).
class _ConnectAppleDeveloperDialog extends StatefulWidget {
  const _ConnectAppleDeveloperDialog({required this.ref, this.projectTeamId});

  final WidgetRef ref;

  /// Team ID letto dal progetto (DEVELOPMENT_TEAM da Xcode). Precompila il campo Team ID se non ci sono credenziali salvate.
  final String? projectTeamId;

  @override
  State<_ConnectAppleDeveloperDialog> createState() => _ConnectAppleDeveloperDialogState();
}

class _ConnectAppleDeveloperDialogState extends State<_ConnectAppleDeveloperDialog> {
  bool _useApiKey = false;
  final _appleIdController = TextEditingController();
  final _teamIdController = TextEditingController();
  final _matchGitUrlController = TextEditingController();
  final _keyIdController = TextEditingController();
  final _issuerIdController = TextEditingController();
  final _p8PathController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final creds = widget.ref.read(appleDeveloperCredentialsProvider).whenOrNull(data: (v) => v);
    if (creds != null) {
      _useApiKey = creds.useApiKey;
      _appleIdController.text = creds.appleId ?? '';
      _teamIdController.text = creds.teamId;
      _matchGitUrlController.text = creds.matchGitUrl ?? '';
      _keyIdController.text = creds.keyId ?? '';
      _issuerIdController.text = creds.issuerId ?? '';
      _p8PathController.text = creds.p8Path ?? '';
    } else if (widget.projectTeamId != null && widget.projectTeamId!.trim().isNotEmpty) {
      final teamId = widget.projectTeamId!.trim();
      // Rimuovi eventuali virgolette dal valore letto dal pbxproj (es. "ABCD1234" -> ABCD1234)
      _teamIdController.text = teamId.replaceFirst(RegExp(r'^"(.*)"$'), r'$1').replaceFirst(RegExp(r"^'(.*)'$"), r'$1');
    }
  }

  @override
  void dispose() {
    _appleIdController.dispose();
    _teamIdController.dispose();
    _matchGitUrlController.dispose();
    _keyIdController.dispose();
    _issuerIdController.dispose();
    _p8PathController.dispose();
    super.dispose();
  }

  void _save() {
    final teamId = _teamIdController.text.trim();
    if (teamId.isEmpty) return;
    final creds = AppleDeveloperCredentials(
      appleId: _useApiKey ? null : _appleIdController.text.trim().isEmpty ? null : _appleIdController.text.trim(),
      teamId: teamId,
      matchGitUrl: _matchGitUrlController.text.trim().isEmpty ? null : _matchGitUrlController.text.trim(),
      useApiKey: _useApiKey,
      keyId: _useApiKey ? _keyIdController.text.trim().isEmpty ? null : _keyIdController.text.trim() : null,
      issuerId: _useApiKey ? _issuerIdController.text.trim().isEmpty ? null : _issuerIdController.text.trim() : null,
      p8Path: _useApiKey ? _p8PathController.text.trim().isEmpty ? null : _p8PathController.text.trim() : null,
    );
    if (!creds.isConnected) return;
    widget.ref.read(appleDeveloperCredentialsProvider.notifier).save(creds);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t_ = (String key) => t(context, key);
    return AlertDialog(
      title: Text(t_('appleDeveloper.dialogTitle')),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                value: _useApiKey,
                onChanged: (v) => setState(() => _useApiKey = v ?? false),
                title: Text(t_('appleDeveloper.useApiKey'), style: const TextStyle(fontSize: 14)),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (!_useApiKey) ...[
                TextField(
                  controller: _appleIdController,
                  decoration: InputDecoration(
                    labelText: t_('appleDeveloper.appleId'),
                    hintText: t_('appleDeveloper.appleIdHint'),
                    border: const OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _teamIdController,
                decoration: InputDecoration(
                  labelText: t_('appleDeveloper.teamId'),
                  hintText: t_('appleDeveloper.teamIdHint'),
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _matchGitUrlController,
                decoration: InputDecoration(
                  labelText: t_('appleDeveloper.matchGitUrl'),
                  hintText: t_('appleDeveloper.matchGitUrlHint'),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.next,
              ),
              if (_useApiKey) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _keyIdController,
                  decoration: InputDecoration(
                    labelText: t_('appleDeveloper.keyId'),
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _issuerIdController,
                  decoration: InputDecoration(
                    labelText: t_('appleDeveloper.issuerId'),
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _p8PathController,
                  decoration: InputDecoration(
                    labelText: t_('appleDeveloper.p8Path'),
                    hintText: t_('appleDeveloper.p8PathHint'),
                    border: const OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.done,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t_('appleDeveloper.cancel')),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(t_('appleDeveloper.save')),
        ),
      ],
    );
  }
}

/// Dialog per eseguire fastlane match con scelta tipo e output.
class _MatchRunDialog extends StatefulWidget {
  const _MatchRunDialog({
    required this.projectPath,
    required this.credentials,
    this.appIdentifier,
  });

  final String projectPath;
  final AppleDeveloperCredentials credentials;

  /// Bundle ID iOS (app identifier) per --app_identifier. Letto dal progetto se disponibile.
  final String? appIdentifier;

  @override
  State<_MatchRunDialog> createState() => _MatchRunDialogState();
}

class _MatchRunDialogState extends State<_MatchRunDialog> {
  MatchType _matchType = MatchType.development;
  final _matchPasswordController = TextEditingController();
  final List<String> _outputLines = [];
  bool _running = false;
  final _scrollController = ScrollController();

  Future<String?> _showTwoFactorDialog(String prompt) async {
    if (!mounted) return null;
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(t(ctx, 'appleDeveloper.twoFactorTitle')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t(ctx, 'appleDeveloper.twoFactorMessage')),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                onSubmitted: (value) {
                  if (value.length == 6) Navigator.of(ctx).pop(value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(t(ctx, 'appleDeveloper.cancel')),
            ),
            FilledButton(
              onPressed: () {
                final v = controller.text.trim();
                if (v.length == 6) Navigator.of(ctx).pop(v);
              },
              child: Text(t(ctx, 'appleDeveloper.twoFactorSubmit')),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _matchPasswordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollConsoleToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _outputLines.clear();
      _outputLines.add('Esecuzione: fastlane match ${_matchType.cliValue}...\n');
    });
    _scrollConsoleToEnd();
    final matchPassword = _matchPasswordController.text.trim();
    final service = FastlaneMatchService();
    final result = await service.runMatch(
      projectPath: widget.projectPath,
      credentials: widget.credentials,
      type: _matchType,
      matchPassword: matchPassword.isEmpty ? null : matchPassword,
      appIdentifier: widget.appIdentifier?.trim(),
      onOutput: (line) {
        if (mounted) {
          setState(() => _outputLines.add(line));
          _scrollConsoleToEnd();
        }
      },
      onNeedsInput: (prompt) => _showTwoFactorDialog(prompt),
    );
    if (mounted) {
      setState(() {
        _running = false;
        _outputLines.add('\nExit code: ${result.exitCode}');
      });
      _scrollConsoleToEnd();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.exitCode == 0
                ? t(context, 'appleDeveloper.matchSuccess')
                : t(context, 'appleDeveloper.matchError'),
          ),
          backgroundColor: result.exitCode == 0 ? Colors.green.shade700 : Colors.red.shade700,
        ),
      );
      if (result.exitCode == 0) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t_ = (String key) => t(context, key);
    return AlertDialog(
      title: Text(t_('appleDeveloper.syncCertificates')),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<MatchType>(
              value: _matchType,
              decoration: InputDecoration(
                labelText: t_('appleDeveloper.matchType'),
                border: const OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(value: MatchType.development, child: Text(t_('appleDeveloper.matchTypeDevelopment'))),
                DropdownMenuItem(value: MatchType.adhoc, child: Text(t_('appleDeveloper.matchTypeAdhoc'))),
                DropdownMenuItem(value: MatchType.appstore, child: Text(t_('appleDeveloper.matchTypeAppstore'))),
                DropdownMenuItem(value: MatchType.enterprise, child: Text(t_('appleDeveloper.matchTypeEnterprise'))),
              ],
              onChanged: _running ? null : (v) => setState(() => _matchType = v ?? MatchType.development),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _matchPasswordController,
              decoration: InputDecoration(
                labelText: t_('appleDeveloper.matchPassword'),
                hintText: t_('appleDeveloper.matchPasswordHint'),
                border: const OutlineInputBorder(),
              ),
              obscureText: true,
              enabled: !_running,
            ),
            const SizedBox(height: 12),
            Text(t_('appleDeveloper.matchOutput'), style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.outline),
              ),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                itemCount: _outputLines.length,
                itemBuilder: (_, i) => SelectableText(
                  _outputLines[i],
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _running ? null : () => Navigator.of(context).pop(),
          child: Text(t_('appleDeveloper.cancel')),
        ),
        FilledButton(
          onPressed: _running ? null : _run,
          child: _running
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(t_('appleDeveloper.runMatch')),
        ),
      ],
    );
  }
}

/// Dialog per eseguire fastlane match init (inizializzazione repository Match).
class _MatchInitDialog extends StatefulWidget {
  const _MatchInitDialog({required this.projectPath, required this.initialGitUrl});

  final String projectPath;
  final String initialGitUrl;

  @override
  State<_MatchInitDialog> createState() => _MatchInitDialogState();
}

class _MatchInitDialogState extends State<_MatchInitDialog> {
  final _gitUrlController = TextEditingController();
  final _matchPasswordController = TextEditingController();
  final List<String> _outputLines = [];
  bool _running = false;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _gitUrlController.text = widget.initialGitUrl;
  }

  Future<String?> _showTwoFactorDialog(String prompt) async {
    if (!mounted) return null;
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          title: Text(t(ctx, 'appleDeveloper.twoFactorTitle')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t(ctx, 'appleDeveloper.twoFactorMessage')),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                keyboardType: TextInputType.number,
                maxLength: 6,
                autofocus: true,
                onSubmitted: (value) {
                  if (value.length == 6) Navigator.of(ctx).pop(value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(t(ctx, 'appleDeveloper.cancel')),
            ),
            FilledButton(
              onPressed: () {
                final v = controller.text.trim();
                if (v.length == 6) Navigator.of(ctx).pop(v);
              },
              child: Text(t(ctx, 'appleDeveloper.twoFactorSubmit')),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _gitUrlController.dispose();
    _matchPasswordController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollConsoleToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _run() async {
    if (_running) return;
    final gitUrl = _gitUrlController.text.trim();
    final matchPassword = _matchPasswordController.text.trim();
    setState(() {
      _running = true;
      _outputLines.clear();
      _outputLines.add('Esecuzione: fastlane match init${gitUrl.isEmpty ? '' : ' --git_url $gitUrl'}...\n');
    });
    _scrollConsoleToEnd();
    final service = FastlaneMatchService();
    final result = await service.runMatchInit(
      projectPath: widget.projectPath,
      gitUrl: gitUrl.isEmpty ? null : gitUrl,
      matchPassword: matchPassword.isEmpty ? null : matchPassword,
      onOutput: (line) {
        if (mounted) {
          setState(() => _outputLines.add(line));
          _scrollConsoleToEnd();
        }
      },
      onNeedsInput: (prompt) => _showTwoFactorDialog(prompt),
    );
    if (mounted) {
      setState(() {
        _running = false;
        _outputLines.add('\nExit code: ${result.exitCode}');
      });
      _scrollConsoleToEnd();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.exitCode == 0
                ? t(context, 'appleDeveloper.initMatchSuccess')
                : t(context, 'appleDeveloper.initMatchError'),
          ),
          backgroundColor: result.exitCode == 0 ? Colors.green.shade700 : Colors.red.shade700,
        ),
      );
      if (result.exitCode == 0) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t_ = (String key) => t(context, key);
    return AlertDialog(
      title: Text(t_('appleDeveloper.initMatch')),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t_('appleDeveloper.initMatchHint'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _gitUrlController,
              decoration: InputDecoration(
                labelText: t_('appleDeveloper.matchGitUrl'),
                hintText: t_('appleDeveloper.matchGitUrlHint'),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              enabled: !_running,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _matchPasswordController,
              decoration: InputDecoration(
                labelText: t_('appleDeveloper.matchPassword'),
                hintText: t_('appleDeveloper.matchPasswordHint'),
                border: const OutlineInputBorder(),
              ),
              obscureText: true,
              enabled: !_running,
            ),
            const SizedBox(height: 12),
            Text(t_('appleDeveloper.matchOutput'), style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).colorScheme.outline),
              ),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(8),
                itemCount: _outputLines.length,
                itemBuilder: (_, i) => SelectableText(
                  _outputLines[i],
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 11),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _running ? null : () => Navigator.of(context).pop(),
          child: Text(t_('appleDeveloper.cancel')),
        ),
        FilledButton(
          onPressed: _running ? null : _run,
          child: _running
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(t_('appleDeveloper.runInit')),
        ),
      ],
    );
  }
}
