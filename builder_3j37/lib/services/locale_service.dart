import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService extends ChangeNotifier {
  static const String _prefKey = 'selected_locale';
  Locale _locale = const Locale('en', 'US');
  
  Locale get locale => _locale;
  bool get isChinese => _locale.languageCode == 'zh';
  
  LocaleService() {
    _loadLocale();
  }
  
  Future<void> _loadLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localeCode = prefs.getString(_prefKey) ?? 'en_US';
      final parts = localeCode.split('_');
      _locale = Locale(parts[0], parts.length > 1 ? parts[1] : '');
      debugPrint('[LocaleService] Loaded locale: $_locale');
      notifyListeners();
    } catch (e) {
      debugPrint('[LocaleService] Error loading locale: $e');
    }
  }
  
  Future<void> setLocale(Locale locale) async {
    debugPrint('[LocaleService] Setting locale: ${locale.languageCode}_${locale.countryCode}');
    _locale = locale;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, '${locale.languageCode}_${locale.countryCode}');
      debugPrint('[LocaleService] Locale saved to preferences');
    } catch (e) {
      debugPrint('[LocaleService] Error saving locale: $e');
    }
  }
  
  Future<void> toggleLocale() async {
    if (isChinese) {
      await setLocale(const Locale('en', 'US'));
    } else {
      await setLocale(const Locale('zh', 'CN'));
    }
  }
}
