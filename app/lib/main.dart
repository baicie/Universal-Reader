import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/library_controller.dart';
import 'core/library_repository.dart';
import 'core/models.dart';
import 'core/format_detector.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final repository = SharedPreferencesLibraryRepository(preferences);
  runApp(
    ProviderScope(
      overrides: [libraryRepositoryProvider.overrideWithValue(repository)],
      child: const UniversalReaderApp(),
    ),
  );
}

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  throw StateError('Library repository must be overridden at startup');
});

final libraryProvider = ChangeNotifierProvider<PersistedLibraryController>((
  ref,
) {
  final controller = PersistedLibraryController(
    repository: ref.watch(libraryRepositoryProvider),
    initialDocuments: seedDocuments,
  );
  controller.load();
  return controller;
});
final themeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.light);
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, state) => const LibraryPage()),
      GoRoute(
        path: '/reader/:id',
        builder: (_, state) => ReaderPage(id: state.pathParameters['id']!),
      ),
      GoRoute(path: '/settings', builder: (_, state) => const SettingsPage()),
    ],
  );
});

class UniversalReaderApp extends ConsumerWidget {
  const UniversalReaderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Universal Reader',
      debugShowCheckedModeBanner: false,
      themeMode: ref.watch(themeProvider),
      theme: readerTheme(Brightness.light),
      darkTheme: readerTheme(Brightness.dark),
      routerConfig: ref.watch(routerProvider),
    );
  }
}

ThemeData readerTheme(Brightness brightness) {
  const accent = Color(0xFF2F5B57);
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
    surface: dark ? const Color(0xFF151A1B) : const Color(0xFFF7F8FA),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamily: 'Arial',
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? const Color(0xFF202728) : Colors.white,
      shape: const RoundedRectangleBorder(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF202728) : const Color(0xFFF0F2F4),
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
  );
}

class LegacyLibraryController extends ChangeNotifier {
  LegacyLibraryController() : _documents = List.of(seedDocuments);

  final FormatDetector detector = const FormatDetector();
  final List<LibraryDocument> _documents;
  String query = '';
  String section = 'all';
  String formatType = 'all';
  String sort = 'recent';
  bool listView = false;

  List<LibraryDocument> get documents {
    final result = _documents.where((document) {
      final metadata = document.metadata;
      final text =
          '${metadata.title} ${metadata.author} ${metadata.format.label}'
              .toLowerCase();
      final queryMatches = query.isEmpty || text.contains(query.toLowerCase());
      final typeMatches =
          formatType == 'all' || metadata.type.name == formatType;
      final progress = document.readingState.progress;
      final sectionMatches = switch (section) {
        'reading' => progress > 0 && progress < 1,
        'favorites' => {'design', 'prince', 'rust'}.contains(metadata.id),
        _ => true,
      };
      return queryMatches && typeMatches && sectionMatches;
    }).toList();
    result.sort(
      (a, b) => switch (sort) {
        'title' => a.metadata.title.compareTo(b.metadata.title),
        'progress' => b.readingState.progress.compareTo(
          a.readingState.progress,
        ),
        _ => b.readingState.lastOpened.compareTo(a.readingState.lastOpened),
      },
    );
    return result;
  }

  void search(String value) {
    query = value;
    notifyListeners();
  }

  void selectSection(String value) {
    section = value;
    notifyListeners();
  }

  void selectType(String value) {
    formatType = value;
    notifyListeners();
  }

  void selectSort(String value) {
    sort = value;
    notifyListeners();
  }

  void toggleView() {
    listView = !listView;
    notifyListeners();
  }

