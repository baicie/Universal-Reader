import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { zh, en, system }

class LocaleController extends ChangeNotifier {
  LocaleController([this.preferences]);

  static const storageKey = 'universal_reader.language.v1';

  final SharedPreferences? preferences;
  AppLanguage language = AppLanguage.zh;

  Locale? get overrideLocale => switch (language) {
    AppLanguage.zh => const Locale('zh'),
    AppLanguage.en => const Locale('en'),
    AppLanguage.system => null,
  };

  Future<void> load() async {
    final raw = preferences?.getString(storageKey);
    language = AppLanguage.values.firstWhere(
      (value) => value.name == raw,
      orElse: () => AppLanguage.zh,
    );
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage value) async {
    language = value;
    await preferences?.setString(storageKey, value.name);
    notifyListeners();
  }
}

Locale resolveAppLocale(
  List<Locale>? deviceLocales, {
  AppLanguage preference = AppLanguage.zh,
}) {
  if (preference == AppLanguage.zh) return const Locale('zh');
  if (preference == AppLanguage.en) return const Locale('en');
  if (deviceLocales != null) {
    for (final locale in deviceLocales) {
      if (locale.languageCode == 'zh' || locale.languageCode == 'en') {
        return Locale(locale.languageCode);
      }
    }
  }
  return const Locale('zh');
}
