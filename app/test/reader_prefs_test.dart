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

  test('clamps line height to one decimal in range', () {
    expect(clampLineHeight(1), ReaderPrefsController.minLineHeight);
    expect(clampLineHeight(3), ReaderPrefsController.maxLineHeight);
    expect(clampLineHeight(1.74), 1.7);
  });

  test('load restores line height, font family, and paper', () async {
    SharedPreferences.setMockInitialValues({
      ReaderPrefsController.lineHeightKey: 2.0,
      ReaderPrefsController.fontFamilyKey: 'sans',
      ReaderPrefsController.paperKey: 'dark',
    });
    final preferences = await SharedPreferences.getInstance();
    final prefs = ReaderPrefsController(preferences);
    await prefs.load();
    expect(prefs.lineHeight, 2.0);
    expect(prefs.fontFamily, ReaderFontFamily.sans);
    expect(prefs.paper, ReaderPaper.dark);
  });

  test('unknown stored font family and paper stay at defaults', () async {
    SharedPreferences.setMockInitialValues({
      ReaderPrefsController.fontFamilyKey: 'comic-sans',
      ReaderPrefsController.paperKey: 'sepia',
    });
    final preferences = await SharedPreferences.getInstance();
    final prefs = ReaderPrefsController(preferences);
    await prefs.load();
    expect(prefs.fontFamily, ReaderFontFamily.serif);
    expect(prefs.paper, ReaderPaper.followApp);
  });

  test('setters persist clamped typography', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final prefs = ReaderPrefsController(preferences);
    await prefs.setLineHeight(1.96);
    await prefs.setFontFamily(ReaderFontFamily.mono);
    await prefs.setPaper(ReaderPaper.light);
    expect(prefs.lineHeight, 2.0);
    expect(preferences.getDouble(ReaderPrefsController.lineHeightKey), 2.0);
    expect(preferences.getString(ReaderPrefsController.fontFamilyKey), 'mono');
    expect(preferences.getString(ReaderPrefsController.paperKey), 'light');
  });

  test('load restores comic layout and reading direction', () async {
    SharedPreferences.setMockInitialValues({
      ReaderPrefsController.comicLayoutKey: 'double',
      ReaderPrefsController.comicDirectionKey: 'rtl',
    });
    final preferences = await SharedPreferences.getInstance();
    final prefs = ReaderPrefsController(preferences);
    await prefs.load();
    expect(prefs.comicLayout, ComicLayout.double);
    expect(prefs.comicDirection, ComicReadDirection.rtl);
  });

  test('unknown comic layout stays single and left-to-right', () async {
    SharedPreferences.setMockInitialValues({
      ReaderPrefsController.comicLayoutKey: 'wide',
      ReaderPrefsController.comicDirectionKey: 'vertical',
    });
    final preferences = await SharedPreferences.getInstance();
    final prefs = ReaderPrefsController(preferences);
    await prefs.load();
    expect(prefs.comicLayout, ComicLayout.single);
    expect(prefs.comicDirection, ComicReadDirection.ltr);
  });

  test('setters persist comic layout and direction', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final prefs = ReaderPrefsController(preferences);
    await prefs.setComicLayout(ComicLayout.vertical);
    await prefs.setComicDirection(ComicReadDirection.rtl);
    expect(prefs.comicLayout, ComicLayout.vertical);
    expect(
      preferences.getString(ReaderPrefsController.comicLayoutKey),
      'vertical',
    );
    expect(
      preferences.getString(ReaderPrefsController.comicDirectionKey),
      'rtl',
    );
  });

  test('clamps pdf zoom to quarter steps in range', () {
    expect(clampPdfZoom(0.2), ReaderPrefsController.minPdfZoom);
    expect(clampPdfZoom(5), ReaderPrefsController.maxPdfZoom);
    expect(clampPdfZoom(1.6), 1.5);
  });

  test('load restores pdf zoom', () async {
    SharedPreferences.setMockInitialValues({
      ReaderPrefsController.pdfZoomKey: 1.5,
    });
    final preferences = await SharedPreferences.getInstance();
    final prefs = ReaderPrefsController(preferences);
    await prefs.load();
    expect(prefs.pdfZoom, 1.5);
  });

  test('unknown pdf zoom stays at 1', () async {
    SharedPreferences.setMockInitialValues({
      ReaderPrefsController.pdfZoomKey: 0.0,
    });
    final preferences = await SharedPreferences.getInstance();
    final prefs = ReaderPrefsController(preferences);
    await prefs.load();
    expect(prefs.pdfZoom, ReaderPrefsController.minPdfZoom);
  });

  test('setPdfZoom persists the clamped value', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final prefs = ReaderPrefsController(preferences);
    await prefs.setPdfZoom(1.6);
    expect(prefs.pdfZoom, 1.5);
    expect(preferences.getDouble(ReaderPrefsController.pdfZoomKey), 1.5);
  });
}