  Future<String?> importFiles() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return null;
    var count = 0;
    for (final file in files) {
      final source = DocumentSource(name: file.name, path: file.path);
      final format = detector.detect(source);
      if (format == DocumentFormat.unknown) continue;
      _documents.insert(
        0,
        LibraryDocument(
          metadata: DocumentMetadata(
            id: file.name,
            title: file.name.replaceFirst(RegExp(r'\.[^.]+$'), ''),
            author: '本地文件',
            format: format,
            type: format.type,
            coverColor: 0xFF6F8179,
          ),
          readingState: ReadingState(progress: 0, lastOpened: DateTime.now()),
        ),
      );
      count++;
    }
    notifyListeners();
    return count == 0 ? '没有识别到支持的格式' : '已导入 $count 本书籍';
  }

  void opened(String id) {
    final index = _documents.indexWhere((item) => item.metadata.id == id);
    if (index < 0) return;
    final item = _documents[index];
    _documents[index] = item.copyWith(
      readingState: ReadingState(
        progress: item.readingState.progress,
        lastOpened: DateTime.now(),
      ),
    );
    notifyListeners();
  }
}

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

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});
  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(libraryProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      drawer: wide ? null : const LibraryDrawer(),
      appBar: AppBar(
        leading: wide
            ? null
            : Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
        titleSpacing: wide ? 42 : 0,
        title: const BrandMark(),
        actions: [
          SizedBox(
            width: wide ? 290 : 145,
            child: TextField(
              controller: searchController,
              onChanged: controller.search,
              decoration: const InputDecoration(
                hintText: '搜索书名、作者或格式',
                prefixIcon: Icon(Icons.search, size: 18),
              ),
            ),
          ),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: CircleAvatar(
              radius: 15,
              backgroundColor: Color(0xFFD7E3DF),
              child: Text('L', style: TextStyle(color: Color(0xFF2F5B57))),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          if (wide) const SizedBox(width: 238, child: LibraryDrawer()),
          Expanded(child: _content(context, controller, wide)),
        ],
      ),
    );
  }

  Widget _content(
    BuildContext context,
    PersistedLibraryController controller,
    bool wide,
  ) {
    final side = wide ? 70.0 : 20.0;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(side, 42, side, 36),
          sliver: SliverToBoxAdapter(child: _header(context, controller, wide)),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: side),
          sliver: SliverToBoxAdapter(child: const ContinueCard()),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(side, 32, side, 22),
          sliver: SliverToBoxAdapter(child: _filters(controller)),
        ),
        if (controller.documents.isEmpty)
          const SliverFillRemaining(hasScrollBody: false, child: EmptyLibrary())
        else
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: side),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) => BookCard(
                  document: controller.documents[index],
                  listView: controller.listView,
                ),
                childCount: controller.documents.length,
              ),
              gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: controller.listView ? 1000 : 190,
                mainAxisExtent: controller.listView ? 100 : 300,
                crossAxisSpacing: 26,
                mainAxisSpacing: 30,
              ),
            ),
          ),
      ],
    );
  }

  Widget _header(
    BuildContext context,
    PersistedLibraryController controller,
    bool wide,
  ) {
    final title =
        {
          'all': '全部书籍',
          'reading': '正在阅读',
          'favorites': '收藏',
        }[controller.section] ??
        '全部书籍';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Eyebrow('YOUR LIBRARY'),
            const SizedBox(height: 9),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${controller.documents.length} 本书籍 · 最近同步于刚刚',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
        if (wide)
          Row(
            children: [
              IconButton(
                tooltip: '切换视图',
                icon: Icon(
                  controller.listView ? Icons.grid_view : Icons.view_list,
                ),
                onPressed: controller.toggleView,
              ),
              FilledButton.icon(
                onPressed: () => _import(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('导入书籍'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _filters(PersistedLibraryController controller) {
    final options = [
      ('all', '全部'),
      ('reflow', '可重排'),
      ('fixedPage', '固定版式'),
      ('comic', '漫画'),
    ];
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text(item.$2),
                        selected: controller.formatType == item.$1,
                        onSelected: (_) => controller.selectType(item.$1),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
        DropdownButton<String>(
          value: controller.sort,
          underline: const SizedBox(),
          items: const [
            DropdownMenuItem(value: 'recent', child: Text('最近添加')),
            DropdownMenuItem(value: 'title', child: Text('标题')),
            DropdownMenuItem(value: 'progress', child: Text('阅读进度')),
          ],
          onChanged: (value) {
            if (value != null) controller.selectSort(value);
          },
        ),
      ],
    );
  }

  Future<void> _import(BuildContext context) async {
    final message = await ref.read(libraryProvider).importFiles();
    if (context.mounted && message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class ContinueCard extends ConsumerWidget {
  const ContinueCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final document = seedDocuments.first;
    return Card(
      color: const Color(0xFFE4ECE8),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Eyebrow('CONTINUE READING'),
                  const SizedBox(height: 9),
                  Text(
                    document.metadata.title,
                    style: const TextStyle(fontFamily: 'Georgia', fontSize: 26),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${document.metadata.author}  ·  第 4 章：白',
                    style: const TextStyle(
                      color: Color(0xFF70807D),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      SizedBox(
                        width: 170,
                        child: LinearProgressIndicator(
                          value: document.readingState.progress,
                          minHeight: 3,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        '37%',
                        style: TextStyle(
                          color: Color(0xFF2F5B57),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 13),
                  TextButton.icon(
                    onPressed: () => context.push('/reader/design'),
                    icon: const Icon(Icons.arrow_forward, size: 16),
                    label: const Text('继续阅读'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 26),
            CoverArt(metadata: document.metadata, width: 90, height: 120),
          ],
        ),
      ),
    );
  }
}

class LibraryDrawer extends ConsumerWidget {
  const LibraryDrawer({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(libraryProvider);
    final items = [
      ('all', Icons.grid_view, '全部'),
      ('reading', Icons.radio_button_checked, '正在阅读'),
      ('favorites', Icons.favorite_border, '收藏'),
    ];
    return Drawer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 30, 18, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Eyebrow('LIBRARY'),
              ),
              const SizedBox(height: 14),
              ...items.map(
                (item) => ListTile(
                  leading: Icon(item.$2, size: 19),
                  title: Text(item.$3, style: const TextStyle(fontSize: 13)),
                  selected: controller.section == item.$1,
                  onTap: () {
                    controller.selectSection(item.$1);
                    if (Navigator.canPop(context)) Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(height: 25),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Eyebrow('COLLECTIONS'),
              ),
              const SizedBox(height: 12),
              const ListTile(
                leading: CircleAvatar(
                  radius: 4,
                  backgroundColor: Color(0xFFC69355),
                ),
                title: Text('设计与灵感', style: TextStyle(fontSize: 12)),
              ),
              const ListTile(
                leading: CircleAvatar(
                  radius: 4,
                  backgroundColor: Color(0xFF6C9EB4),
                ),
                title: Text('技术阅读', style: TextStyle(fontSize: 12)),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.create_new_folder_outlined, size: 17),
                label: const Text('导入文件夹'),
              ),
              const SizedBox(height: 10),
              const Text(
                'Local-first · 离线可用',
                style: TextStyle(color: Color(0xFFA5ADB5), fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BookCard extends ConsumerWidget {
  const BookCard({required this.document, required this.listView, super.key});
  final LibraryDocument document;
  final bool listView;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metadata = document.metadata;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          metadata.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        const SizedBox(height: 5),
        Text(
          metadata.author,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 11),
        ),
        if (document.readingState.progress > 0) ...[
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: LinearProgressIndicator(
                  value: document.readingState.progress,
                  minHeight: 2,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                '${(document.readingState.progress * 100).round()}%',
                style: TextStyle(
                  color: Theme.of(context).hintColor,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ],
    );
    final content = InkWell(
      onTap: () {
        ref.read(libraryProvider).opened(metadata.id);
        context.push('/reader/${metadata.id}');
      },
      child: listView
          ? Row(
              children: [
                CoverArt(metadata: metadata, width: 60, height: 84),
                const SizedBox(width: 16),
                Expanded(child: details),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoverArt(metadata: metadata, height: 205),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: details,
                ),
              ],
            ),
    );
    return listView
        ? Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: content,
            ),
          )
        : content;
  }
}

class CoverArt extends StatelessWidget {
  const CoverArt({
    required this.metadata,
    this.width = 156,
    this.height = 220,
    super.key,
  });
  final DocumentMetadata metadata;
  final double width;
  final double height;
  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    padding: const EdgeInsets.all(14),
    color: Color(metadata.coverColor),
    child: Stack(
      children: [
        Positioned(
          top: 0,
          right: 0,
          child: Text(
            metadata.format.label,
            style: const TextStyle(color: Colors.white70, fontSize: 8),
          ),
        ),
        Align(
          alignment: Alignment.topLeft,
          child: Text(
            metadata.title,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Georgia',
              fontSize: 18,
              height: 1.1,
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            metadata.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 9),
          ),
        ),
      ],
    ),
  );
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 32,
        height: 32,
        color: const Color(0xFF2F5B57),
        alignment: Alignment.center,
        child: const Text(
          'UR',
          style: TextStyle(color: Colors.white, fontSize: 10),
        ),
      ),
      const SizedBox(width: 11),
      const Text(
        'Universal Reader',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    ],
  );
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: Color(0xFF9AA2AA),
      fontSize: 10,
      fontWeight: FontWeight.bold,
      letterSpacing: 1.5,
    ),
  );
}

class EmptyLibrary extends StatelessWidget {
  const EmptyLibrary({super.key});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.menu_book_outlined,
          size: 50,
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .35),
        ),
        const SizedBox(height: 14),
        const Text(
          '没有找到匹配的书籍',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          '尝试更换搜索词或筛选条件。',
          style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12),
        ),
      ],
    ),
  );
}

