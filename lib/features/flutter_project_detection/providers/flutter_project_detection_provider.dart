import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/flutter_project_result.dart';
import '../services/flutter_project_detector_service.dart';

final flutterProjectDetectionProvider = FutureProvider.autoDispose
    .family<FlutterProjectResult, String>((
  Ref ref,
  String path,
) async {
  if (path.trim().isEmpty) {
    return const FlutterProjectResult(
      path: '',
      isFlutterProject: false,
    );
  }
  final service = FlutterProjectDetectorService();
  return service.detect(path);
});
