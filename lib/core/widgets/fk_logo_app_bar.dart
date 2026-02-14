import 'package:flutter/material.dart';

import '../constants/assets.dart';

/// AppBar con logo Flutter Kick. Sfondo trasparente per uso su FKScaffold.
class FKLogoAppBar extends StatelessWidget implements PreferredSizeWidget {
  const FKLogoAppBar({super.key, this.title});

  final String? title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      shadowColor: Colors.transparent,
      animateColor: false,
      surfaceTintColor: Colors.transparent,
      backgroundColor: Colors.transparent,
      title: Image.asset(Assets.flutterKickLogo, height: kToolbarHeight, fit: BoxFit.contain),
    );
  }
}
