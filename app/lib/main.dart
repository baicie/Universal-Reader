import 'dart:math' as math;

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
import 'features/tools/ai/ai_settings.dart';
import 'features/tools/ai/ai_settings_controller.dart';
import 'features/tools/reader_ai_panel.dart';
import 'features/tools/sample_reader_document.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final repository = SharedPreferencesLibraryRepository(preferences);
  final aiSettings = SharedPreferencesAiSettingsRepository(preferences);
  runApp(
    ProviderScope(
      overrides: [
        libraryRepositoryProvider.overrideWithValue(repository),
        aiSettingsRepositoryProvider.overrideWithValue(aiSettings),
      ],
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
final aiSettingsRepositoryProvider = Provider<AiSettingsRepository>((ref) {
  throw StateError('AI settings repository must be overridden at startup');
});

final aiSettingsProvider = ChangeNotifierProvider<AiSettingsController>((ref) {
  final controller = AiSettingsController(
    repository: ref.watch(aiSettingsRepositoryProvider),
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

const _pine = Color(0xFF2F5B57);
const _pageMaxWidth = 1120.0;
const _coverRatio = 3 / 4;

ThemeData readerTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: _pine,
    brightness: brightness,
    surface: dark ? const Color(0xFF151A1B) : const Color(0xFFF7F8FA),
  );
  final radius = BorderRadius.circular(8);
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    visualDensity: VisualDensity.standard,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 64,
      titleSpacing: 16,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: dark ? const Color(0xFF202728) : Colors.white,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    listTileTheme: ListTileThemeData(
      dense: true,
      selectedTileColor: scheme.primary.withValues(alpha: 0.12),
      selectedColor: scheme.primary,
      iconColor: scheme.onSurfaceVariant,
      shape: RoundedRectangleBorder(borderRadius: radius),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      minLeadingWidth: 24,
      visualDensity: VisualDensity.compact,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: radius),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.primary.withValues(alpha: 0.12),
      linearMinHeight: 3,
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      inactiveTrackColor: scheme.primary.withValues(alpha: 0.16),
      thumbColor: scheme.primary,
      overlayColor: scheme.primary.withValues(alpha: 0.1),
      trackHeight: 3,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: radius),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      space: 1,
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: dark ? const Color(0xFF202728) : const Color(0xFFF0F2F4),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
      prefixIconColor: scheme.onSurfaceVariant,
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: radius,
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: radius,
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: scheme.primary.withValues(alpha: 0.4)),
        borderRadius: radius,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    chipTheme: ChipThemeData(
      selectedColor: scheme.primary.withValues(alpha: 0.16),
      backgroundColor: dark ? const Color(0xFF202728) : const Color(0xFFEEF1F2),
      labelStyle: const TextStyle(fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: BorderSide.none,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      showCheckmark: false,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 0,
      highlightElevation: 0,
    ),
  );
}

Widget _constrainedPage({required Widget child}) {
  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _pageMaxWidth),
      child: child,
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
                  tooltip: '打开菜单',
                  icon: const Icon(Icons.menu),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
        titleSpacing: wide ? 24 : 0,
        title: BrandMark(compact: MediaQuery.sizeOf(context).width < 600),
        actions: [
          if (wide)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                width: 280,
                child: SearchField(
                  controller: searchController,
                  onChanged: controller.search,
                ),
              ),
            ),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: wide
          ? null
          : FloatingActionButton(
              tooltip: '导入书籍',
              onPressed: () => _import(context),
              child: const Icon(Icons.add),
            ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide) const LibraryDrawer(embedded: true),
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
    final side = wide ? 40.0 : 20.0;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(side, 28, side, 20),
          sliver: SliverToBoxAdapter(
            child: _constrainedPage(
              child: Column(
                children: [
                  _header(context, controller, wide),
                  if (!wide) ...[
                    const SizedBox(height: 16),
                    SearchField(
                      controller: searchController,
                      onChanged: controller.search,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (controller.continueReading != null)
          SliverPadding(
            padding: EdgeInsets.fromLTRB(side, 0, side, 8),
            sliver: SliverToBoxAdapter(
              child: _constrainedPage(
                child: ContinueCard(document: controller.continueReading!),
              ),
            ),
          ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(side, 20, side, 16),
          sliver: SliverToBoxAdapter(
            child: _constrainedPage(child: _filters(controller)),
          ),
        ),
        if (controller.documents.isEmpty)
          const SliverFillRemaining(hasScrollBody: false, child: EmptyLibrary())
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(side, 0, side, wide ? 48 : 88),
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final maxW = math.min(
                  constraints.crossAxisExtent,
                  _pageMaxWidth,
                );
                if (controller.listView) {
                  return SliverToBoxAdapter(
                    child: _constrainedPage(
                      child: Column(
                        children: [
                          for (var i = 0; i < controller.documents.length; i++)
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: i == controller.documents.length - 1
                                    ? 0
                                    : 12,
                              ),
                              child: BookCard(
                                document: controller.documents[i],
                                listView: true,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }
                const gap = 20.0;
                final columns = math.max(2, (maxW / 196).floor());
                final cellW = (maxW - gap * (columns - 1)) / columns;
                final extent = cellW / _coverRatio + 100;
                return SliverToBoxAdapter(
                  child: _constrainedPage(
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: controller.documents.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisExtent: extent,
                        crossAxisSpacing: gap,
                        mainAxisSpacing: 24,
                      ),
                      itemBuilder: (context, index) => BookCard(
                        document: controller.documents[index],
                        listView: false,
                      ),
                    ),
                  ),
                );
              },
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
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Eyebrow('资料库'),
              const SizedBox(height: 8),
              Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${controller.documents.length} 本书籍',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: '切换视图',
          icon: Icon(controller.listView ? Icons.grid_view : Icons.view_list),
          onPressed: controller.toggleView,
        ),
        if (wide) ...[
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: () => _import(context),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('导入书籍'),
          ),
        ],
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
              children: [
                for (final item in options)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(item.$2),
                      selected: controller.formatType == item.$1,
                      onSelected: (_) => controller.selectType(item.$1),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: controller.sort,
            borderRadius: BorderRadius.circular(8),
            items: const [
              DropdownMenuItem(value: 'recent', child: Text('最近阅读')),
              DropdownMenuItem(value: 'title', child: Text('标题')),
              DropdownMenuItem(value: 'progress', child: Text('阅读进度')),
            ],
            onChanged: (value) {
              if (value != null) controller.selectSort(value);
            },
          ),
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
  const ContinueCard({required this.document, super.key});
  final LibraryDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final percent = (document.readingState.progress * 100).round();
    return Card(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
      child: InkWell(
        onTap: () {
          ref.read(libraryProvider).opened(document.metadata.id);
          context.push('/reader/${document.metadata.id}');
        },
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Eyebrow('继续阅读'),
                    const SizedBox(height: 8),
                    Text(
                      document.metadata.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      document.metadata.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: document.readingState.progress,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '$percent%',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextButton.icon(
                      onPressed: () {
                        ref.read(libraryProvider).opened(document.metadata.id);
                        context.push('/reader/${document.metadata.id}');
                      },
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text('继续阅读'),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),
              CoverArt(metadata: document.metadata, width: 84, height: 112),
            ],
          ),
        ),
      ),
    );
  }
}

class LibraryDrawer extends ConsumerWidget {
  const LibraryDrawer({this.embedded = false, super.key});
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(libraryProvider);
    final theme = Theme.of(context);
    final items = [
      ('all', Icons.grid_view_outlined, '全部'),
      ('reading', Icons.auto_stories_outlined, '正在阅读'),
      ('favorites', Icons.favorite_border, '收藏'),
    ];
    final collections = [
      (const Color(0xFFC69355), '设计与灵感'),
      (const Color(0xFF6C9EB4), '技术阅读'),
    ];
    final nav = SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Eyebrow('浏览'),
            ),
            const SizedBox(height: 8),
            for (final item in items)
              ListTile(
                leading: Icon(item.$2, size: 20),
                title: Text(item.$3),
                selected: controller.section == item.$1,
                onTap: () {
                  controller.selectSection(item.$1);
                  if (!embedded && Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Eyebrow('收藏夹'),
            ),
            const SizedBox(height: 8),
            for (final item in collections)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: item.$1,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(item.$2, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.create_new_folder_outlined, size: 18),
              label: const Text('导入文件夹'),
            ),
            const SizedBox(height: 10),
            Text(
              'Local-first · 离线可用',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
    if (embedded) {
      return Material(
        color: theme.colorScheme.surfaceContainerLow,
        child: SizedBox(width: 232, child: nav),
      );
    }
    return Drawer(child: nav);
  }
}

class BookCard extends ConsumerWidget {
  const BookCard({required this.document, required this.listView, super.key});
  final LibraryDocument document;
  final bool listView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metadata = document.metadata;
    final theme = Theme.of(context);
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          metadata.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          metadata.author,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (document.readingState.progress > 0) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: document.readingState.progress,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(document.readingState.progress * 100).round()}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ],
    );
    final content = listView
        ? Row(
            children: [
              CoverArt(metadata: metadata, width: 56, height: 76),
              const SizedBox(width: 14),
              Expanded(child: details),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CoverArt(metadata: metadata),
              const SizedBox(height: 10),
              Expanded(child: details),
            ],
          );
    return Material(
      color: listView ? theme.cardTheme.color : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          ref.read(libraryProvider).opened(metadata.id);
          context.push('/reader/${metadata.id}');
        },
        child: listView
            ? Padding(padding: const EdgeInsets.all(12), child: content)
            : content,
      ),
    );
  }
}

