import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Larghezza sotto la quale i segmenti non ci stanno e si usa il menu a tendina.
const double _kBreakpointWidth = 480;

/// Voce per [FkAdaptiveTabSelector].
typedef FkTabSegment = ({int value, String label, IconData icon});

/// Selettore tab: [SegmentedButton] quando c'è spazio, menu a tendina altrimenti.
class FkAdaptiveTabSelector extends StatelessWidget {
  const FkAdaptiveTabSelector({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
    this.iconSize = 24.0,
  });

  final List<FkTabSegment> segments;
  final int selected;
  final ValueChanged<int> onSelectionChanged;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useDropdown = constraints.maxWidth < _kBreakpointWidth;
        if (useDropdown) {
          return _DropdownTabSelector(
            segments: segments,
            selected: selected,
            onSelectionChanged: onSelectionChanged,
            iconSize: iconSize,
            minWidth: constraints.maxWidth,
          );
        }
        return SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            for (final s in segments)
              ButtonSegment<int>(
                value: s.value,
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        s.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                icon: Icon(s.icon, size: iconSize),
              ),
          ],
          selected: {selected},
          onSelectionChanged: (Set<int> sel) {
            if (sel.isNotEmpty) onSelectionChanged(sel.first);
          },
        );
      },
    );
  }
}

class _DropdownTabSelector extends StatelessWidget {
  const _DropdownTabSelector({
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
    required this.iconSize,
    this.minWidth = double.infinity,
  });

  final List<FkTabSegment> segments;
  final int selected;
  final ValueChanged<int> onSelectionChanged;
  final double iconSize;
  final double minWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final segment = segments.firstWhere(
      (s) => s.value == selected,
      orElse: () => segments.first,
    );
    return PopupMenuButton<int>(
      tooltip: MaterialLocalizations.of(context).showMenuTooltip,
      onSelected: onSelectionChanged,
      itemBuilder: (context) => [
        for (final s in segments)
          PopupMenuItem<int>(
            value: s.value,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(s.icon, size: iconSize),
                const SizedBox(width: 12),
                Text(s.label),
              ],
            ),
          ),
      ],
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.colorScheme.outline.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(segment.icon, size: iconSize, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  segment.label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(CupertinoIcons.chevron_down, size: 16, color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
