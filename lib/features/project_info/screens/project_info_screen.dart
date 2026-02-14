import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_kick/core/l10n/translation.dart';
import 'package:flutter_kick/core/widgets/fk_copyable_error.dart';
import 'package:flutter_kick/core/widgets/fk_expandable_section.dart';
import 'package:flutter_kick/core/widgets/fk_scaffold.dart';

import '../models/dependency_info.dart';
import '../models/flutter_project_info.dart';
import '../providers/project_info_provider.dart';

/// Apre il file o la cartella nel file manager di sistema (Finder su macOS, Explorer su Windows, ecc.).
/// Restituisce [true] se il path esiste e il comando è stato avviato, [false] altrimenti.
Future<bool> revealInFinder(String path) async {
  final normalized = path.replaceAll(RegExp(r'/+'), '/').replaceFirst(RegExp(r'/$'), '');
  final exists = File(normalized).existsSync() || Directory(normalized).existsSync();
  if (!exists) return false;
  if (Platform.isMacOS) {
    await Process.run('open', ['-R', normalized]);
  } else if (Platform.isWindows) {
    await Process.run('explorer', ['/select,', normalized]);
  } else {
    final dir = File(normalized).existsSync() ? File(normalized).parent.path : normalized;
    await Process.run('xdg-open', [dir]);
  }
  return true;
}

/// Restituisce i testi delle sezioni per la tab [tabIndex], usati per la ricerca (Cmd+F).
List<String> buildSectionTextsForTab(FlutterProjectInfo info, int tabIndex) {
  switch (tabIndex) {
    case 0:
      return _sectionTextsTabInfo(info);
    case 1:
      return _sectionTextsTabEnv(info);
    case 2:
      return _sectionTextsTabIcons(info);
    case 3:
      return _sectionTextsTabSigning(info);
    case 4:
      return _sectionTextsTabRelease(info);
    default:
      return [];
  }
}

List<String> _sectionTextsTabRelease(FlutterProjectInfo info) {
  final envs = _releaseEnvironmentNames(info);
  return [envs.join(' '), info.platforms.join(' ')];
}

List<String> _sectionTextsTabInfo(FlutterProjectInfo info) {
  final list = <String>[
    [info.name, info.description, info.version, info.publishTo].whereType<String>().join(' '),
    [info.flutterVersion, info.sdkConstraint].whereType<String>().join(' '),
    info.platforms.join(' '),
    info.dependencies.map((d) => '${d.name} ${d.constraint ?? ''}').join(' '),
    info.devDependencies.map((d) => '${d.name} ${d.constraint ?? ''}').join(' '),
    info.projectPath,
  ];
  if (info.platforms.contains('ios') && info.iosBuildSettings.isNotEmpty) {
    list.add(info.iosBuildSettings.entries.map((e) => '${e.key} ${e.value}').join(' '));
  }
  if (info.platforms.contains('android') && info.androidGradleSettings.isNotEmpty) {
    list.add(info.androidGradleSettings.entries.map((e) => '${e.key} ${e.value}').join(' '));
  }
  return list;
}

List<String> _sectionTextsTabEnv(FlutterProjectInfo info) {
  return [
    info.androidFlavors.join(' '),
    info.iosFlavors.join(' '),
    info.androidEnvFiles.join(' '),
    info.iosEnvFiles.join(' '),
    info.launchJsonPath ?? '',
    info.envScripts.map((s) => '${s.envName} ${s.scriptFile}').join(' '),
    info.firebaseEnvs.join(' '),
    info.dartEnvSourceFiles.join(' '),
  ];
}

List<String> _sectionTextsTabIcons(FlutterProjectInfo info) {
  final iosText = info.iosAppIcons.map((e) => '${e.label} ${e.path}').join(' ') + (info.iosAppIconPath ?? '');
  final androidText =
      info.androidAppIcons.map((e) => '${e.label} ${e.path}').join(' ') + (info.androidAppIconPath ?? '');
  final assetsFontsText =
      '${info.assets.map((a) => a.path).join(' ')} ${info.fonts.map((f) => f.family).join(' ')}';
  return ['iOS $iosText Android $androidText', '${info.iosSplashPath ?? ''} ${info.androidSplashPath ?? ''}', assetsFontsText];
}

String _formatAssetBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