class CoverArt extends StatelessWidget {
  const CoverArt({required this.metadata, this.width, this.height, super.key});
  final DocumentMetadata metadata;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final cover = Color(metadata.coverColor);
    final light = cover.computeLuminance() > 0.48;
    final fg = light ? const Color(0xFF1C2423) : Colors.white;
    final muted = fg.withValues(alpha: 0.72);
    final art = Container(
      width: width,
      height: height,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      color: cover,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: Text(
              metadata.format.label,
              style: TextStyle(
                color: muted,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              metadata.title,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: fg,
                fontSize: width != null && width! < 80 ? 12 : 16,
                height: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            metadata.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: muted, fontSize: 11),
          ),
        ],
      ),
    );
    final clipped = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: art,
    );
    if (width != null && height != null) return clipped;
    return AspectRatio(aspectRatio: _coverRatio, child: clipped);
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({this.compact = false, super.key});
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.asset(
          'assets/branding/app_icon.png',
          width: 32,
          height: 32,
          filterQuality: FilterQuality.medium,
        ),
      ),
      if (!compact) ...[
        const SizedBox(width: 10),
        const Text(
          'Universal Reader',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ],
    ],
  );
}

class SearchField extends StatelessWidget {
  const SearchField({
    required this.controller,
    required this.onChanged,
    super.key,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: const InputDecoration(
        hintText: '搜索书名、作者或格式',
        prefixIcon: Icon(Icons.search, size: 18),
      ),
    );
  }
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
    ),
  );
}

