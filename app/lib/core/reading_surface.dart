import 'package:flutter/material.dart';

enum ReaderFontFamily { serif, sans, mono }

enum ReaderPaper { followApp, light, dark }

class ReadingSurface {
  const ReadingSurface({
    required this.fontSize,
    required this.lineHeight,
    required this.fontFamily,
    required this.background,
    required this.color,
  });

  static const lightBackground = Color(0xFFF5F0E8);
  static const lightInk = Color(0xFF2A2620);
  static const darkBackground = Color(0xFF1C1B18);
  static const darkInk = Color(0xFFE8E2D6);
  static const lightMuted = Color(0xFF8A7358);
  static const darkMuted = Color(0xFFB7A894);

  static const serifCss = 'Georgia, "Noto Serif", "Songti SC", serif';
  static const sansCss =
      'system-ui, "Segoe UI", "PingFang SC", "Noto Sans", sans-serif';
  static const monoCss =
      'ui-monospace, "Cascadia Mono", "Sarasa Mono SC", monospace';

  final double fontSize;
  final double lineHeight;
  final ReaderFontFamily fontFamily;
  final Color background;
  final Color color;

  bool get isDark => background == darkBackground;

  Color get muted => isDark ? darkMuted : lightMuted;

  String get cssBackground => _cssHex(background);

  String get cssColor => _cssHex(color);

  String get cssFontFamily => switch (fontFamily) {
    ReaderFontFamily.serif => serifCss,
    ReaderFontFamily.sans => sansCss,
    ReaderFontFamily.mono => monoCss,
  };

  String? get flutterFontFamily => switch (fontFamily) {
    ReaderFontFamily.serif => 'Georgia',
    ReaderFontFamily.sans => null,
    ReaderFontFamily.mono => 'Courier',
  };

  Map<String, Object?> toFoliateCommand() {
    return {
      'fontSize': fontSize,
      'lineHeight': lineHeight,
      'fontFamily': cssFontFamily,
      'background': cssBackground,
      'color': cssColor,
    };
  }

  static ReadingSurface resolve({
    required double fontSize,
    required double lineHeight,
    required ReaderFontFamily fontFamily,
    required ReaderPaper paper,
    required Brightness brightness,
  }) {
    final dark =
        paper == ReaderPaper.dark ||
        (paper == ReaderPaper.followApp && brightness == Brightness.dark);
    return ReadingSurface(
      fontSize: fontSize,
      lineHeight: lineHeight,
      fontFamily: fontFamily,
      background: dark ? darkBackground : lightBackground,
      color: dark ? darkInk : lightInk,
    );
  }

  static const light = ReadingSurface(
    fontSize: 18,
    lineHeight: 1.7,
    fontFamily: ReaderFontFamily.serif,
    background: lightBackground,
    color: lightInk,
  );

  static ReadingSurface get lightDefaults => light;

  @override
  bool operator ==(Object other) {
    return other is ReadingSurface &&
        fontSize == other.fontSize &&
        lineHeight == other.lineHeight &&
        fontFamily == other.fontFamily &&
        background == other.background &&
        color == other.color;
  }

  @override
  int get hashCode =>
      Object.hash(fontSize, lineHeight, fontFamily, background, color);
}

ReaderFontFamily parseReaderFontFamily(String? raw) {
  return switch (raw) {
    'sans' => ReaderFontFamily.sans,
    'mono' => ReaderFontFamily.mono,
    _ => ReaderFontFamily.serif,
  };
}

ReaderPaper parseReaderPaper(String? raw) {
  return switch (raw) {
    'light' => ReaderPaper.light,
    'dark' => ReaderPaper.dark,
    _ => ReaderPaper.followApp,
  };
}

String _cssHex(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
