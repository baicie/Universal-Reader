import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/http_library_repository.dart';
import 'core/library_controller.dart';
import 'core/locale_controller.dart';
import 'core/models.dart';
import 'core/providers.dart';
import 'core/reader_prefs.dart';
import 'features/reader/reader_page.dart';
import 'features/tools/ai/ai_runtime.dart';
import 'features/tools/ai/ai_settings.dart';
import 'features/tools/ai/ai_settings_card.dart';
import 'l10n/l10n.dart';
import 'widgets/eyebrow.dart';

export 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final repository = await resolveLibraryRepository(preferences);
  final aiSettings = SharedPreferencesAiSettingsRepository(preferences);
  final localeController = LocaleController(preferences);
  await localeController.load();
  final readerPrefs = ReaderPrefsController(preferences);
  await readerPrefs.load();
  final aiRuntime = await resolveAiRuntime(repository, preferences);
  runApp(
    ProviderScope(
      overrides: [
        libraryRepositoryProvider.overrideWithValue(repository),
        aiSettingsRepositoryProvider.overrideWithValue(aiSettings),
        localeProvider.overrideWith((ref) => localeController),
        readerPrefsProvider.overrideWith((ref) => readerPrefs),
        aiRuntimeProvider.overrideWithValue(aiRuntime),
      ],
      child: const UniversalReaderApp(),
    ),
  );
}

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
    final locales = ref.watch(localeProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      locale: locales.overrideLocale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeListResolutionCallback: (device, supported) {
        return resolveAppLocale(device, preference: locales.language);
      },
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

Future<void> importBooksWithFeedback(
  BuildContext context,
  WidgetRef ref,
) async {
  final outcome = await ref.read(libraryProvider).importFiles();
  if (!context.mounted || outcome.cancelled) return;
  final l10n = AppLocalizations.of(context);
  final message = outcome.count > 0
      ? l10n.importedBooks(outcome.count)
      : outcome.failed
      ? l10n.importFailed
      : l10n.noSupportedFormat;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
    final l10n = AppLocalizations.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return Scaffold(
      drawer: wide ? null : const LibraryDrawer(),
      appBar: AppBar(
        leading: wide
            ? null
            : Builder(
                builder: (context) => IconButton(
                  tooltip: l10n.openMenu,
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
                  hintText: l10n.searchHint,
                  onChanged: controller.search,
                ),
              ),
            ),
          IconButton(
            tooltip: l10n.settings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: wide
          ? null
          : FloatingActionButton(
              tooltip: l10n.importBooks,
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
    final l10n = AppLocalizations.of(context);
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
                      hintText: AppLocalizations.of(context).searchHint,
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
          SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyLibrary(
              title: controller.hasStoredDocuments
                  ? l10n.emptyLibraryFilteredTitle
                  : l10n.emptyLibraryTitle,
              subtitle: controller.hasStoredDocuments
                  ? l10n.emptyLibraryFilteredSubtitle
                  : controller.usesRemoteStore
                  ? l10n.emptyLibraryRemoteSubtitle
                  : l10n.emptyLibraryLocalSubtitle,
            ),
          )
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
    final l10n = AppLocalizations.of(context);
    final title = l10n.sectionTitle(controller.section);
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(
                controller.usesRemoteStore
                    ? l10n.libraryWithServer
                    : l10n.library,
              ),
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
                l10n.bookCount(controller.documents.length),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: l10n.toggleView,
          icon: Icon(controller.listView ? Icons.grid_view : Icons.view_list),
          onPressed: controller.toggleView,
        ),
        if (wide) ...[
          const SizedBox(width: 4),
          FilledButton.icon(
            onPressed: () => _import(context),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.importBooks),
          ),
        ],
      ],
    );
  }

  Widget _filters(PersistedLibraryController controller) {
    final l10n = AppLocalizations.of(context);
    final options = [
      ('all', l10n.all),
      ('reflow', l10n.reflow),
      ('fixedPage', l10n.fixedLayout),
      ('comic', l10n.comic),
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
            items: [
              DropdownMenuItem(value: 'recent', child: Text(l10n.sortRecent)),
              DropdownMenuItem(value: 'title', child: Text(l10n.sortTitle)),
              DropdownMenuItem(
                value: 'progress',
                child: Text(l10n.sortProgress),
              ),
            ],
            onChanged: (value) {
              if (value != null) controller.selectSort(value);
            },
          ),
        ),
      ],
    );
  }

  Future<void> _import(BuildContext context) =>
      importBooksWithFeedback(context, ref);
}

