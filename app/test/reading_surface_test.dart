import 'package:app/core/reading_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('follow-app paper uses night ink when the app is dark', () {
    final surface = ReadingSurface.resolve(
      fontSize: 18,
      lineHeight: 1.7,
      fontFamily: ReaderFontFamily.serif,
      paper: ReaderPaper.followApp,
      brightness: Brightness.dark,
    );
    expect(surface.cssBackground, '#1C1B18');
    expect(surface.cssColor, '#E8E2D6');
    expect(surface.isDark, isTrue);
  });

  test('light paper stays light when the app is dark', () {
    final surface = ReadingSurface.resolve(
      fontSize: 20,
      lineHeight: 2.0,
      fontFamily: ReaderFontFamily.sans,
      paper: ReaderPaper.light,
      brightness: Brightness.dark,
    );
    expect(surface.cssBackground, '#F5F0E8');
    expect(surface.cssColor, '#2A2620');
    expect(surface.isDark, isFalse);
    expect(surface.toFoliateCommand()['fontFamily'], contains('sans-serif'));
    expect(surface.toFoliateCommand()['lineHeight'], 2.0);
    expect(surface.toFoliateCommand()['fontSize'], 20);
  });
}
