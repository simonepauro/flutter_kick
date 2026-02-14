import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_i18n/loaders/decoders/json_decode_strategy.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_kick/features/tabs/screens/tab_shell_screen.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

/// Colori e tema ispirati alle Human Interface Guidelines Apple (macOS / Xcode).
class _MacOSTheme {
  _MacOSTheme._();

  // System colors (Apple HIG)
  static const Color systemGray6 = Color(0xFFF2F2F7);   // Content background
  static const Color systemGray5 = Color(0xFFE5E5EA);   // Toolbar / tab bar
  static const Color systemGray4 = Color(0xFFD1D1D6);   // Borders
  static const Color systemGray = Color(0xFF8E8E93);    // Secondary text
  static const Color systemBlue = Color(0xFF007AFF);    // Accent
  static const Color white = Color(0xFFFFFFFF);
  static const Color labelPrimary = Color(0xFF000000);
  static const Color labelSecondary = Color(0xFF3C3C43); // 60% opacity black
  static const Color fillSecondary = Color(0xFFEBEBF0);

  static ColorScheme get colorScheme {
    return ColorScheme.light(
      primary: systemBlue,
      onPrimary: white,
      primaryContainer: const Color(0xFFD6E7FF),
      onPrimaryContainer: const Color(0xFF001D36),
      secondary: systemGray,
      onSecondary: white,
      surface: white,
      onSurface: labelPrimary,
      onSurfaceVariant: labelSecondary,
      outline: systemGray4,
      outlineVariant: systemGray5,
      surfaceContainerHighest: fillSecondary,
      surfaceContainerHigh: systemGray6,
      error: const Color(0xFFFF3B30),
      onError: white,
      inverseSurface: systemGray,
      onInverseSurface: white,
    );
  }

  static ThemeData get themeData {
    final scheme = colorScheme;
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      // Per un look ancora più “di sistema” su macOS puoi aggiungere il font SF Pro in pubspec.
      fontFamily: null,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: systemGray6,
        foregroundColor: labelPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: labelPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: systemGray4, width: 0.5),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: systemGray4),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: const BorderSide(color: systemBlue, width: 1.5),
        ),
        hintStyle: TextStyle(color: systemGray, fontSize: 13),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return white;
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return labelPrimary;
            return labelSecondary;
          }),
          side: WidgetStateProperty.all(const BorderSide(color: systemGray4)),
          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))),
          elevation: WidgetStateProperty.all(0),
          shadowColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: fillSecondary,
        side: const BorderSide(color: systemGray4, width: 0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        labelStyle: const TextStyle(fontSize: 12),
      ),
      dividerTheme: const DividerThemeData(color: systemGray4, thickness: 0.5, space: 1),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: labelPrimary,
          minimumSize: const Size(28, 28),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentTextStyle: const TextStyle(color: white),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Kick',
      theme: _MacOSTheme.themeData,
      localizationsDelegates: [
        FlutterI18nDelegate(
          translationLoader: FileTranslationLoader(
            basePath: 'assets/i18n',
            fallbackFile: 'en',
            decodeStrategies: [JsonDecodeStrategy()],
          ),
        ),
        ...GlobalMaterialLocalizations.delegates,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('it', 'IT'), Locale('en', 'US')],
      home: const TabShellScreen(),
    );
  }
}
