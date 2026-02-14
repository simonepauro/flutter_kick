import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_kick/core/l10n/translation.dart';
import 'package:flutter_kick/core/widgets/fk_copyable_error.dart';
import 'package:flutter_kick/core/widgets/fk_scaffold.dart';

import '../models/dependency_info.dart';
import '../models/flutter_project_info.dart';
import '../providers/project_info_provider.dart';

/// Apre il file nel file manager di sistema (Finder su macOS, Explorer su Windows, ecc.).
Future<void> revealInFinder(String path) async {
  final file = File(path);
  if (!file.existsSync()) return;
  if (Platform.isMacOS) {
    await Process.run('open', ['-R', path]);
  } else if (Platform.isWindows) {
    await Process.run('explorer', ['/select,', path]);
  } else {
    final dir = File(path).parent.path;
    await Process.run('xdg-open', [dir]);
  }
}

/// Panel to embed in a parent screen: shows project info, env, app icons or signing tab content.
/// Use with [projectPath] and [tabIndex]: 0 = Project info, 1 = Environment, 2 = App icons, 3 = Signing.
class ProjectInfoPanel extends ConsumerWidget {
  const ProjectInfoPanel({super.key, required this.projectPath, required this.tabIndex});

  final String projectPath;
  final int tabIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncInfo = ref.watch(projectInfoProvider(projectPath));
    return asyncInfo.when(
      data: (info) {
        if (tabIndex == 0) return _ProjectInfoTabBody(projectPath: projectPath, info: info);
        if (tabIndex == 1) return _ProjectEnvTabBody(projectPath: projectPath, info: info);
        if (tabIndex == 2) return _ProjectAppIconsTabBody(info: info);
        return _ProjectSigningTabBody(info: info);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => FKCopyableError(message: err.toString(), title: t(context, 'projectInfo.loadError')),
    );
  }
}

/// Tab "Project info": solo dati da pubspec (project, environment, platforms, dependencies, path).
class _ProjectInfoTabBody extends ConsumerWidget {
  const _ProjectInfoTabBody({required this.projectPath, required this.info});

  final String projectPath;
  final FlutterProjectInfo info;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: t(context, 'projectInfo.project'),
          children: [
            _InfoRow(label: t(context, 'projectInfo.name'), value: info.name),
            if (info.description != null && info.description!.isNotEmpty)
              _InfoRow(label: t(context, 'projectInfo.description'), value: info.description!),
            if (info.version != null) _InfoRow(label: t(context, 'projectInfo.version'), value: info.version!),
            if (info.publishTo != null) _InfoRow(label: t(context, 'projectInfo.publishTo'), value: info.publishTo!),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: t(context, 'projectInfo.environment'),
          children: [
            if (info.flutterVersion != null)
              _InfoRow(label: t(context, 'projectInfo.flutter'), value: info.flutterVersion!),
            if (info.sdkConstraint != null) _InfoRow(label: t(context, 'projectInfo.sdk'), value: info.sdkConstraint!),
          ],
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: t(context, 'projectInfo.platforms'),
          child: info.platforms.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(t(context, 'projectInfo.noPlatforms')),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: info.platforms
                      .map(
                        (p) => Chip(
                          label: Text(p),
                          avatar: Icon(_platformIcon(p), size: 18, color: Theme.of(context).colorScheme.onSurface),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: t(
            context,
            'projectInfo.dependenciesCount',
            translationParams: {'count': '${info.dependencies.length}'},
          ),
          child: info.dependencies.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(t(context, 'projectInfo.noDependencies')),
                )
              : _DependencyList(projectPath: projectPath, dependencies: info.dependencies),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: t(
            context,
            'projectInfo.devDependenciesCount',
            translationParams: {'count': '${info.devDependencies.length}'},
          ),
          child: info.devDependencies.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(t(context, 'projectInfo.noDevDependencies')),
                )
              : _DependencyList(projectPath: projectPath, dependencies: info.devDependencies),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: t(context, 'projectInfo.path'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SelectableText(
              info.projectPath,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
          ),
        ),
        if (info.platforms.contains('ios') && info.iosBuildSettings.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: t(context, 'projectInfo.buildSettingsIos'),
            children: _buildSettingsEntries(context, info.iosBuildSettings),
          ),
        ],
        if (info.platforms.contains('android') && info.androidGradleSettings.isNotEmpty) ...[
          const SizedBox(height: 12),
          _SectionCard(
            title: t(context, 'projectInfo.buildSettingsAndroid'),
            children: _buildSettingsEntries(context, info.androidGradleSettings),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildSettingsEntries(BuildContext context, Map<String, String> settings) {
    final keys = settings.keys.toList()..sort();
    return keys.map((k) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 220,
              child: SelectableText(
                k,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
            Expanded(
              child: SelectableText(settings[k]!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          ],
        ),
      );
    }).toList();
  }

  IconData _platformIcon(String platform) {
    switch (platform) {
      case 'android':
        return Icons.android;
      case 'ios':
        return Icons.apple;
      case 'web':
        return Icons.web;
      case 'macos':
        return Icons.laptop_mac;
      case 'windows':
        return Icons.desktop_windows;
      case 'linux':
        return Icons.computer;
      default:
        return Icons.folder;
    }
  }
}

/// Tab "Environment": tutto ciò che non è da pubspec (flavors, env files, scripts, Firebase, Dart env).
class _ProjectEnvTabBody extends StatelessWidget {
  const _ProjectEnvTabBody({required this.projectPath, required this.info});