class EmptyLibrary extends StatelessWidget {
  const EmptyLibrary({super.key});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 48,
              color: theme.colorScheme.primary.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 16),
            Text(
              '没有找到匹配的书籍',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '尝试更换搜索词或筛选条件。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
  bool ask = false;
  late double progress;

  static const _chapters = [
    '第 1 章 设计的轮廓',
    '第 2 章 无印良品',
    '第 3 章 白与空',
    '第 4 章 白',
  ];

  @override
  void initState() {
    super.initState();
    progress =
        ref
            .read(libraryProvider)
            .documentById(widget.id)
            ?.readingState
            .progress ??
        0.37;
  }

  @override
  Widget build(BuildContext context) {
    final document =
        ref.watch(libraryProvider).documentById(widget.id) ??
        seedDocuments.firstWhere(
          (item) => item.metadata.id == widget.id,
          orElse: () => seedDocuments.first,
        );
    final dark = Theme.of(context).brightness == Brightness.dark;
    final paper = dark ? const Color(0xFF1C1B18) : const Color(0xFFF5F0E8);
    final ink = dark ? const Color(0xFFE8E2D6) : const Color(0xFF2A2620);
    final muted = dark ? const Color(0xFFB7A894) : const Color(0xFF8A7358);
    final tocBg = dark ? const Color(0xFF24231F) : const Color(0xFFF0EADF);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final readerDocument = SampleReaderDocument(metadata: document.metadata);
    final aiSettings = ref.watch(aiSettingsProvider).settings;

    return Scaffold(
      backgroundColor: paper,
      appBar: chrome
          ? AppBar(
              backgroundColor: paper,
              foregroundColor: ink,
              leading: IconButton(
                tooltip: '返回书库',
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/'),
              ),
              title: Text(
                document.metadata.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              actions: [
                IconButton(
                  tooltip: '问这一页',
                  icon: Icon(
                    ask ? Icons.chat_bubble : Icons.chat_bubble_outline,
                    color: ask ? _pine : ink,
                  ),
                  onPressed: () => setState(() {
                    ask = !ask;
                    chrome = true;
                  }),
                ),
                IconButton(
                  tooltip: '目录',
                  icon: Icon(
                    toc ? Icons.menu_book : Icons.menu_book_outlined,
                    color: toc ? _pine : ink,
                  ),
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
        child: Stack(
          children: [
            Row(
              children: [
                if (toc)
                  Material(
                    color: tocBg,
                    child: SizedBox(
                      width: 240,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 24, 16, 24),
                        children: [
                          const Eyebrow('目录'),
                          const SizedBox(height: 12),
                          for (var i = 0; i < _chapters.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                _chapters[i],
                                style: TextStyle(
                                  fontWeight: i == 3
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: i == 3 ? _pine : ink,
                                  height: 1.4,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          28,
                          chrome ? 32 : 48,
                          28,
                          chrome ? 112 : 48,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '第 4 章',
                              style: TextStyle(
                                color: muted,
                                letterSpacing: 2,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              '白',
                              style: TextStyle(
                                color: ink,
                                fontSize: 36,
                                fontWeight: FontWeight.w600,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              '白是一种包容所有颜色的颜色。它没有自己的主张，却能让其他事物显现出清晰的轮廓。在设计中，空白从来不是缺席，而是一种主动的表达。',
                              style: TextStyle(
                                color: ink,
                                fontSize: 18,
                                height: 1.85,
                              ),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              '我们习惯于把信息填满，把空间占据，把每一个空隙都看作需要解决的问题。但真正成熟的设计，知道什么时候应该停下来，让事物自己说话。',
                              style: TextStyle(
                                color: ink,
                                fontSize: 18,
                                height: 1.85,
                              ),
                            ),
                            const SizedBox(height: 22),
                            Text(
                              '阅读是一种与留白相处的方式。文字之间的距离、章节之间的停顿，以及读者暂时离开页面的片刻，共同构成了完整的体验。',
                              style: TextStyle(
                                color: ink,
                                fontSize: 18,
                                height: 1.85,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (ask)
              Positioned(
                top: wide ? 0 : null,
                left: wide ? null : 0,
                right: 0,
                bottom: chrome ? 72 : 0,
                width: wide ? 320 : null,
                height: wide ? null : MediaQuery.sizeOf(context).height * 0.45,
                child: ReaderAiPanel(
                  document: readerDocument,
                  settings: aiSettings,
                ),
              ),
            if (chrome)
              Positioned(
                left: toc ? 240 : 0,
                right: ask && wide ? 320 : 0,
                bottom: 0,
                child: Material(
                  color: paper,
                  child: SafeArea(
                    top: false,
                    child: GestureDetector(
                      onTap: () {},
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Slider(
                              value: progress,
                              onChanged: (value) {
                                setState(() => progress = value);
                                ref
                                    .read(libraryProvider)
                                    .updateProgress(widget.id, value);
                              },
                            ),
                            Row(
                              children: [
                                Text(
                                  '第 4 章',
                                  style: TextStyle(color: muted, fontSize: 12),
                                ),
                                const Spacer(),
                                Text(
                                  '${(progress * 100).round()}%',
                                  style: TextStyle(
                                    color: ink,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
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
    final theme = Theme.of(context);
    final themeLabel = switch (mode) {
      ThemeMode.dark => '深色',
      ThemeMode.light => '浅色',
      ThemeMode.system => '跟随系统',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
            children: [
              const Eyebrow('偏好'),
              const SizedBox(height: 8),
              Text(
                '设置',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                '外观',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('主题'),
                  subtitle: Text(themeLabel),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<ThemeMode>(
                      value: mode,
                      borderRadius: BorderRadius.circular(8),
                      items: const [
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text('浅色'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text('深色'),
                        ),
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
              ),
              const SizedBox(height: 28),
              Text(
                '阅读助手',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const _AiSettingsCard(),
              const SizedBox(height: 28),
              Text(
                '资料库',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.folder_outlined),
                      title: Text('默认导入位置'),
                      subtitle: Text('由系统文件选择器管理'),
                    ),
                    Divider(),
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
        ),
      ),
    );
  }
}

class _AiSettingsCard extends ConsumerStatefulWidget {
  const _AiSettingsCard();

  @override
  ConsumerState<_AiSettingsCard> createState() => _AiSettingsCardState();
}

class _AiSettingsCardState extends ConsumerState<_AiSettingsCard> {
  late final TextEditingController endpoint;
  late final TextEditingController model;
  late final TextEditingController apiKey;
  bool synced = false;

  @override
  void initState() {
    super.initState();
    endpoint = TextEditingController();
    model = TextEditingController();
    apiKey = TextEditingController();
  }

  @override
  void dispose() {
    endpoint.dispose();
    model.dispose();
    apiKey.dispose();
    super.dispose();
  }

  void _sync(AiSettings settings) {
    if (synced) return;
    endpoint.text = settings.endpoint;
    model.text = settings.model;
    apiKey.text = settings.apiKey;
    synced = true;
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(aiSettingsProvider);
    final settings = controller.settings;
    if (!controller.loading && !synced) {
      _sync(settings);
    }
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用阅读助手'),
              subtitle: const Text('默认关闭。关闭时阅读页不会请求任何模型。'),
              value: settings.enabled,
              onChanged: (value) {
                controller.update(settings.copyWith(enabled: value));
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: endpoint,
              decoration: const InputDecoration(
                labelText: '接口地址',
                hintText: 'http://127.0.0.1:11434/v1',
              ),
              onChanged: (value) {
                controller.update(settings.copyWith(endpoint: value));
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: model,
              decoration: const InputDecoration(
                labelText: '模型名称',
                hintText: 'llama3.1 或 gpt-4o-mini',
              ),
              onChanged: (value) {
                controller.update(settings.copyWith(model: value));
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: apiKey,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'API Key（可选）',
                hintText: '仅保存在本机',
              ),
              onChanged: (value) {
                controller.update(settings.copyWith(apiKey: value));
              },
            ),
            const SizedBox(height: 12),
            Text(
              '发送时会把当前摘录交给你配置的 OpenAI 兼容接口，例如本机 Ollama。不上整本书，也不上传书库。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
