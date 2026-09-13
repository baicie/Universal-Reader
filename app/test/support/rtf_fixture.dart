import 'dart:convert';

List<int> minimalRtfBytes({
  String title = 'RTF Compatibility Book',
  String author = 'Rich Text',
  String firstTitle = 'Chapter One',
  String secondTitle = 'Chapter Two',
}) {
  final source =
      r'''{\rtf1\ansi\ansicpg1252
{\info{\title ''' +
      title +
      r'''}{\author ''' +
      author +
      r'''}}
{\fonttbl{\f0 Arial;}}
\pard\s1 ''' +
      firstTitle +
      r'''\par
\pard Hello \b bold\b0 and \i italic\i0 text.\par
\pard Unicode: \u20013?\u25991?\par
\pard Bullet: \bullet\tab First item\par
\trowd\cellx2000\cellx4000
Key\cell Value\cell\row
\pard\s2 ''' +
      secondTitle +
      r'''\par
\pard
Second chapter body.\par
}''';
  return utf8.encode(source);
}
