import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import 'reader_bookmarks_pane.dart';

/// Top app bar for the reader page.
///
/// Exposes all chrome-toggle actions as plain callbacks so [ReaderPage] does
/// not need to own the widget tree for these buttons.
class ReaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ReaderAppBar({
    super.key,
    required this.title,
    required this.ask,
    required this.showSearch,
    required this.showNotes,
    required this.bookmarks,
    required this.toc,
    this.onAskToggle,
    this.onSearchToggle,
    this.onNotesToggle,
    this.onBookmarksToggle,
    this.onTocToggle,
    this.onAddBookmark,
    this.onOpenSettings,
    this.onBack,
  });

  final String title;
  final bool ask;
  final bool showSearch;
  final bool showNotes;
  final bool bookmarks;
  final bool toc;
  final VoidCallback? onAskToggle;
  final VoidCallback? onSearchToggle;
  final VoidCallback? onNotesToggle;
  final VoidCallback? onBookmarksToggle;
  final VoidCallback? onTocToggle;
  final VoidCallback? onAddBookmark;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final ink = theme.brightness == Brightness.dark
        ? Colors.white
        : Colors.black;

    return AppBar(
      leading: IconButton(
        tooltip: l10n.backToLibrary,
        icon: const Icon(Icons.arrow_back),
        onPressed: onBack,
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        IconButton(
          tooltip: l10n.askThisPage,
          icon: Icon(
            ask ? Icons.chat_bubble : Icons.chat_bubble_outline,
            color: ask ? accent : ink,
          ),
          onPressed: onAskToggle,
        ),
        IconButton(
          tooltip: l10n.searchInBook,
          icon: Icon(
            Icons.search,
            color: showSearch ? accent : ink,
          ),
          onPressed: onSearchToggle,
        ),
        IconButton(
          tooltip: l10n.notesTitle,
          icon: Icon(
            showNotes ? Icons.sticky_note_2 : Icons.sticky_note_2_outlined,
            color: showNotes ? accent : ink,
          ),
          onPressed: onNotesToggle,
        ),
        IconButton(
          key: addBookmarkButtonKey,
          tooltip: l10n.addBookmark,
          icon: const Icon(Icons.bookmark_add_outlined),
          onPressed: onAddBookmark,
        ),
        IconButton(
          tooltip: l10n.bookmarks,
          icon: Icon(
            bookmarks ? Icons.bookmarks : Icons.bookmarks_outlined,
            color: bookmarks ? accent : ink,
          ),
          onPressed: onBookmarksToggle,
        ),
        IconButton(
          tooltip: l10n.tableOfContents,
          icon: Icon(
            toc ? Icons.menu_book : Icons.menu_book_outlined,
            color: toc ? accent : ink,
          ),
          onPressed: onTocToggle,
        ),
        IconButton(
          tooltip: l10n.readingSettings,
          icon: const Icon(Icons.text_fields),
          onPressed: onOpenSettings,
        ),
      ],
    );
  }
}
