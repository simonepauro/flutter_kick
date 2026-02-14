import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Sezione espandibile in stile Xcode: header con triangolo di disclosure e contenuto collassabile.
/// Il header ha sfondo grigio e chevron; il contenuto è mostrato solo quando [expanded] è true.
class FkExpandableSection extends StatefulWidget {
  FkExpandableSection({
    super.key,
    required this.title,
    this.initialExpanded = true,
    List<Widget>? children,
    this.child,
    this.headerTrailing,
  })  : children = children ?? const <Widget>[],
        assert(children == null || children.isEmpty || child == null);

  final String title;
  final bool initialExpanded;
  final List<Widget> children;
  final Widget? child;
  /// Widget aggiuntivo nella header (es. pulsanti), mostrato prima del chevron.
  final Widget? headerTrailing;

  @override
  State<FkExpandableSection> createState() => _FkExpandableSectionState();
}

class _FkExpandableSectionState extends State<FkExpandableSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initialExpanded;
  }

  @override
  void didUpdateWidget(FkExpandableSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialExpanded != widget.initialExpanded) {
      _expanded = widget.initialExpanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final headerBg = isDark
        ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.6)
        : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5);
    final borderColor = theme.colorScheme.outline.withOpacity(0.25);
    final borderRadius = BorderRadius.circular(8);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: headerBg,
            child: InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Icon(
                      _expanded ? CupertinoIcons.chevron_down : CupertinoIcons.chevron_right,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (widget.headerTrailing != null) ...[
                      widget.headerTrailing!,
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: widget.child != null
                    ? [widget.child!]
                    : List.from(widget.children),
              ),
            ),
        ],
      ),
    );
  }
}
