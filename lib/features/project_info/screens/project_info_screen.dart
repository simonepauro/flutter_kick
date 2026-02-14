import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_kick/core/l10n/translation.dart';
import 'package:flutter_kick/core/widgets/fk_copyable_error.dart';
import 'package:flutter_kick/core/widgets/fk_scaffold.dart';

import '../models/dependency_info.dart';
import '../models/flutter_project_info.dart';
import '../providers/project_info_provider.dart';

/// Panel to embed in a parent screen: shows project info or env tab content.
/// Use with [projectPath] and [tabIndex]: 0 = Project info, 1 = Environment.
class ProjectInfoPanel extends ConsumerWidget {
  const ProjectInfoPanel({super.key, required this.projectPath, required this.tabIndex});

  final String projectPath;
  final int tabIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncInfo = ref.watch(projectInfoProvider(projectPath));
    return asyncInfo.when(
      data: (info) => tabIndex == 0
          ? _ProjectInfoTabBody(projectPath: projectPath, info: info)
          : _ProjectEnvTabBody(projectPath: projectPath, info: info),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => FKCopyableError(
        message: err.toString(),
        title: t(context, 'projectInfo.loadError'),
      ),
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
          children: [if (info.sdkConstraint != null) _InfoRow(label: t(context, 'projectInfo.sdk'), value: info.sdkConstraint!)],
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
          title: t(context, 'projectInfo.dependenciesCount', translationParams: {'count': '${info.dependencies.length}'}),
          child: info.dependencies.isEmpty
              ? Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t(context, 'projectInfo.noDependencies')))
              : _DependencyList(
                  projectPath: projectPath,
                  dependencies: info.dependencies,
                ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: t(context, 'projectInfo.devDependenciesCount', translationParams: {'count': '${info.devDependencies.length}'}),
          child: info.devDependencies.isEmpty
              ? Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t(context, 'projectInfo.noDevDependencies')))
              : _DependencyList(
                  projectPath: projectPath,
                  dependencies: info.devDependencies,
                ),
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
      ],
    );
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
                          avatar: Icon(Icons.description_outlined, size: 18, color: Theme.of(context).colorScheme.onSurface),
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
                          avatar: Icon(Icons.description_outlined, size: 18, color: Theme.of(context).colorScheme.onSurface),
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

class _DependencyList extends ConsumerWidget {
  const _DependencyList({
    required this.projectPath,
    required this.dependencies,
  });

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
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
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
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