class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({required this.id, super.key});
  final String id;
  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  bool chrome = true;
  bool toc = false;
  double progress = .37;
  @override
  Widget build(BuildContext context) {
    final document = seedDocuments.firstWhere(
      (item) => item.metadata.id == widget.id,
      orElse: () => seedDocuments.first,
    );
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0E8),
      appBar: chrome
          ? AppBar(
              backgroundColor: const Color(0xFFF5F0E8),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/'),
              ),
              title: Text(
                document.metadata.title,
                style: const TextStyle(fontSize: 14),
              ),
              actions: [
                IconButton(
                  tooltip: '目录',
                  icon: const Icon(Icons.menu_book_outlined),
                  onPressed: () => setState(() => toc = !toc),
                ),
                IconButton(
                  tooltip: '阅读设置',
                  icon: const Icon(Icons.text_fields),
                  onPressed: () {},
                ),
              ],
            )
          : null,
      body: GestureDetector(
        onTap: () => setState(() => chrome = !chrome),
        child: Row(
          children: [
            if (toc)
              const SizedBox(
                width: 250,
                child: Material(
                  color: Color(0xFFF0EADF),
                  child: Padding(
                    padding: EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow('CONTENTS'),
                        SizedBox(height: 20),
                        Text('第 1 章 设计的轮廓'),
                        SizedBox(height: 18),
                        Text('第 2 章 无印良品'),
                        SizedBox(height: 18),
                        Text('第 3 章 白与空'),
                        SizedBox(height: 18),
                        Text(
                          '第 4 章 白',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2F5B57),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(38),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '第 4 章',
                          style: TextStyle(
                            color: Color(0xFFB79A7B),
                            letterSpacing: 2,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          '白',
                          style: TextStyle(fontFamily: 'Georgia', fontSize: 42),
                        ),
                        SizedBox(height: 36),
                        Text(
                          '白是一种包容所有颜色的颜色。它没有自己的主张，却能让其他事物显现出清晰的轮廓。在设计中，空白从来不是缺席，而是一种主动的表达。',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 19,
                            height: 1.85,
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          '我们习惯于把信息填满，把空间占据，把每一个空隙都看作需要解决的问题。但真正成熟的设计，知道什么时候应该停下来，让事物自己说话。',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 19,
                            height: 1.85,
                          ),
                        ),
                        SizedBox(height: 24),
                        Text(
                          '阅读是一种与留白相处的方式。文字之间的距离、章节之间的停顿，以及读者暂时离开页面的片刻，共同构成了完整的体验。',
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 19,
                            height: 1.85,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (chrome)
              Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Slider(
                      value: progress,
                      onChanged: (value) {
                        setState(() => progress = value);
                        ref
                            .read(libraryProvider)
                            .updateProgress(widget.id, value);
                      },
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(28),
        children: [
          const Eyebrow('PREFERENCES'),
          const SizedBox(height: 14),
          const Text(
            '外观',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Card(
            child: ListTile(
              title: const Text('主题'),
              subtitle: Text(mode == ThemeMode.dark ? '深色' : '浅色'),
              trailing: DropdownButton<ThemeMode>(
                value: mode,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: ThemeMode.light, child: Text('浅色')),
                  DropdownMenuItem(value: ThemeMode.dark, child: Text('深色')),
                  DropdownMenuItem(
                    value: ThemeMode.system,
                    child: Text('跟随系统'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    ref.read(themeProvider.notifier).state = value;
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            '资料库',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.folder_outlined),
                  title: Text('默认导入位置'),
                  subtitle: Text('由系统文件选择器管理'),
                ),
                Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.storage_outlined),
                  title: Text('本地优先存储'),
                  subtitle: Text('阅读进度和标注保存在本设备'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
