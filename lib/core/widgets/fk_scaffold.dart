import 'package:flutter/material.dart';

/// Scaffold custom con sfondo applicato. Espone le stesse proprietà principali
/// di [Scaffold] e disegna l'immagine di sfondo sotto il contenuto.
class FKScaffold extends StatelessWidget {
  const FKScaffold({
    super.key,
    this.appBar,
    this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.drawer,
    this.endDrawer,
    this.backgroundColor,
    this.resizeToAvoidBottomInset,
  });

  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final Widget? endDrawer;
  final Color? backgroundColor;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Sfondo stile macOS (System Gray 6 - Apple HIG)
        Container(decoration: const BoxDecoration(color: Color(0xFFF2F2F7))),
        Scaffold(
          backgroundColor: backgroundColor ?? Colors.transparent,
          resizeToAvoidBottomInset: resizeToAvoidBottomInset,
          appBar: appBar,
          body: body,
          floatingActionButton: floatingActionButton,
          floatingActionButtonLocation: floatingActionButtonLocation,
          bottomNavigationBar: bottomNavigationBar,
          drawer: drawer,
          endDrawer: endDrawer,
        ),
      ],
    );
  }
}
