import 'package:app/core/reader_prefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('clamps font size to the supported range', () {
    expect(clampFontSize(10), ReaderPrefsController.minFontSize);
    expect(clampFontSize(40), ReaderPrefsController.maxFontSize);
    expect(clampFontSize(18.4), 18);
  });

  test('load restores a saved font size', () async {
    SharedPreferences.setMockInitialValues({
      ReaderPrefsController.storageKey: 22.0,
    });
    final preferences = await SharedPreferences.getInstance();
    final prefs = ReaderPrefsController(preferences);
    await prefs.load();
    expect(prefs.fontSize, 22);
  });

  test('setFontSize persists the clamped value', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final prefs = ReaderPrefsController(preferences);
    await prefs.setFontSize(25.6);
    expect(prefs.fontSize, 26);
    expect(preferences.getDouble(ReaderPrefsController.storageKey), 26);
  });
}
