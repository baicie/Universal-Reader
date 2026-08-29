import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'comic_layout.dart';
import 'reading_surface.dart';

export 'comic_layout.dart';
export 'reading_surface.dart';

class ReaderPrefsController extends ChangeNotifier {
  ReaderPrefsController([this.preferences]);

  static const storageKey = 'universal_reader.reader.font_size.v1';
  static const lineHeightKey = 'universal_reader.reader.line_height.v1';
  static const fontFamilyKey = 'universal_reader.reader.font_family.v1';
  static const paperKey = 'universal_reader.reader.paper.v1';
  static const comicLayoutKey = 'universal_reader.reader.comic_layout.v1';
  static const comicDirectionKey = 'universal_reader.reader.comic_direction.v1';
  static const pdfZoomKey = 'universal_reader.reader.pdf_zoom.v1';
  static const minFontSize = 14.0;
  static const maxFontSize = 28.0;
  static const defaultFontSize = 18.0;
  static const minLineHeight = 1.4;
  static const maxLineHeight = 2.2;
  static const defaultLineHeight = 1.7;
  static const minPdfZoom = 1.0;
  static const maxPdfZoom = 3.0;
  static const defaultPdfZoom = 1.0;
  static const pdfZoomStops = [1.0, 1.25, 1.5, 2.0, 3.0];

  final SharedPreferences? preferences;
  double fontSize = defaultFontSize;
  double lineHeight = defaultLineHeight;
  ReaderFontFamily fontFamily = ReaderFontFamily.serif;
  ReaderPaper paper = ReaderPaper.followApp;
  ComicLayout comicLayout = ComicLayout.single;
  ComicReadDirection comicDirection = ComicReadDirection.ltr;
  double pdfZoom = defaultPdfZoom;

  Future<void> load() async {
    fontSize = clampFontSize(
      preferences?.getDouble(storageKey) ?? defaultFontSize,
    );
    lineHeight = clampLineHeight(
      preferences?.getDouble(lineHeightKey) ?? defaultLineHeight,
    );
    fontFamily = parseReaderFontFamily(preferences?.getString(fontFamilyKey));
    paper = parseReaderPaper(preferences?.getString(paperKey));
    comicLayout = parseComicLayout(preferences?.getString(comicLayoutKey));
    comicDirection = parseComicReadDirection(
      preferences?.getString(comicDirectionKey),
    );
    pdfZoom = clampPdfZoom(
      preferences?.getDouble(pdfZoomKey) ?? defaultPdfZoom,
    );
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

  Future<void> setComicLayout(ComicLayout value) async {
    comicLayout = value;
    await preferences?.setString(comicLayoutKey, value.name);
    notifyListeners();
  }

  Future<void> setComicDirection(ComicReadDirection value) async {
    comicDirection = value;
    await preferences?.setString(comicDirectionKey, value.name);
    notifyListeners();
  }

  Future<void> setPdfZoom(double value) async {
    pdfZoom = clampPdfZoom(value);
    await preferences?.setDouble(pdfZoomKey, pdfZoom);
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

double clampPdfZoom(double value) {
  return ((value * 4).round() / 4).clamp(
    ReaderPrefsController.minPdfZoom,
    ReaderPrefsController.maxPdfZoom,
  );
}
