import 'package:flutter/material.dart';

import '../../core/foliate_session.dart';
import '../../core/reader_runtime.dart';
import '../../core/reflow_nav.dart';
import '../../l10n/l10n.dart';
import '../../widgets/eyebrow.dart';
import '../library/annotation_store.dart';
import 'reader_bookmarks.dart';
import 'reader_bookmarks_pane.dart';
import 'reader_notes_pane.dart';
import 'reader_search_pane.dart';

/// Side panel shown while a reader side panel is open.
///
/// Stacks the search, notes, bookmarks and table-of-contents panes as a
/// single scrollable column, hiding the panes whose toggle is off.
class ReaderSidePanel extends StatelessWidget {
  const ReaderSidePanel({
    super.key,
    required this.background,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.showSearch,
    required this.showNotes,
    required this.showBookmarks,
    required this.showToc,
    required this.searchQuery,
    required this.searchHits,
    required this.notes,
    required this.tocItems,
    required this.currentHref,
    required this.currentFragment,
    required this.currentIndex,
    required this.foliateSession,
    required this.onSearchQuery,
    required this.onSearchOpen,
    required this.onNoteOpen,
    required this.onNoteDelete,
    required this.onBookmarkOpen,
    required this.onBookmarkDelete,
    required this.onTocOpen,
  });

  final Color background;
  final Color ink;
  final Color muted;
  final Color accent;

  final bool showSearch;
  final bool showNotes;
  final bool showBookmarks;
  final bool showToc;

  final String searchQuery;
  final List<SearchResult> searchHits;
  final List<ReaderAnnotation> notes;
  final List<TocItem> tocItems;
  final String currentHref;
  final String? currentFragment;
  final int currentIndex;
  final FoliateSession? foliateSession;

  final ValueChanged<String> onSearchQuery;
  final ValueChanged<SearchResult> onSearchOpen;
  final ValueChanged<ReaderAnnotation> onNoteOpen;
  final ValueChanged<ReaderAnnotation> onNoteDelete;
  final ValueChanged<ReaderAnnotation> onBookmarkOpen;
  final ValueChanged<ReaderAnnotation> onBookmarkDelete;
  final ValueChanged<TocItem> onTocOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Material(
      color: background,
      child: GestureDetector(
        onTap: () {},
        child: SizedBox(
          width: 240,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 16, 24),
            children: [
              if (showSearch) ...[
                ReaderSearchPane(
                  title: l10n.searchInBook,
                  hint: l10n.searchInBookHint,
                  emptyLabel: l10n.noSearchResults,
                  query: searchQuery,
                  hits: searchHits,
                  onQuery: onSearchQuery,
                  onOpen: onSearchOpen,
                ),
                if (showNotes || showBookmarks || showToc)
                  const SizedBox(height: 28),
              ],
              if (showNotes) ...[
                ReaderNotesPane(
                  title: l10n.notesTitle,
                  emptyLabel: l10n.noNotes,
                  deleteLabel: l10n.deleteNote,
                  notes: notesOf(notes),
                  onOpen: onNoteOpen,
                  onDelete: onNoteDelete,
                ),
                if (showBookmarks || showToc) const SizedBox(height: 28),
              ],
              if (showBookmarks) ...[
                ReaderBookmarksPane(
                  title: l10n.bookmarks,
                  emptyLabel: l10n.noBookmarks,
                  deleteLabel: l10n.deleteBookmark,
                  bookmarks: bookmarksOf(notes),
                  onOpen: onBookmarkOpen,
                  onDelete: onBookmarkDelete,
                ),
                if (showToc) const SizedBox(height: 28),
              ],
              if (showToc) ...[
                Eyebrow(l10n.tableOfContents),
                const SizedBox(height: 12),
                if (tocItems.isEmpty)
                  Text(
                    l10n.untitledSection,
                    style: TextStyle(color: muted, height: 1.4),
                  )
                else
                  ..._tocTiles(
                    l10n: l10n,
                    items: tocItems,
                    currentIndex: currentIndex,
                    currentHref: currentHref,
                    currentFragment: currentFragment,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _tocTiles({
    required AppLocalizations l10n,
    required List<TocItem> items,
    required int currentIndex,
    required String currentHref,
    String? currentFragment,
    int depth = 0,
  }) {
    final tiles = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final current = currentHref.isEmpty
          ? depth == 0 && i == currentIndex
          : reflowTocItemCurrent(
              item,
              href: currentHref,
              fragment: currentFragment,
            );
      tiles.add(
        Padding(
          padding: EdgeInsets.fromLTRB(depth * 12.0, 6, 0, 6),
          child: InkWell(
            onTap: () => onTocOpen(item),
            child: Text(
              item.title.trim().isEmpty ? l10n.untitledSection : item.title,
              style: TextStyle(
                fontWeight: current ? FontWeight.w700 : FontWeight.w400,
                color: current ? accent : ink,
                height: 1.4,
              ),
            ),
          ),
        ),
      );
      if (item.children.isNotEmpty) {
        tiles.addAll(
          _tocTiles(
            l10n: l10n,
            items: item.children,
            currentIndex: currentIndex,
            currentHref: currentHref,
            currentFragment: currentFragment,
            depth: depth + 1,
          ),
        );
      }
    }
    return tiles;
  }
}
