import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/locale_service.dart';
import '../services/translations.dart';

extension BuildContextExtensions on BuildContext {
  LocaleService get localeService => read<LocaleService>();

  /// Get translated string. Uses watch to auto-rebuild on locale change.
  String tr(String key) {
    final locale = watch<LocaleService>().locale;
    final languageCode = locale.languageCode;
    return Translations.get(key, languageCode);
  }
}
