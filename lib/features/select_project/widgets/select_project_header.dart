import 'package:flutter/material.dart';

import 'package:flutter_kick/core/l10n/translation.dart';

class SelectProjectHeader extends StatelessWidget {
  const SelectProjectHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(t(context, 'selectProject.projectPathLabel'), style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          t(context, 'selectProject.projectPathHint'),
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
