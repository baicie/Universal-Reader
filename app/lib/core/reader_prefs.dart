import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReaderPrefsController extends ChangeNotifier {
  ReaderPrefsController([this.preferences]);

  static const storageKey = 'universal_reader.reader.font_size.v1';
  static const minFontSize = 14.0;
  static const maxFontSize = 28.0;
  static const defaultFontSize = 18.0;

  final SharedPreferences? preferences;
  double fontSize = defaultFontSize;

  Future<void> load() async {
    fontSize = clampFontSize(
      preferences?.getDouble(storageKey) ?? defaultFontSize,
    );
    notifyListeners();
  }

  Future<void> setFontSize(double value) async {
    fontSize = clampFontSize(value);
    await preferences?.setDouble(storageKey, fontSize);
    notifyListeners();
  }
}

double clampFontSize(double value) {
  return value
      .clamp(
        ReaderPrefsController.minFontSize,
        ReaderPrefsController.maxFontSize,
      )
      .roundToDouble();
}
