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

  group('fontFamily branches', () {
    test('mono family uses the monospace css stack', () {
      const surface = ReadingSurface(
        fontSize: 18,
        lineHeight: 1.7,
        fontFamily: ReaderFontFamily.mono,
        background: ReadingSurface.lightBackground,
        color: ReadingSurface.lightInk,
      );
      expect(surface.cssFontFamily, contains('Cascadia Mono'));
      expect(surface.flutterFontFamily, 'Courier');
    });

    test(
      'sans family maps to the platform default and exposes no override',
      () {
        const surface = ReadingSurface(
          fontSize: 18,
          lineHeight: 1.7,
          fontFamily: ReaderFontFamily.sans,
          background: ReadingSurface.lightBackground,
          color: ReadingSurface.lightInk,
        );
        expect(surface.flutterFontFamily, isNull);
        // cssFontFamily for sans is already exercised indirectly via
        // toFoliateCommand above, but assert it here so the branch is named.
        expect(surface.cssFontFamily, contains('system-ui'));
      },
    );
  });

  group('equality and hashing', () {
    test('two surfaces with identical fields compare equal', () {
      const a = ReadingSurface(
        fontSize: 18,
        lineHeight: 1.7,
        fontFamily: ReaderFontFamily.serif,
        background: ReadingSurface.lightBackground,
        color: ReadingSurface.lightInk,
      );
      const b = ReadingSurface(
        fontSize: 18,
        lineHeight: 1.7,
        fontFamily: ReaderFontFamily.serif,
        background: ReadingSurface.lightBackground,
        color: ReadingSurface.lightInk,
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('hashCode is stable enough for Set lookup', () {
      const a = ReadingSurface(
        fontSize: 18,
        lineHeight: 1.7,
        fontFamily: ReaderFontFamily.serif,
        background: ReadingSurface.lightBackground,
        color: ReadingSurface.lightInk,
      );
      const b = ReadingSurface(
        fontSize: 18,
        lineHeight: 1.7,
        fontFamily: ReaderFontFamily.serif,
        background: ReadingSurface.lightBackground,
        color: ReadingSurface.lightInk,
      );
      // Set dedupes via hashCode + equals; covering the getter end-to-end.
      // Build the set via repeated add() rather than a literal so the test
      // expresses "adding an equal element is a no-op" without tripping the
      // equal-elements-in-set-literal lint.
      final found = <ReadingSurface>{};
      found.add(a);
      found.add(b);
      expect(found, hasLength(1));
    });
  });
}