  final String projectPath;
  final FlutterProjectInfo info;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: t(context, 'projectInfo.flavorsAndroid'),
          child: info.androidFlavors.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(t(context, 'projectInfo.noFlavors')),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: info.androidFlavors
                      .map(
                        (f) => Chip(
                          label: Text(f),
                          avatar: Icon(Icons.layers_outlined, size: 18, color: Theme.of(context).colorScheme.onSurface),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: t(context, 'projectInfo.flavorsIos'),
          child: info.iosFlavors.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(t(context, 'projectInfo.noFlavors')),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: info.iosFlavors
                      .map(
                        (f) => Chip(
                          label: Text(f),
                          avatar: Icon(Icons.layers_outlined, size: 18, color: Theme.of(context).colorScheme.onSurface),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: t(context, 'projectInfo.envAndroid'),
          child: info.androidEnvFiles.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(t(context, 'projectInfo.noEnvFiles')),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: info.androidEnvFiles
                      .map(
                        (f) => Chip(
                          label: Text(f),
                          avatar: Icon(
                            Icons.description_outlined,
                            size: 18,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: t(context, 'projectInfo.envIos'),
          child: info.iosEnvFiles.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(t(context, 'projectInfo.noEnvFiles')),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: info.iosEnvFiles
                      .map(
                        (f) => Chip(
                          label: Text(f),
                          avatar: Icon(
                            Icons.description_outlined,
                            size: 18,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: t(context, 'projectInfo.envScripts'),
          child: info.envScripts.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(t(context, 'projectInfo.noEnvScripts')),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: info.envScripts
                        .map(
                          (s) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Icon(Icons.terminal, size: 20, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Text(
                                  s.envName,
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 8),
                                SelectableText(
                                  s.scriptFile,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: t(context, 'projectInfo.firebaseEnvs'),
          child: info.firebaseEnvs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(t(context, 'projectInfo.noFirebaseEnvs')),
                )
              : Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: info.firebaseEnvs
                      .map(
                        (e) => Chip(
                          label: Text(e),
                          avatar: Icon(Icons.cloud_outlined, size: 18, color: Theme.of(context).colorScheme.onSurface),
                        ),
                      )
                      .toList(),
                ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: t(context, 'projectInfo.dartEnvSources'),
          child: info.dartEnvSourceFiles.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(t(context, 'projectInfo.noDartEnvSources')),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: info.dartEnvSourceFiles
                        .map(
                          (f) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: SelectableText(
                              f,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
        ),
      ],
    );
  }
}

/// Tab "Signing": come viene firmata l'app su iOS e Android (code signing / signing config).
class _ProjectSigningTabBody extends StatelessWidget {
  const _ProjectSigningTabBody({required this.info});

  final FlutterProjectInfo info;

  @override
  Widget build(BuildContext context) {
    final hasIos = info.platforms.contains('ios');
    final hasAndroid = info.platforms.contains('android');
    final iosEmpty = info.iosSigningSettings.isEmpty;
    final androidEmpty = info.androidSigningSettings.isEmpty;
    if (!hasIos && !hasAndroid) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            t(context, 'projectInfo.noPlatforms'),
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (hasIos && hasAndroid && iosEmpty && androidEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            t(context, 'projectInfo.noSigningConfig'),
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (hasIos) ...[
          _SectionCard(
            title: t(context, 'projectInfo.signingIos'),
            children: iosEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(t(context, 'projectInfo.noSigningConfig')),
                    ),
                  ]
                : (info.iosSigningSettings.keys.toList()..sort())
                      .map((k) => _InfoRow(label: k, value: info.iosSigningSettings[k]!))
                      .toList(),
          ),
          const SizedBox(height: 12),
        ],
        if (hasAndroid) ...[
          _SectionCard(
            title: t(context, 'projectInfo.signingAndroid'),
            children: androidEmpty
                ? [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(t(context, 'projectInfo.noSigningConfig')),
                    ),
                  ]
                : (info.androidSigningSettings.keys.toList()..sort())
                      .map((k) => _InfoRow(label: k, value: info.androidSigningSettings[k]!))
                      .toList(),
          ),
        ],
      ],
    );
  }
}

/// Tab "App icons": icone app e splash screen per iOS e Android.
class _ProjectAppIconsTabBody extends StatelessWidget {
  const _ProjectAppIconsTabBody({required this.info});

  final FlutterProjectInfo info;

  @override
  Widget build(BuildContext context) {
    final hasAnyIcon = info.iosAppIconPath != null || info.androidAppIconPath != null;
    final hasAnySplash = info.iosSplashPath != null || info.androidSplashPath != null;
    if (!hasAnyIcon && !hasAnySplash) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            t(context, 'projectInfo.noAppIcons'),
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionCard(
          title: t(context, 'projectInfo.appIcons'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _AppIconTile(
                    platformLabel: t(context, 'projectInfo.iosIcon'),
                    iconPath: info.iosAppIconPath,
                    iconData: Icons.apple,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _AppIconTile(
                    platformLabel: t(context, 'projectInfo.androidIcon'),
                    iconPath: info.androidAppIconPath,
                    iconData: Icons.android,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: t(context, 'projectInfo.splashScreen'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: _AppIconTile(
                    platformLabel: t(context, 'projectInfo.iosIcon'),
                    iconPath: info.iosSplashPath,
                    iconData: Icons.apple,
                    size: 120,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _AppIconTile(
                    platformLabel: t(context, 'projectInfo.androidIcon'),
                    iconPath: info.androidSplashPath,
                    iconData: Icons.android,
                    size: 120,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-screen wrapper (kept for compatibility; prefer embedding [ProjectInfoPanel] with segmented control).
class ProjectInfoScreen extends ConsumerWidget {
  const ProjectInfoScreen({super.key, required this.projectPath});

  final String projectPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FKScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(t(context, 'projectInfo.title')),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).pop()),
      ),
      body: ProjectInfoPanel(projectPath: projectPath, tabIndex: 0),
    );
  }
}

class _AppIconTile extends StatelessWidget {
  const _AppIconTile({required this.platformLabel, required this.iconPath, required this.iconData, this.size = 80});

  final String platformLabel;
  final String? iconPath;
  final IconData iconData;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasPath = iconPath != null && File(iconPath!).existsSync();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          platformLabel,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasPath
              ? Image.file(File(iconPath!), fit: BoxFit.contain)
              : Icon(iconData, size: size * 0.5, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        if (hasPath && iconPath != null) ...[
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => revealInFinder(iconPath!),
            icon: const Icon(Icons.folder_open, size: 18),
            label: Text(t(context, 'projectInfo.showInFinder')),
          ),
        ],
      ],
    );
  }
}

class _DependencyList extends ConsumerWidget {
  const _DependencyList({required this.projectPath, required this.dependencies});

  final String projectPath;
  final List<DependencyInfo> dependencies;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStatus = ref.watch(dependencyStatusProvider(projectPath));
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: dependencies.map((d) {
          final status = asyncStatus.hasValue ? asyncStatus.value : null;
          final hasUpdate = status?.hasUpdate(d.name) ?? false;
          final isDeprecated = status?.isDeprecated(d.name) ?? false;
          final outdatedInfo = status?.outdated[d.name];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('• ', style: Theme.of(context).textTheme.bodyMedium),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: SelectableText(
                              d.constraint != null ? '${d.name} ${d.constraint}' : d.name,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: isDeprecated
                                    ? Theme.of(context).colorScheme.error
                                    : hasUpdate
                                    ? Theme.of(context).colorScheme.tertiary
                                    : null,
                                decoration: isDeprecated ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          if (isDeprecated || hasUpdate) ...[
                            const SizedBox(width: 8),
                            if (isDeprecated)
                              _StatusChip(
                                label: t(context, 'projectInfo.deprecated'),
                                color: Theme.of(context).colorScheme.error,
                              ),
                            if (hasUpdate && !isDeprecated) ...[
                              _StatusChip(
                                label: outdatedInfo?.latest != null
                                    ? '${t(context, 'projectInfo.updateAvailable')} → ${outdatedInfo!.latest}'
                                    : t(context, 'projectInfo.updateAvailable'),
                                color: Theme.of(context).colorScheme.tertiary,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  _SectionCard({required this.title, this.children = const [], this.child}) : assert(children.isEmpty || child == null);

  final String title;
  final List<Widget> children;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (child != null) child! else ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          SizedBox(width: 16),

          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
