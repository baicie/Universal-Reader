import 'package:app/widgets/eyebrow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Eyebrow renders the given text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Eyebrow('CHAPTER ONE')),
      ),
    );

    expect(find.text('CHAPTER ONE'), findsOneWidget);
  });

  testWidgets('Eyebrow uses onSurfaceVariant colour from the theme',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: const ColorScheme.light(
            onSurfaceVariant: Color(0xFF9C89B8),
          ),
        ),
        home: const Scaffold(body: Eyebrow('Eyebrow Text')),
      ),
    );

    final text = tester.widget<Text>(find.text('Eyebrow Text'));
    expect(text.style?.color, const Color(0xFF9C89B8));
  });

  testWidgets('Eyebrow applies the correct font style', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Eyebrow('Styled')),
      ),
    );

    final text = tester.widget<Text>(find.text('Styled'));
    expect(text.style?.fontSize, 11);
    expect(text.style?.fontWeight, FontWeight.w600);
    expect(text.style?.letterSpacing, 0.8);
  });
}
