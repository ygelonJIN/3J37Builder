import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/locale_service.dart';
import '../services/translations.dart';

extension BuildContextExtensions on BuildContext {
  LocaleService get localeService => read<LocaleService>();

  /// Get translated string. Uses read (not watch) so it can be called
  /// from both build methods AND event handlers (onTap, etc).
  String tr(String key) {
    final locale = read<LocaleService>().locale;
    final languageCode = locale.languageCode;
    return Translations.get(key, languageCode);
  }
}
