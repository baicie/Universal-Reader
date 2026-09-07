import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/features/reader/reader_progress_bar.dart';

void main() {
  testWidgets('shows the label and a rounded percentage', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReaderProgressBar(
          progress: 0.42,
          label: '第 3 / 12 章',
          paper: const Color(0xFFF5F0E8),
          muted: Colors.grey,
          ink: Colors.black,
          onSeek: (_) {},
        ),
      ),
    ));
    expect(find.text('第 3 / 12 章'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
  });

  testWidgets('clamps out-of-range progress before rendering', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReaderProgressBar(
          progress: -0.5,
          label: 'x',
          paper: const Color(0xFFF5F0E8),
          muted: Colors.grey,
          ink: Colors.black,
          onSeek: (_) {},
        ),
      ),
    ));
    expect(find.text('0%'), findsOneWidget);
  });

  testWidgets('clamps high progress before rendering', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReaderProgressBar(
          progress: 1.7,
          label: 'x',
          paper: const Color(0xFFF5F0E8),
          muted: Colors.grey,
          ink: Colors.black,
          onSeek: (_) {},
        ),
      ),
    ));
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('slider drag invokes onSeek with the raw value', (tester) async {
    double? lastSeek;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 200,
          child: ReaderProgressBar(
            progress: 0.0,
            label: 'x',
            paper: const Color(0xFFF5F0E8),
            muted: Colors.grey,
            ink: Colors.black,
            onSeek: (v) => lastSeek = v,
          ),
        ),
      ),
    ));
    // Tap the slider in the middle of the track.
    final sliderFinder = find.byType(Slider);
    expect(sliderFinder, findsOneWidget);
    final rect = tester.getRect(sliderFinder);
    await tester.tapAt(rect.center);
    await tester.pump();
    expect(lastSeek, isNotNull);
    expect(lastSeek! >= 0 && lastSeek! <= 1, isTrue);
  });
}
