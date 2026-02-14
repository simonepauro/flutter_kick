import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter_kick/core/l10n/translation.dart';
import 'package:flutter_kick/core/widgets/fk_copyable_error.dart';

import '../providers/flutter_project_detection_provider.dart';

/// Mostra se il percorso inserito è un progetto Flutter (caricamento, ok, errore).
class FKProjectDetectionStatus extends ConsumerWidget {
  const FKProjectDetectionStatus({super.key, required this.projectPath});

  final String projectPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncResult = ref.watch(flutterProjectDetectionProvider(projectPath));

    return asyncResult.when(
      data: (result) {
        if (result.path.isEmpty) {
          return const SizedBox.shrink();
        }
        if (result.isFlutterProject) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.checkmark_circle_fill, color: Theme.of(context).colorScheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  t(context, 'detection.flutterProject'),
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(CupertinoIcons.exclamationmark_triangle_fill, color: Theme.of(context).colorScheme.error, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  result.errorMessageKey != null
                      ? t(context, result.errorMessageKey!, translationParams: result.errorMessageParams)
                      : (result.errorMessage ?? t(context, 'detection.notFlutterProject')),
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 13),
                ),
              ),
            ],
          ),
        );
      },
      loading: () {
        if (projectPath.trim().isEmpty) return const SizedBox.shrink();
        return const Padding(
          padding: EdgeInsets.only(top: 8),
          child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        );
      },
      error: (err, _) => FKCopyableError(
        compact: true,
        message: t(context, 'detection.error', translationParams: {'message': err.toString()}),
      ),
    );
  }
}
