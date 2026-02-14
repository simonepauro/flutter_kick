import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:flutter_kick/core/l10n/translation.dart';

class SelectProjectUseButton extends StatelessWidget {
  const SelectProjectUseButton({super.key, required this.path, required this.onPressed});

  final String path;
  final ValueChanged<String> onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: path.isEmpty ? null : () => onPressed(path),
      icon: const Icon(CupertinoIcons.arrow_right),
      label: Text(t(context, 'selectProject.useProject')),
    );
  }
}
