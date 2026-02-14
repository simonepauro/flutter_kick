import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/translation.dart';

/// Mostra un messaggio di errore all'utente in modo sempre copiabile:
/// testo selezionabile e pulsante per copiare negli appunti.
class FKCopyableError extends StatelessWidget {
  const FKCopyableError({
    super.key,
    required this.message,
    this.title,
    this.iconSize = 48,
    this.actions = const [],
    this.compact = false,
  });

  /// Messaggio di errore (sempre selezionabile e copiabile).
  final String message;

  /// Titolo opzionale sopra il messaggio.
  final String? title;

  /// Dimensione dell'icona di errore (ignorata se [compact] è true).
  final double iconSize;

  /// Azioni opzionali sotto il messaggio (es. pulsante Indietro).
  final List<Widget> actions;

  /// Se true, layout compatto (solo messaggio + icona copia, senza icona errore grande).
  final bool compact;

  Future<void> _copyToClipboard(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: message));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t(context, 'common.copied')), behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;

    if (compact) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SelectableText(message, style: TextStyle(color: errorColor, fontSize: 13)),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(CupertinoIcons.doc_on_doc, size: 18, color: errorColor),
              onPressed: () => _copyToClipboard(context),
              tooltip: t(context, 'common.copy'),
              style: IconButton.styleFrom(
                minimumSize: const Size(32, 32),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(CupertinoIcons.exclamationmark_circle, size: iconSize, color: errorColor),
            if (title != null) ...[
              const SizedBox(height: 16),
              Text(title!, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            ],
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SelectableText(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(color: errorColor),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(CupertinoIcons.doc_on_doc, color: errorColor),
                  onPressed: () => _copyToClipboard(context),
                  tooltip: t(context, 'common.copy'),
                ),
              ],
            ),
            if (actions.isNotEmpty) ...[const SizedBox(height: 24), ...actions],
          ],
        ),
      ),
    );
  }
}
