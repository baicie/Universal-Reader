import 'models.dart';

final seedDocuments = <LibraryDocument>[
  _doc('design', '设计中的设计', '原研哉', DocumentFormat.epub, 0xFF314D49, .37),
  _doc(
    'creative',
    'The Creative Act',
    'Rick Rubin',
    DocumentFormat.epub,
    0xFFC9A879,
    0,
  ),
  _doc(
    'data',
    'Designing Data-Intensive Applications',
    'Martin Kleppmann',
    DocumentFormat.pdf,
    0xFF527882,
    .64,
  ),
  _doc(
    'prince',
    '小王子',
    'Antoine de Saint-Exupéry',
    DocumentFormat.epub,
    0xFFA25848,
    .82,
  ),
  _doc(
    'science',
    'The Art of Doing Science',
    'Richard Hamming',
    DocumentFormat.pdf,
    0xFFD8D0BB,
    .15,
  ),
  _doc(
    'patterns',
    'Head First Design Patterns',
    'Eric Freeman',
    DocumentFormat.epub,
    0xFF3D4546,
    0,
  ),
  _doc('solitude', '百年孤独', '加西亚·马尔克斯', DocumentFormat.epub, 0xFFB3ABC7, .25),
  _doc(
    'code',
    'The Way of Code',
    'Reed Berkowitz',
    DocumentFormat.cbz,
    0xFF77836D,
    0,
  ),
  _doc('galaxy', '银河系漫游手册', '奥杜', DocumentFormat.cbz, 0xFFD1AE50, .48),
  _doc(
    'rust',
    'Rust 程序设计语言',
    'Steve Klabnik',
    DocumentFormat.markdown,
    0xFF55636D,
    .71,
  ),
];

LibraryDocument _doc(
  String id,
  String title,
  String author,
  DocumentFormat format,
  int color,
  double progress,
) {
  return LibraryDocument(
    metadata: DocumentMetadata(
      id: id,
      title: title,
      author: author,
      format: format,
      type: format.type,
      coverColor: color,
    ),
    readingState: ReadingState(progress: progress, lastOpened: DateTime.now()),
  );
}