class ContinueCard extends ConsumerWidget {
  const ContinueCard({required this.document, super.key});
  final LibraryDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
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
                    Eyebrow(l10n.continueReading),
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
                      l10n.authorLabel(document.metadata.author),
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
                      label: Text(l10n.continueReading),
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
    final l10n = AppLocalizations.of(context);
    final items = [
      ('all', Icons.grid_view_outlined, l10n.all),
      ('reading', Icons.auto_stories_outlined, l10n.currentlyReading),
      ('favorites', Icons.favorite_border, l10n.favorites),
    ];
    final collections = [
      (const Color(0xFFC69355), l10n.collectionDesign),
      (const Color(0xFF6C9EB4), l10n.collectionTech),
    ];
    final nav = SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Eyebrow(l10n.browse),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Eyebrow(l10n.collections),
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
              onPressed: () => importBooksWithFeedback(context, ref),
              icon: const Icon(Icons.create_new_folder_outlined, size: 18),
              label: Text(l10n.importFolder),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.localFirstOffline,
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
    final l10n = AppLocalizations.of(context);
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
          l10n.authorLabel(metadata.author),
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
            AppLocalizations.of(context).authorLabel(metadata.author),
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
    required this.hintText,
    super.key,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search, size: 18),
      ),
    );
  }
}

class EmptyLibrary extends StatelessWidget {
  const EmptyLibrary({required this.title, required this.subtitle, super.key});
  final String title;
  final String subtitle;
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
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
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

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeProvider);
    final language = ref.watch(localeProvider).language;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final themeLabel = switch (mode) {
      ThemeMode.dark => l10n.themeDark,
      ThemeMode.light => l10n.themeLight,
      ThemeMode.system => l10n.themeSystem,
    };
    final languageLabel = switch (language) {
      AppLanguage.zh => l10n.languageChinese,
      AppLanguage.en => l10n.languageEnglish,
      AppLanguage.system => l10n.languageSystem,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
            children: [
              Eyebrow(l10n.preferences),
              const SizedBox(height: 8),
              Text(
                l10n.settings,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                l10n.appearance,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(l10n.theme),
                  subtitle: Text(themeLabel),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<ThemeMode>(
                      value: mode,
                      borderRadius: BorderRadius.circular(8),
                      items: [
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text(l10n.themeLight),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text(l10n.themeDark),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text(l10n.themeSystem),
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
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(l10n.language),
                  subtitle: Text(languageLabel),
                  trailing: DropdownButtonHideUnderline(
                    child: DropdownButton<AppLanguage>(
                      value: language,
                      borderRadius: BorderRadius.circular(8),
                      items: [
                        DropdownMenuItem(
                          value: AppLanguage.zh,
                          child: Text(l10n.languageChinese),
                        ),
                        DropdownMenuItem(
                          value: AppLanguage.en,
                          child: Text(l10n.languageEnglish),
                        ),
                        DropdownMenuItem(
                          value: AppLanguage.system,
                          child: Text(l10n.languageSystem),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          ref.read(localeProvider).setLanguage(value);
                        }
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                l10n.readingAssistant,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const AiSettingsCard(),
              const SizedBox(height: 28),
              Text(
                l10n.library,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(l10n.defaultImportLocation),
                      subtitle: Text(l10n.defaultImportLocationSubtitle),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.storage_outlined),
                      title: Text(l10n.localFirstStorage),
                      subtitle: Text(l10n.localFirstStorageSubtitle),
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
