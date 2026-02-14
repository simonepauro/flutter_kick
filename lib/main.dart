import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:flutter_i18n/loaders/decoders/json_decode_strategy.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_kick/features/select_project/screens/select_project_screen.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static ColorScheme get _businessColorScheme {
    const primary = Color(0xFF1e3a5f);      // Navy
    const onPrimary = Color(0xFFf1f5f9);
    const primaryContainer = Color(0xFFe2e8f0);
    const onPrimaryContainer = Color(0xFF0f172a);
    const secondary = Color(0xFF475569);    // Slate
    const onSecondary = Color(0xFFf8fafc);
    const surface = Color(0xFFf8fafc);
    const onSurface = Color(0xFF1e293b);
    const surfaceContainerHighest = Color(0xFFe2e8f0);
    const outline = Color(0xFF94a3b8);
    const outlineVariant = Color(0xFFcbd5e1);
    return ColorScheme.light(
      primary: primary,
      onPrimary: onPrimary,
      primaryContainer: primaryContainer,
      onPrimaryContainer: onPrimaryContainer,
      secondary: secondary,
      onSecondary: onSecondary,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: Color(0xFF64748b),
      outline: outline,
      outlineVariant: outlineVariant,
      surfaceContainerHighest: surfaceContainerHighest,
      error: const Color(0xFFb91c1c),
      onError: const Color(0xFFfef2f2),
      inverseSurface: const Color(0xFF334155),
      onInverseSurface: const Color(0xFFf1f5f9),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Kick',
      theme: ThemeData(
        colorScheme: _businessColorScheme,
        useMaterial3: true,
      ),
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
      home: const SelectProjectScreen(),
    );
  }
}
