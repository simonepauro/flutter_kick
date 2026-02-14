import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dependency_info.dart';
import '../models/flutter_project_info.dart';
import '../services/dependency_status_service.dart';
import '../services/project_info_service.dart';

final projectInfoProvider = FutureProvider.autoDispose
    .family<FlutterProjectInfo, String>((Ref ref, String projectPath) async {
  if (projectPath.trim().isEmpty) {
    throw ArgumentError('projectPath non può essere vuoto');
  }
  final service = ProjectInfoService();
  return service.load(projectPath);
});

/// Stato aggiornamenti/deprecazioni delle dipendenze (verifica in background).
final dependencyStatusProvider = FutureProvider.autoDispose
    .family<DependencyStatusInfo, String>((Ref ref, String projectPath) async {
  final info = await ref.watch(projectInfoProvider(projectPath).future);
  final allNames = [
    ...info.dependencies.map((d) => d.name),
    ...info.devDependencies.map((d) => d.name),
  ];
  final service = DependencyStatusService();
  return service.check(projectPath, directPackageNames: allNames);
});
