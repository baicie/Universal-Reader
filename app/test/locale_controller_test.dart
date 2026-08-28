import 'package:app/core/locale_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults to Chinese', () {
    expect(resolveAppLocale(null), const Locale('zh'));
    expect(resolveAppLocale(const [Locale('en')]), const Locale('zh'));
    expect(LocaleController().overrideLocale, const Locale('zh'));
  });

  test('setLanguage updates the override locale', () async {
    final controller = LocaleController();
    await controller.setLanguage(AppLanguage.en);
    expect(controller.overrideLocale, const Locale('en'));
    await controller.setLanguage(AppLanguage.system);
    expect(controller.overrideLocale, isNull);
  });

  test('load restores a saved language', () async {
    SharedPreferences.setMockInitialValues({LocaleController.storageKey: 'en'});
    final preferences = await SharedPreferences.getInstance();
    final controller = LocaleController(preferences);
    await controller.load();
    expect(controller.language, AppLanguage.en);
  });

  test('explicit English wins over the device locale', () {
    expect(
      resolveAppLocale(const [Locale('zh')], preference: AppLanguage.en),
      const Locale('en'),
    );
  });

  test('system mode follows the first supported device language', () {
    expect(
      resolveAppLocale(const [
        Locale('en'),
        Locale('zh'),
      ], preference: AppLanguage.system),
      const Locale('en'),
    );
    expect(
      resolveAppLocale(const [Locale('ja')], preference: AppLanguage.system),
      const Locale('zh'),
    );
  });
}
