import 'package:flutter/material.dart';

/// Segment item for [FkPixelSegmentedControl].
class FkPixelSegment<T> {
  const FkPixelSegment({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

/// Segmented control in pixel / retro style: blocky borders, no rounded corners,
/// chunky selected state with a simple 3D effect.
class FkPixelSegmentedControl<T> extends StatelessWidget {
  const FkPixelSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelected,
    this.pixelSize = 4,
  });

  final List<FkPixelSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onSelected;
  /// Base unit for borders and padding (multiples give the pixel look).
  final int pixelSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final p = pixelSize.toDouble();

    // Pixel-style colors: dark outline, light highlight, flat fill
    final outline = colorScheme.outline.withOpacity(0.9);
    final outlineDark = Color.lerp(outline, Colors.black, 0.3) ?? outline;
    final surface = colorScheme.surfaceContainerHighest;
    final selectedBg = colorScheme.primary;
    final selectedFg = colorScheme.onPrimary;
    final unselectedFg = colorScheme.onSurface;

    return Container(
      decoration: BoxDecoration(
        color: outline,
        border: Border.all(color: outlineDark, width: 2),
      ),
      child: Row(
        children: List.generate(segments.length * 2 - 1, (index) {
          if (index.isOdd) {
            return Container(
              width: p,
              color: outlineDark,
            );
          }
          final i = index ~/ 2;
          final segment = segments[i];
          final isSelected = segment.value == selected;
          return Expanded(
            child: _PixelSegmentTile(
              pixelSize: p,
              label: segment.label,
              icon: segment.icon,
              isSelected: isSelected,
              outline: outline,
              outlineDark: outlineDark,
              surface: surface,
              selectedBg: selectedBg,
              selectedFg: selectedFg,
              unselectedFg: unselectedFg,
              onTap: () => onSelected(segment.value),
            ),
          );
        }),
      ),
    );
  }
}

class _PixelSegmentTile extends StatelessWidget {
  const _PixelSegmentTile({
    required this.pixelSize,
    required this.label,
    this.icon,
    required this.isSelected,
    required this.outline,
    required this.outlineDark,
    required this.surface,
    required this.selectedBg,
    required this.selectedFg,
    required this.unselectedFg,
    required this.onTap,
  });

  final double pixelSize;
  final String label;
  final IconData? icon;
  final bool isSelected;
  final Color outline;
  final Color outlineDark;
  final Color surface;
  final Color selectedBg;
  final Color selectedFg;
  final Color unselectedFg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = pixelSize;
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: selectedFg.withOpacity(0.2),
        highlightColor: selectedFg.withOpacity(0.1),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: p * 2, vertical: p * 2.5),
          decoration: BoxDecoration(
            color: isSelected ? selectedBg : surface,
            border: Border(
              top: BorderSide(color: outlineDark, width: 1),
              left: BorderSide(color: outlineDark, width: 1),
              right: BorderSide(color: outline.withOpacity(0.6), width: 1),
              bottom: BorderSide(color: outline.withOpacity(0.6), width: 1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? selectedFg : unselectedFg,
                ),
                SizedBox(width: p),
              ],
              Flexible(
                child: Text(
                  label,
                  style: textStyle?.copyWith(
                    color: isSelected ? selectedFg : unselectedFg,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
