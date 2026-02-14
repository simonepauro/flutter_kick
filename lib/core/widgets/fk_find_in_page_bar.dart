import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Barra di ricerca stile browser (Cmd+F): campo di ricerca, precedente/successivo, conteggio, chiudi.
class FKFindInPageBar extends StatefulWidget {
  const FKFindInPageBar({
    super.key,
    required this.query,
    required this.onQueryChanged,
    required this.matchIndex,
    required this.matchCount,
    required this.onPrevious,
    required this.onNext,
    required this.onClose,
    this.hintText,
    this.previousTooltip,
    this.nextTooltip,
    this.closeTooltip,
    this.noResultsLabel,
  });

  final String query;
  final ValueChanged<String> onQueryChanged;
  final int matchIndex;
  final int matchCount;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onClose;
  final String? hintText;
  final String? previousTooltip;
  final String? nextTooltip;
  final String? closeTooltip;
  final String? noResultsLabel;

  @override
  State<FKFindInPageBar> createState() => _FKFindInPageBarState();
}

class _FKFindInPageBarState extends State<FKFindInPageBar> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant FKFindInPageBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query && _controller.text != widget.query) {
      _controller.text = widget.query;
      _controller.selection = TextSelection.collapsed(offset: widget.query.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surface = isDark ? theme.colorScheme.surfaceContainerHigh : theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outline;

    return Material(
      elevation: 2,
      color: surface,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderColor, width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: widget.hintText ?? 'Find',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                ),
                onChanged: widget.onQueryChanged,
                textInputAction: TextInputAction.search,
              ),
            ),
            const SizedBox(width: 8),
            _CountLabel(
              matchIndex: widget.matchIndex,
              matchCount: widget.matchCount,
              noResultsLabel: widget.noResultsLabel,
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: widget.matchCount > 0 ? widget.onPrevious : null,
              tooltip: widget.previousTooltip ?? 'Previous',
              style: IconButton.styleFrom(minimumSize: const Size(36, 36)),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: widget.matchCount > 0 ? widget.onNext : null,
              tooltip: widget.nextTooltip ?? 'Next',
              style: IconButton.styleFrom(minimumSize: const Size(36, 36)),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: widget.onClose,
              tooltip: widget.closeTooltip ?? 'Close (Esc)',
              style: IconButton.styleFrom(minimumSize: const Size(36, 36)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountLabel extends StatelessWidget {
  const _CountLabel({required this.matchIndex, required this.matchCount, this.noResultsLabel});

  final int matchIndex;
  final int matchCount;
  final String? noResultsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final text = matchCount == 0 && matchIndex == 0 ? (noResultsLabel ?? 'No results') : '$matchIndex of $matchCount';
    return SizedBox(
      width: 64,
      child: Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
    );
  }
}
