import 'package:app/features/library/annotation_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('saves a note per book and does not invent another book', () async {
    SharedPreferences.setMockInitialValues({});
    final store = SharedPreferencesAnnotationRepository(
      await SharedPreferences.getInstance(),
    );
    final note = ReaderAnnotation(
      id: '1',
      note: 'saved reply',
      quote: 'what is white?',
      locatorLabel: 'chapter-4',
      createdAt: DateTime.utc(2026, 8, 29),
    );

    await store.append('design', note);

    expect((await store.load('design')).single.note, 'saved reply');
    expect(await store.load('other'), isEmpty);
  });

  test('corrupt annotation json is an error, not an empty list', () async {
    SharedPreferences.setMockInitialValues({
      '${SharedPreferencesAnnotationRepository.prefix}design': '{not-json',
    });
    final store = SharedPreferencesAnnotationRepository(
      await SharedPreferences.getInstance(),
    );

    expect(store.load('design'), throwsA(isA<FormatException>()));
  });
}
