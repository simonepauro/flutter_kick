import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_kick/core/l10n/translation.dart';
import 'package:flutter_kick/features/select_project/constants/select_project_constants.dart';

class SelectProjectDropZone extends StatelessWidget {
  const SelectProjectDropZone({
    super.key,
    required this.isDragging,
    required this.onDragEntered,
    required this.onDragExited,
    required this.onDropDone,
  });

  final bool isDragging;
  final VoidCallback onDragEntered;
  final VoidCallback onDragExited;
  final void Function(DropDoneDetails) onDropDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DropTarget(
      onDragDone: onDropDone,
      onDragEntered: (_) => onDragEntered(),
      onDragExited: (_) => onDragExited(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: kSelectProjectDropZoneAnimationMs),
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          color: _dropZoneBackgroundColor(colorScheme),
          borderRadius: BorderRadius.circular(kSelectProjectDropZoneBorderRadius),
          border: Border.all(color: _dropZoneBorderColor(colorScheme), width: isDragging ? 2 : 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isDragging ? Icons.folder_open : Icons.folder,
              size: kSelectProjectDropZoneIconSize,
              color: _dropZoneIconColor(colorScheme),
            ),
            const SizedBox(height: 12),
            Text(
              isDragging ? t(context, 'selectProject.dropHere') : t(context, 'selectProject.dragHere'),
              style: theme.textTheme.bodyLarge?.copyWith(color: _dropZoneIconColor(colorScheme)),
            ),
          ],
        ),
      ),
    );
  }

  Color _dropZoneBackgroundColor(ColorScheme colorScheme) {
    return isDragging
        ? colorScheme.primaryContainer.withAlpha(153)
        : colorScheme.surfaceContainerHighest.withAlpha(128);
  }

  Color _dropZoneBorderColor(ColorScheme colorScheme) {
    return isDragging ? colorScheme.primary : colorScheme.outline.withAlpha(128);
  }

  Color _dropZoneIconColor(ColorScheme colorScheme) {
    return isDragging ? colorScheme.primary : colorScheme.onSurfaceVariant.withAlpha(179);
  }
}