Widget _buildAssetsSectionWidget(BuildContext context, FlutterProjectInfo info) {
  if (info.assets.isEmpty) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(t(context, 'projectInfo.noAssets')),
    );
  }
  final totalFormatted = _formatAssetBytes(info.totalAssetSizeBytes);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(CupertinoIcons.folder, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            t(context, 'projectInfo.assetsList'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Text(
            t(context, 'projectInfo.totalAssetSize', translationParams: {'size': totalFormatted}),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      ...info.assets.map(
        (e) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SelectableText(
                  e.path,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                ),
              ),
              const SizedBox(width: 8),
              SelectableText(
                _formatAssetBytes(e.sizeBytes),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

Widget _buildFontsSectionWidget(BuildContext context, FlutterProjectInfo info) {
  if (info.fonts.isEmpty) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(t(context, 'projectInfo.noFonts')),
    );
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(CupertinoIcons.textformat, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            t(context, 'projectInfo.fontsList'),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      const SizedBox(height: 8),
      ...info.fonts.expand((f) => [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                f.family,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            ...f.variants.map(
              (v) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SelectableText(
                        v.assetPath,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
                      ),
                    ),
                    if (v.weight != null || (v.style != null && v.style!.isNotEmpty))
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(
                          [
                            if (v.weight != null) 'weight: ${v.weight}',
                            if (v.style != null && v.style!.isNotEmpty) 'style: ${v.style}',
                          ].join(', '),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ]),
    ],
  );
}

List<String> _sectionTextsTabSigning(FlutterProjectInfo info) {
  final list = <String>[];
  if (info.platforms.contains('ios')) {
    list.add(info.iosSigningSettings.entries.map((e) => '${e.key} ${e.value}').join(' '));
  }
  if (info.platforms.contains('android')) {
    list.add(info.androidSigningSettings.entries.map((e) => '${e.key} ${e.value}').join(' '));
  }
  return list;
}

/// Nomi ambienti per la tab Release: da flavor di progetto o default Dev/Staging/Prod.
List<String> _releaseEnvironmentNames(FlutterProjectInfo info) {
  final flavors = <String>{...info.androidFlavors, ...info.iosFlavors};
  if (flavors.isNotEmpty) return flavors.toList()..sort();
  return ['Development', 'Staging', 'Production'];
}

/// Panel to embed in a parent screen: shows project info, env, app icons, release or signing tab content.
/// Use with [projectPath] and [tabIndex]: 0 = Project info, 1 = Environment, 2 = App icons, 3 = Signing.
/// If [sectionKeys] is provided, sections are keyed for find-in-page (Cmd+F) scroll.
/// If [highlightSectionIndex] >= 0, that section is visually highlighted as the current search match.
class ProjectInfoPanel extends ConsumerWidget {
  const ProjectInfoPanel({
    super.key,
    required this.projectPath,
    required this.tabIndex,
    this.sectionKeys,
    this.highlightSectionIndex = -1,
  });

  final String projectPath;
  final int tabIndex;
  final List<GlobalKey>? sectionKeys;
  final int highlightSectionIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncInfo = ref.watch(projectInfoProvider(projectPath));
    return asyncInfo.when(
      data: (info) {
        if (tabIndex == 0) {
          return _ProjectInfoTabBody(
            projectPath: projectPath,
            info: info,
            sectionKeys: sectionKeys,
            highlightSectionIndex: highlightSectionIndex,
          );
        }
        if (tabIndex == 1) {
          return _ProjectEnvTabBody(
            projectPath: projectPath,
            info: info,
            sectionKeys: sectionKeys,
            highlightSectionIndex: highlightSectionIndex,
          );
        }
        if (tabIndex == 2) {
          return _ProjectAppIconsTabBody(
            info: info,
            sectionKeys: sectionKeys,
            highlightSectionIndex: highlightSectionIndex,
          );
        }
        if (tabIndex == 4) {
          return _ProjectReleaseTabBody(
            projectPath: projectPath,
            info: info,
            sectionKeys: sectionKeys,
            highlightSectionIndex: highlightSectionIndex,
          );
        }
        return _ProjectSigningTabBody(
          info: info,
          sectionKeys: sectionKeys,
          highlightSectionIndex: highlightSectionIndex,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => FKCopyableError(message: err.toString(), title: t(context, 'projectInfo.loadError')),
    );
  }
}

/// Tab "Project info": solo dati da pubspec (project, environment, platforms, dependencies, path).
class _ProjectInfoTabBody extends ConsumerWidget {
  const _ProjectInfoTabBody({
    required this.projectPath,
    required this.info,
    this.sectionKeys,
    this.highlightSectionIndex = -1,
  });

  final String projectPath;
  final FlutterProjectInfo info;
  final List<GlobalKey>? sectionKeys;
  final int highlightSectionIndex;

  Widget _wrapSection(BuildContext context, Widget child, int index) {
    Widget w = child;
    if (highlightSectionIndex == index) {
      w = Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        child: w,
      );
    }
    if (sectionKeys != null && index < sectionKeys!.length) {
      return KeyedSubtree(key: sectionKeys![index], child: w);
    }
    return w;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var sectionIndex = 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _wrapSection(
          context,
          FkExpandableSection(
            title: t(context, 'projectInfo.project'),
            children: [
              _InfoRow(label: t(context, 'projectInfo.name'), value: info.name),
              if (info.description != null && info.description!.isNotEmpty)
                _InfoRow(label: t(context, 'projectInfo.description'), value: info.description!),
              if (info.version != null) _InfoRow(label: t(context, 'projectInfo.version'), value: info.version!),
              if (info.publishTo != null) _InfoRow(label: t(context, 'projectInfo.publishTo'), value: info.publishTo!),
            ],
          ),
          sectionIndex++,
        ),
        const SizedBox(height: 12),
        _wrapSection(
          context,
          FkExpandableSection(
            title: t(context, 'projectInfo.environment'),
            children: [
              if (info.flutterVersion != null)
                _InfoRow(label: t(context, 'projectInfo.flutter'), value: info.flutterVersion!),
              if (info.sdkConstraint != null)
                _InfoRow(label: t(context, 'projectInfo.sdk'), value: info.sdkConstraint!),
            ],
          ),
          sectionIndex++,
        ),
        const SizedBox(height: 12),
        _wrapSection(
          context,
          FkExpandableSection(
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
          sectionIndex++,
        ),
        const SizedBox(height: 12),
        _wrapSection(
          context,
          FkExpandableSection(
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
          sectionIndex++,
        ),
        const SizedBox(height: 12),
        _wrapSection(
          context,
          FkExpandableSection(
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
          sectionIndex++,
        ),
        const SizedBox(height: 12),
        _wrapSection(
          context,
          FkExpandableSection(
            title: t(context, 'projectInfo.path'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: SelectableText(
                info.projectPath,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
              ),
            ),
          ),
          sectionIndex++,
        ),
        if (info.platforms.contains('ios') && info.iosBuildSettings.isNotEmpty) ...[
          const SizedBox(height: 12),
          _wrapSection(
            context,
            FkExpandableSection(
              title: t(context, 'projectInfo.buildSettingsIos'),
              children: _buildSettingsEntries(context, info.iosBuildSettings),
            ),
            sectionIndex++,
          ),
        ],
        if (info.platforms.contains('android') && info.androidGradleSettings.isNotEmpty) ...[
          const SizedBox(height: 12),
          _wrapSection(
            context,
            FkExpandableSection(
              title: t(context, 'projectInfo.buildSettingsAndroid'),
              children: _buildSettingsEntries(context, info.androidGradleSettings),
            ),
            sectionIndex++,
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
        return Icons.android; // Cupertino non ha icona Android
      case 'ios':
        return CupertinoIcons.device_phone_portrait;
      case 'web':
        return CupertinoIcons.globe;
      case 'macos':
        return Icons.laptop_mac; // Cupertino non ha icona laptop in questa versione
      case 'windows':
      case 'linux':
        return Icons.computer;
      default:
        return CupertinoIcons.folder;
    }
  }
}

/// Tab "Environment": tutto ciò che non è da pubspec (flavors, env files, scripts, Firebase, Dart env).
class _ProjectEnvTabBody extends StatelessWidget {
  const _ProjectEnvTabBody({
    required this.projectPath,
    required this.info,
    this.sectionKeys,
    this.highlightSectionIndex = -1,
  });

  final String projectPath;
  final FlutterProjectInfo info;
  final List<GlobalKey>? sectionKeys;
  final int highlightSectionIndex;

  Widget _wrapSection(BuildContext context, Widget child, int index) {
    Widget w = child;
    if (highlightSectionIndex == index) {
      w = Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        child: w,
      );
    }
    if (sectionKeys != null && index < sectionKeys!.length) {
      return KeyedSubtree(key: sectionKeys![index], child: w);
    }
    return w;
  }

  @override
  Widget build(BuildContext context) {
    var sectionIndex = 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _wrapSection(
          context,
          FkExpandableSection(
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
                            avatar: Icon(
                              CupertinoIcons.square_stack_3d_up,
                              size: 18,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          sectionIndex++,
        ),
        const SizedBox(height: 12),
        _wrapSection(
          context,
          FkExpandableSection(
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
                            avatar: Icon(
                              CupertinoIcons.square_stack_3d_up,
                              size: 18,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          sectionIndex++,
        ),
        const SizedBox(height: 12),
        _wrapSection(
          context,
          FkExpandableSection(
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
                              CupertinoIcons.doc_text,
                              size: 18,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          sectionIndex++,
        ),
        const SizedBox(height: 12),
        _wrapSection(
          context,
          FkExpandableSection(
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
                              CupertinoIcons.doc_text,
                              size: 18,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          sectionIndex++,
        ),
        const SizedBox(height: 12),
        _wrapSection(
          context,
          FkExpandableSection(
            title: t(context, 'projectInfo.launchJson'),
            child: info.launchJsonPath == null
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(t(context, 'projectInfo.noLaunchJson')),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(CupertinoIcons.play_circle, size: 20, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 8),
                            SelectableText(
                              info.launchJsonPath!,
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          t(context, 'projectInfo.launchConfigurations'),
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        info.launchConfigurations.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text(
                                  t(context, 'projectInfo.noLaunchConfigurations'),
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: info.launchConfigurations
                                    .map(
                                      (c) => Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: Row(
                                          children: [
                                            Icon(
                                              CupertinoIcons.settings,
                                              size: 18,
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: SelectableText(
                                                c.flavor != null ? '${c.name} flavor = ${c.flavor}' : c.name,
                                                style: Theme.of(context).textTheme.bodyMedium,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                      ],
                    ),
                  ),
          ),
          sectionIndex++,
        ),
        const SizedBox(height: 12),
        _wrapSection(
          context,
          FkExpandableSection(
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
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
          sectionIndex++,
        ),
        const SizedBox(height: 12),
        _wrapSection(
          context,
          FkExpandableSection(
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
                            avatar: Icon(
                              CupertinoIcons.cloud,
                              size: 18,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          sectionIndex++,
        ),
        const SizedBox(height: 12),
        _wrapSection(
          context,
          FkExpandableSection(
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
          sectionIndex++,
        ),
      ],
    );
  }
}

/// Tab "Release": pulsante per ogni ambiente per build/release (usa flavor se presenti).
class _ProjectReleaseTabBody extends StatefulWidget {
  const _ProjectReleaseTabBody({
    required this.projectPath,
    required this.info,
    this.sectionKeys,
    this.highlightSectionIndex = -1,
  });

  final String projectPath;
  final FlutterProjectInfo info;
  final List<GlobalKey>? sectionKeys;
  final int highlightSectionIndex;

  @override
  State<_ProjectReleaseTabBody> createState() => _ProjectReleaseTabBodyState();
}

/// Prefs: JSON map projectPath -> (buildKey -> seconds), e.g. {"path": {"prod:android": 120}}.
const _prefsKeyLastBuildDurations = 'release_last_build_durations';

/// Prefs: JSON map projectPath -> (buildKey -> output). Output troncato a _maxCachedConsoleChars.
const _prefsKeyConsoleOutputs = 'release_console_outputs';
const _maxCachedConsoleChars = 50000;

/// Formatta una durata in secondi in testo breve (es. "2 min", "45 sec").
String _formatBuildDuration(int totalSeconds) {
  if (totalSeconds < 60) return '${totalSeconds} sec';
  final min = totalSeconds ~/ 60;
  final sec = totalSeconds % 60;
  if (sec == 0) return '$min min';
  return '$min min $sec sec';
}

/// Formatta secondi in "M:SS" per il timer in corso (es. "1:23").
String _formatElapsed(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Risolve l'eseguibile Flutter: FVM nel progetto (.fvm/flutter_sdk/bin/flutter) oppure 'flutter' da PATH.
Future<String> _resolveFlutterExecutable(String projectPath) async {
  final fvmFlutter = Platform.isWindows
      ? File('$projectPath/.fvm/flutter_sdk/bin/flutter.bat')
      : File('$projectPath/.fvm/flutter_sdk/bin/flutter');
  if (await fvmFlutter.exists()) return fvmFlutter.path;
  return 'flutter';
}

const _platformAndroid = 'android';
const _platformIos = 'ios';

/// Path dell'artefatto dopo un build riuscito (APK, IPA cartella, o AAB).
String _builtArtifactPath(String projectPath, String platform, String? flavorArg) {
  if (platform == _platformAndroid) {
    final suffix = flavorArg != null ? '-$flavorArg-release.apk' : '-release.apk';
    return '$projectPath/build/app/outputs/flutter-apk/app$suffix';
  }
  // iOS: cartella che contiene l'.ipa
  return '$projectPath/build/ios/ipa';
}

class _ProjectReleaseTabBodyState extends State<_ProjectReleaseTabBody> {
  /// Keys: 'envName:android' or 'envName:ios'
  final Set<String> _runningBuilds = {};
  final Map<String, DateTime> _buildStartTimes = {};
  final Map<String, int> _elapsedSecondsByKey = {};
  Timer? _buildTimer;

  /// Ultima durata build per buildKey (env:platform), persistita in prefs.
  final Map<String, int> _lastBuildDurationByKey = {};

  /// Path dell'artefatto (APK o cartella IPA) dopo build riuscita, per chiave envName:platform.
  final Map<String, String> _lastBuiltArtifactPaths = {};

  /// Output console per buildKey (env:platform). In memoria e in cache (prefs).
  final Map<String, String> _consoleOutputByKey = {};
  final Map<String, ScrollController> _consoleScrollControllers = {};

  List<String> get _envs => _releaseEnvironmentNames(widget.info);
  bool get _hasIos => widget.info.platforms.contains(_platformIos);

  String _buildKey(String envName, String platform) => '$envName:$platform';
  bool _isRunning(String envName, String platform) => _runningBuilds.contains(_buildKey(envName, platform));
  int? _elapsedFor(String envName, String platform) => _elapsedSecondsByKey[_buildKey(envName, platform)];

  List<String> get _allBuildKeys {
    final keys = <String>[];
    for (final env in _envs) {
      keys.add(_buildKey(env, _platformAndroid));
      if (_hasIos) keys.add(_buildKey(env, _platformIos));
    }
    return keys;
  }

  @override
  void initState() {
    super.initState();
    _loadLastBuildDuration();
    _loadCachedConsoles();
    for (final k in _allBuildKeys) {
      _consoleScrollControllers[k] = ScrollController();
    }
  }

  @override
  void dispose() {
    _buildTimer?.cancel();
    for (final c in _consoleScrollControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _appendConsole(String buildKey, String text) {
    if (!mounted) return;
    setState(() => _consoleOutputByKey[buildKey] = (_consoleOutputByKey[buildKey] ?? '') + text);
    final controller = _consoleScrollControllers[buildKey];
    if (controller != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.hasClients) {
          controller.animateTo(
            controller.position.maxScrollExtent,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _clearConsoleFor(String buildKey) {
    setState(() => _consoleOutputByKey[buildKey] = '');
    _saveCachedConsoles();
  }

  Future<void> _loadCachedConsoles() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKeyConsoleOutputs);
    if (json == null) return;
    try {
      final top = jsonDecode(json) as Map<String, dynamic>?;
      final byKey = top?[widget.projectPath] as Map<String, dynamic>?;
      if (byKey == null) return;
      final map = <String, String>{};
      for (final e in byKey.entries) {
        if (e.value is String) map[e.key] = e.value as String;
      }
      if (mounted) setState(() => _consoleOutputByKey.addAll(map));
    } catch (_) {}
  }

  Future<void> _saveCachedConsoles() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKeyConsoleOutputs);
    final top = (json != null ? (jsonDecode(json) as Map<String, dynamic>?) : null) ?? <String, dynamic>{};
    final byKey = <String, dynamic>{};
    for (final e in _consoleOutputByKey.entries) {
      final s = e.value;
      if (s.isEmpty) continue;
      byKey[e.key] = s.length > _maxCachedConsoleChars ? s.substring(s.length - _maxCachedConsoleChars) : s;
    }
    top[widget.projectPath] = byKey;
    await prefs.setString(_prefsKeyConsoleOutputs, jsonEncode(top));
  }

  Future<void> _loadLastBuildDuration() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKeyLastBuildDurations);
    if (json == null) return;
    try {
      final top = jsonDecode(json) as Map<String, dynamic>?;
      final byKey = top?[widget.projectPath] as Map<String, dynamic>?;
      if (byKey == null) return;
      final map = <String, int>{};
      for (final e in byKey.entries) {
        final v = e.value;
        if (v is int) map[e.key] = v;
      }
      if (mounted) setState(() => _lastBuildDurationByKey.addAll(map));
    } catch (_) {}
  }

  void _startBuildTimer(String buildKey) {
    _buildStartTimes[buildKey] = DateTime.now();
    _elapsedSecondsByKey[buildKey] = 0;
    _buildTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      var changed = false;
      final now = DateTime.now();
      for (final key in _runningBuilds) {
        final start = _buildStartTimes[key];
        if (start != null) {
          final elapsed = now.difference(start).inSeconds;
          if (_elapsedSecondsByKey[key] != elapsed) {
            _elapsedSecondsByKey[key] = elapsed;
            changed = true;
          }
        }
      }
      if (changed) setState(() {});
    });
  }

  void _stopBuildTimer(String buildKey) {
    _buildStartTimes.remove(buildKey);
    _elapsedSecondsByKey.remove(buildKey);
    if (_runningBuilds.isEmpty) {
      _buildTimer?.cancel();
      _buildTimer = null;
    }
  }

  /// Persiste l'intera mappa _lastBuildDurationByKey per il progetto corrente (tutti i buildKey).
  Future<void> _saveAllLastBuildDurations() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKeyLastBuildDurations);
    final top = (json != null ? (jsonDecode(json) as Map<String, dynamic>?) : null) ?? <String, dynamic>{};
    final byKey = <String, dynamic>{};
    for (final e in _lastBuildDurationByKey.entries) {
      byKey[e.key] = e.value;
    }
    top[widget.projectPath] = byKey;
    await prefs.setString(_prefsKeyLastBuildDurations, jsonEncode(top));
  }

  Future<void> _runRelease(String envName, String platform) async {
    final buildKey = _buildKey(envName, platform);
    if (_runningBuilds.contains(buildKey)) return;

    final hasFlavors = widget.info.androidFlavors.isNotEmpty || widget.info.iosFlavors.isNotEmpty;
    final flavorArg = hasFlavors ? envName.toLowerCase() : null;
    List<String> args = platform == _platformIos ? ['build', 'ipa', '--release'] : ['build', 'apk', '--release'];
    if (flavorArg != null) args.addAll(['--flavor', flavorArg]);
    final executable = await _resolveFlutterExecutable(widget.projectPath);

    final String commandDisplay;
    if (executable == 'flutter') {
      commandDisplay = 'flutter ${args.join(' ')}';
    } else {
      commandDisplay = '$executable ${args.join(' ')}';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t(context, 'release.confirmTitle')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t(context, 'release.confirmMessage'), style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            SelectableText(
              commandDisplay,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${t(context, 'release.confirmCwd')}\n${widget.projectPath}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t(context, 'release.confirmCancel')),
          ),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: Text(t(context, 'release.confirmRun'))),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    setState(() {
      _runningBuilds.add(buildKey);
      _startBuildTimer(buildKey);
      _consoleOutputByKey[buildKey] = '';
    });
    final stopwatch = Stopwatch()..start();

    try {
      final Process process;
      if (executable == 'flutter') {
        if (Platform.isMacOS || Platform.isLinux) {
          final cmd = 'flutter ${args.map((a) => a.contains(' ') ? "'$a'" : a).join(' ')}';
          process = await Process.start(
            '/bin/zsh',
            ['-l', '-c', cmd],
            workingDirectory: widget.projectPath,
            runInShell: false,
          );
        } else {
          process = await Process.start('flutter', args, workingDirectory: widget.projectPath, runInShell: true);
        }
      } else {
        process = await Process.start(executable, args, workingDirectory: widget.projectPath, runInShell: false);
      }

      process.stdout.transform(utf8.decoder).listen((data) => _appendConsole(buildKey, data));
      process.stderr.transform(utf8.decoder).listen((data) => _appendConsole(buildKey, data));

      final exitCode = await process.exitCode;
      stopwatch.stop();
      final durationSeconds = stopwatch.elapsed.inSeconds;

      if (!mounted) return;
      setState(() => _runningBuilds.remove(buildKey));
      _stopBuildTimer(buildKey);

      if (exitCode == 0) {
        if (mounted)
          setState(() {
            _lastBuildDurationByKey[buildKey] = durationSeconds;
            _lastBuiltArtifactPaths[buildKey] = _builtArtifactPath(widget.projectPath, platform, flavorArg);
          });
        await _saveAllLastBuildDurations();
      }

      _appendConsole(
        buildKey,
        '\n${exitCode == 0 ? t(context, 'release.done') : t(context, 'release.error')} (exit $exitCode)\n',
      );
      await _saveCachedConsoles();

      final ok = exitCode == 0;
      final platformLabel = platform == _platformIos ? 'iOS' : 'Android';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? '${t(context, 'release.done')}: $envName ($platformLabel)'
                : '${t(context, 'release.error')}: $envName ($platformLabel)',
          ),
          backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700,
        ),
      );
    } catch (e) {
      stopwatch.stop();
      _appendConsole(buildKey, '\n${t(context, 'release.error')}: $e\n');
      await _saveCachedConsoles();
      if (mounted) {
        setState(() => _runningBuilds.remove(buildKey));
        _stopBuildTimer(buildKey);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${t(context, 'release.error')}: $e'), backgroundColor: Colors.red.shade700),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var sectionIndex = 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            t(context, 'release.tabDescription'),
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
        ..._envs.expand((env) {
          final card = _ReleaseEnvCard(
            envName: env,
            hasIos: _hasIos,
            isBuildingAndroid: _isRunning(env, _platformAndroid),
            isBuildingIos: _isRunning(env, _platformIos),
            elapsedSecondsAndroid: _elapsedFor(env, _platformAndroid),
            elapsedSecondsIos: _elapsedFor(env, _platformIos),
            lastBuildDurationSecondsAndroid: _lastBuildDurationByKey[_buildKey(env, _platformAndroid)],
            lastBuildDurationSecondsIos: _lastBuildDurationByKey[_buildKey(env, _platformIos)],
            androidArtifactPath: _lastBuiltArtifactPaths[_buildKey(env, _platformAndroid)],
            iosArtifactPath: _lastBuiltArtifactPaths[_buildKey(env, _platformIos)],
            onReleaseAndroid: () => _runRelease(env, _platformAndroid),
            onReleaseIos: () => _runRelease(env, _platformIos),
          );
          final wrapped = widget.sectionKeys != null && sectionIndex < widget.sectionKeys!.length
              ? KeyedSubtree(key: widget.sectionKeys![sectionIndex++], child: card)
              : card;
          final androidKey = _buildKey(env, _platformAndroid);
          final iosKey = _buildKey(env, _platformIos);
          final androidController = _consoleScrollControllers[androidKey];
          final iosController = _hasIos ? _consoleScrollControllers[iosKey] : null;
          final androidOutput = _consoleOutputByKey[androidKey] ?? '';
          final iosOutput = _consoleOutputByKey[iosKey] ?? '';
          final showAndroidConsole =
              androidController != null && (androidOutput.isNotEmpty || _runningBuilds.contains(androidKey));
          final showIosConsole = iosController != null && (iosOutput.isNotEmpty || _runningBuilds.contains(iosKey));
          return [
            Padding(padding: const EdgeInsets.only(bottom: 12), child: wrapped),
            if (showAndroidConsole)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _ReleaseConsole(
                  title: '$env · ${t(context, 'release.platformAndroid')}',
                  output: androidOutput,
                  scrollController: androidController,
                  isBuilding: _runningBuilds.contains(androidKey),
                  onClear: () => _clearConsoleFor(androidKey),
                ),
              ),
            if (showIosConsole)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _ReleaseConsole(
                  title: '$env · ${t(context, 'release.platformIos')}',
                  output: iosOutput,
                  scrollController: iosController,
                  isBuilding: _runningBuilds.contains(iosKey),
                  onClear: () => _clearConsoleFor(iosKey),
                ),
              ),
          ];
        }),
      ],
    );
  }
}

class _ReleaseEnvCard extends StatelessWidget {
  const _ReleaseEnvCard({
    required this.envName,
    required this.hasIos,
    required this.isBuildingAndroid,
    required this.isBuildingIos,
    this.elapsedSecondsAndroid,
    this.elapsedSecondsIos,
    this.lastBuildDurationSecondsAndroid,
    this.lastBuildDurationSecondsIos,
    this.androidArtifactPath,
    this.iosArtifactPath,
    required this.onReleaseAndroid,
    required this.onReleaseIos,
  });

  final String envName;
  final bool hasIos;
  final bool isBuildingAndroid;
  final bool isBuildingIos;
  final int? elapsedSecondsAndroid;
  final int? elapsedSecondsIos;
  final int? lastBuildDurationSecondsAndroid;
  final int? lastBuildDurationSecondsIos;
  final String? androidArtifactPath;
  final String? iosArtifactPath;
  final VoidCallback onReleaseAndroid;
  final VoidCallback onReleaseIos;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buildingAndroidLabel = isBuildingAndroid && elapsedSecondsAndroid != null
        ? t(context, 'release.buildingElapsed', translationParams: {'elapsed': _formatElapsed(elapsedSecondsAndroid!)})
        : t(context, 'release.building');
    final buildingIosLabel = isBuildingIos && elapsedSecondsIos != null
        ? t(context, 'release.buildingElapsed', translationParams: {'elapsed': _formatElapsed(elapsedSecondsIos!)})
        : t(context, 'release.building');
    final anyLoading = isBuildingAndroid || isBuildingIos;
    final hasDurationAndroid = lastBuildDurationSecondsAndroid != null && !anyLoading;
    final hasDurationIos = lastBuildDurationSecondsIos != null && !anyLoading;
    return FkExpandableSection(
      title: envName,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: const SizedBox.shrink(),
              ),
              FilledButton.icon(
                  onPressed: isBuildingAndroid ? null : onReleaseAndroid,
                  icon: isBuildingAndroid
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary),
                        )
                      : const Icon(Icons.android, size: 20),
                  label: Text(isBuildingAndroid ? buildingAndroidLabel : t(context, 'release.buildAndroid')),
                ),
                if (androidArtifactPath != null && !isBuildingAndroid) ...[
                  const SizedBox(width: 4),
                  IconButton.filledTonal(
                    onPressed: () async {
                      final opened = await revealInFinder(androidArtifactPath!);
                      if (context.mounted && !opened) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(t(context, 'release.artifactNotFound')),
                            backgroundColor: Colors.orange.shade700,
                          ),
                        );
                      }
                    },
                    icon: const Icon(CupertinoIcons.folder_fill, size: 20),
                    tooltip: t(context, 'release.showInFinder'),
                    style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
                  ),
                ],
                if (hasIos) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: isBuildingIos ? null : onReleaseIos,
                    icon: isBuildingIos
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.onPrimary),
                          )
                        : const Icon(CupertinoIcons.device_phone_portrait, size: 20),
                    label: Text(isBuildingIos ? buildingIosLabel : t(context, 'release.buildIos')),
                  ),
                  if (iosArtifactPath != null && !isBuildingIos) ...[
                    const SizedBox(width: 4),
                    IconButton.filledTonal(
                      onPressed: () async {
                        final opened = await revealInFinder(iosArtifactPath!);
                        if (context.mounted && !opened) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(t(context, 'release.artifactNotFound')),
                              backgroundColor: Colors.orange.shade700,
                            ),
                          );
                        }
                      },
                      icon: const Icon(CupertinoIcons.folder_fill, size: 20),
                      tooltip: t(context, 'release.showInFinder'),
                      style: IconButton.styleFrom(minimumSize: const Size(40, 40)),
                    ),
                  ],
                ],
              ],
            ),
          if (hasDurationAndroid || hasDurationIos)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 12,
                runSpacing: 2,
                children: [
                  if (hasDurationAndroid)
                    Text(
                      t(
                        context,
                        'release.lastBuildTimeWithPlatform',
                        translationParams: {
                          'platform': t(context, 'release.platformAndroid'),
                          'duration': _formatBuildDuration(lastBuildDurationSecondsAndroid!),
                        },
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  if (hasDurationIos)
                    Text(
                      t(
                        context,
                        'release.lastBuildTimeWithPlatform',
                        translationParams: {
                          'platform': t(context, 'release.platformIos'),
                          'duration': _formatBuildDuration(lastBuildDurationSecondsIos!),
                        },
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Mini console che mostra l'output del comando di build in tempo reale (una per buildKey).
class _ReleaseConsole extends StatelessWidget {
  const _ReleaseConsole({
    required this.title,
    required this.output,
    required this.scrollController,
    required this.isBuilding,
    required this.onClear,
  });

  final String title;
  final String output;
  final ScrollController scrollController;
  final bool isBuilding;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const consoleHeight = 220.0;
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFF2D2D2D);
    final textColor = isDark ? const Color(0xFFD4D4D4) : const Color(0xFFE0E0E0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (isBuilding)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
                ),
              ),
            if (!isBuilding && output.isNotEmpty)
              TextButton.icon(
                onPressed: onClear,
                icon: const Icon(CupertinoIcons.clear, size: 18),
                label: Text(t(context, 'release.consoleClear')),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: consoleHeight,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              output.isEmpty ? t(context, 'release.consolePlaceholder') : output,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                height: 1.4,
                color: output.isEmpty ? textColor.withOpacity(0.6) : textColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Tab "Signing": come viene firmata l'app su iOS e Android (code signing / signing config).
class _ProjectSigningTabBody extends StatelessWidget {
  const _ProjectSigningTabBody({required this.info, this.sectionKeys, this.highlightSectionIndex = -1});

  final FlutterProjectInfo info;
  final List<GlobalKey>? sectionKeys;
  final int highlightSectionIndex;

  Widget _wrapSection(BuildContext context, Widget child, int index) {
    Widget w = child;
    if (highlightSectionIndex == index) {
      w = Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        child: w,
      );
    }
    if (sectionKeys != null && index < sectionKeys!.length) {
      return KeyedSubtree(key: sectionKeys![index], child: w);
    }
    return w;
  }

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
    var sectionIndex = 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (hasIos) ...[
          _wrapSection(
            context,
            FkExpandableSection(
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
            sectionIndex++,
          ),
          const SizedBox(height: 12),
        ],
        if (hasAndroid) ...[
          _wrapSection(
            context,
            FkExpandableSection(
              title: t(context, 'projectInfo.signingAndroid'),
              children: androidEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(t(context, 'projectInfo.noSigningConfig')),
                      ),
                    ]
                  : [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          t(context, 'projectInfo.signingAndroidPropertiesHint'),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      ...(info.androidSigningSettings.keys.toList()..sort())
                          .map((k) => _InfoRow(label: k, value: info.androidSigningSettings[k]!)),
                    ],
            ),
            sectionIndex++,
          ),
        ],
      ],
    );
  }
}

