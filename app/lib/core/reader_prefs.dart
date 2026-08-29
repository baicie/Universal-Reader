import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'reading_surface.dart';

export 'reading_surface.dart';

class ReaderPrefsController extends ChangeNotifier {
  ReaderPrefsController([this.preferences]);

  static const storageKey = 'universal_reader.reader.font_size.v1';
  static const lineHeightKey = 'universal_reader.reader.line_height.v1';
  static const fontFamilyKey = 'universal_reader.reader.font_family.v1';
  static const paperKey = 'universal_reader.reader.paper.v1';
  static const minFontSize = 14.0;
  static const maxFontSize = 28.0;
  static const defaultFontSize = 18.0;
  static const minLineHeight = 1.4;
  static const maxLineHeight = 2.2;
  static const defaultLineHeight = 1.7;

  final SharedPreferences? preferences;
  double fontSize = defaultFontSize;
  double lineHeight = defaultLineHeight;
  ReaderFontFamily fontFamily = ReaderFontFamily.serif;
  ReaderPaper paper = ReaderPaper.followApp;

  Future<void> load() async {
    fontSize = clampFontSize(
      preferences?.getDouble(storageKey) ?? defaultFontSize,
    );
    lineHeight = clampLineHeight(
      preferences?.getDouble(lineHeightKey) ?? defaultLineHeight,
    );
    fontFamily = parseReaderFontFamily(preferences?.getString(fontFamilyKey));
    paper = parseReaderPaper(preferences?.getString(paperKey));
    notifyListeners();
  }

  Future<void> setFontSize(double value) async {
    fontSize = clampFontSize(value);
    await preferences?.setDouble(storageKey, fontSize);
    notifyListeners();
  }

  Future<void> setLineHeight(double value) async {
    lineHeight = clampLineHeight(value);
    await preferences?.setDouble(lineHeightKey, lineHeight);
    notifyListeners();
  }

  Future<void> setFontFamily(ReaderFontFamily value) async {
    fontFamily = value;
    await preferences?.setString(fontFamilyKey, value.name);
    notifyListeners();
  }

  Future<void> setPaper(ReaderPaper value) async {
    paper = value;
    await preferences?.setString(paperKey, value.name);
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

double clampLineHeight(double value) {
  return ((value * 10).round() / 10).clamp(
    ReaderPrefsController.minLineHeight,
    ReaderPrefsController.maxLineHeight,
  );
}
