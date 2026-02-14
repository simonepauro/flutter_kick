import 'package:flutter/material.dart';

import 'package:flutter_kick/core/l10n/translation.dart';

class SelectProjectPathField extends StatelessWidget {
  const SelectProjectPathField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.path,
    this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String path;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      decoration: InputDecoration(
        hintText: t(context, 'selectProject.pathFieldHint'),
        border: const OutlineInputBorder(),
        prefixIcon: const Icon(Icons.folder_outlined),
        suffixIcon: path.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: onClear) : null,
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}