/// Tab "App icons": icone app e splash screen per iOS e Android.
class _ProjectAppIconsTabBody extends StatelessWidget {
  const _ProjectAppIconsTabBody({required this.info, this.sectionKeys, this.highlightSectionIndex = -1});

  final FlutterProjectInfo info;
  final List<GlobalKey>? sectionKeys;
  final int highlightSectionIndex;

  Widget _wrapSection(BuildContext context, Widget child, int index) {
    Widget w = child;
    if (highlightSectionIndex == index) {
      w = Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        child: w,
      );
    }
    if (sectionKeys != null && index < sectionKeys!.length) {
      return KeyedSubtree(key: sectionKeys![index], child: w);
    }
    return w;
  }

  @override
  Widget build(BuildContext context) {
    final hasAnyIcon =
        info.iosAppIcons.isNotEmpty ||
        info.androidAppIcons.isNotEmpty ||
        info.iosAppIconPath != null ||
        info.androidAppIconPath != null;
    final hasAnySplash = info.iosSplashPath != null || info.androidSplashPath != null;
    final hasAssetsOrFonts = info.assets.isNotEmpty || info.fonts.isNotEmpty;
    if (!hasAnyIcon && !hasAnySplash && !hasAssetsOrFonts) {
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
    var sectionIndex = 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (hasAnyIcon || hasAnySplash) ...[
        _wrapSection(
          context,
          FkExpandableSection(
            title: t(context, 'projectInfo.appIcons'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (info.iosAppIcons.isNotEmpty) ...[
                    Text(
                      t(context, 'projectInfo.iosIcon'),
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: info.iosAppIcons
                          .map(
                            (e) => _AppIconTile(
                              platformLabel: e.label,
                              iconPath: e.path,
                              iconData: CupertinoIcons.device_phone_portrait,
                              isMain: e.isMain,
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ] else if (info.iosAppIconPath != null) ...[
                    Text(
                      t(context, 'projectInfo.iosIcon'),
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    _AppIconTile(
                      platformLabel: t(context, 'projectInfo.iosIcon'),
                      iconPath: info.iosAppIconPath,
                      iconData: CupertinoIcons.device_phone_portrait,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (info.androidAppIcons.isNotEmpty) ...[
                    Text(
                      t(context, 'projectInfo.androidIcon'),
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: info.androidAppIcons
                          .map(
                            (e) => _AppIconTile(
                              platformLabel: e.label,
                              iconPath: e.path,
                              iconData: Icons.android,
                              isMain: e.isMain,
                            ),
                          )
                          .toList(),
                    ),
                  ] else if (info.androidAppIconPath != null) ...[
                    Text(
                      t(context, 'projectInfo.androidIcon'),
                      style: Theme.of(
                        context,
                      ).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 8),
                    _AppIconTile(
                      platformLabel: t(context, 'projectInfo.androidIcon'),
                      iconPath: info.androidAppIconPath,
                      iconData: Icons.android,
                    ),
                  ],
                ],
              ),
            ),
          ),
          sectionIndex++,
        ),
        const SizedBox(height: 12),
        _wrapSection(
          context,
          FkExpandableSection(
            title: t(context, 'projectInfo.splashScreen'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: _AppIconTile(
                      platformLabel: t(context, 'projectInfo.iosIcon'),
                      iconPath: info.iosSplashPath,
                      iconData: CupertinoIcons.device_phone_portrait,
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
          sectionIndex++,
        ),
        ],
        const SizedBox(height: 12),
        _wrapSection(
          context,
          FkExpandableSection(
            title: t(context, 'projectInfo.assetsSection'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAssetsSectionWidget(context, info),
                const SizedBox(height: 16),
                _buildFontsSectionWidget(context, info),
              ],
            ),
          ),
          sectionIndex++,
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
        leading: IconButton(icon: const Icon(CupertinoIcons.back), onPressed: () => Navigator.of(context).pop()),
      ),
      body: ProjectInfoPanel(projectPath: projectPath, tabIndex: 0),
    );
  }
}

class _AppIconTile extends StatelessWidget {
  const _AppIconTile({
    required this.platformLabel,
    required this.iconPath,
    required this.iconData,
    this.size = 80,
    this.isMain = false,
  });

  final String platformLabel;
  final String? iconPath;
  final IconData iconData;
  final double size;
  final bool isMain;

  @override
  Widget build(BuildContext context) {
    final hasPath = iconPath != null && File(iconPath!).existsSync();
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(platformLabel, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isMain ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                  width: isMain ? 2.5 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasPath
                  ? Image.file(File(iconPath!), fit: BoxFit.contain)
                  : Icon(iconData, size: size * 0.5, color: theme.colorScheme.onSurfaceVariant),
            ),
            if (isMain)
              Positioned(
                top: -6,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.shadow.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    t(context, 'projectInfo.mainIcon'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (hasPath && iconPath != null) ...[
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => revealInFinder(iconPath!),
            icon: const Icon(CupertinoIcons.folder_fill, size: 18),
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
