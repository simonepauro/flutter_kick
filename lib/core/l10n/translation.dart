import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';

/// Restituisce la stringa tradotta per [key].
/// Usa [translationParams] per sostituire placeholder tipo {name}, {count}.
String t(BuildContext context, String key, {Map<String, String>? translationParams, String? fallbackKey}) {
  return FlutterI18n.translate(context, key, translationParams: translationParams, fallbackKey: fallbackKey);
}
