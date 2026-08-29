import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/library_controller.dart';
import '../../core/library_repository.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../l10n/l10n.dart';
import 'shelf_store.dart';

Future<void> confirmAndDeleteBook(
  BuildContext context,
  WidgetRef ref,
  String documentId,
) async {
  final controller = ref.read(libraryProvider);
  final document = controller.documentById(documentId);
  if (document == null) return;
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(l10n.deleteFromLibrary),
        content: Text(l10n.deleteBookConfirm(document.metadata.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancelAction),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.confirmDelete),
          ),
        ],
      );
    },
  );
  if (confirmed == true) await controller.deleteDocument(documentId);
}

Future<void> showEditBookIdentityDialog(
  BuildContext context,
  WidgetRef ref,
  String documentId,
) async {
  final controller = ref.read(libraryProvider);
  final document = controller.documentById(documentId);
  if (document == null) return;
  await showDialog<void>(
    context: context,
    builder: (context) =>
        _EditBookIdentityDialog(controller: controller, document: document),
  );
}

class _EditBookIdentityDialog extends StatefulWidget {
  const _EditBookIdentityDialog({
    required this.controller,
    required this.document,
  });

  final PersistedLibraryController controller;
  final LibraryDocument document;

  @override
  State<_EditBookIdentityDialog> createState() =>
      _EditBookIdentityDialogState();
}

class _EditBookIdentityDialogState extends State<_EditBookIdentityDialog> {
  late final TextEditingController title;
  late final TextEditingController author;

  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.document.metadata.title);
    author = TextEditingController(text: widget.document.metadata.author);
  }

  @override
  void dispose() {
    title.dispose();
    author.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await widget.controller.writeIdentity(
      id: widget.document.metadata.id,
      title: title.text,
      author: author.text,
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.editBookIdentity),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const Key('edit-book-title'),
            controller: title,
            autofocus: true,
            maxLength: maxBookIdentityLength,
            decoration: InputDecoration(labelText: l10n.bookTitleLabel),
            onSubmitted: (_) => _submit(),
          ),
          TextField(
            key: const Key('edit-book-author'),
            controller: author,
            maxLength: maxBookIdentityLength,
            decoration: InputDecoration(labelText: l10n.bookAuthorLabel),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancelAction),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.saveAction)),
      ],
    );
  }
}

Future<LibraryCollection?> showCreateCollectionDialog(
  BuildContext context,
  WidgetRef ref,
) {
  final controller = ref.read(libraryProvider);
  return showDialog<LibraryCollection>(
    context: context,
    builder: (context) => _CreateCollectionDialog(controller: controller),
  );
}

class _CreateCollectionDialog extends StatefulWidget {
  const _CreateCollectionDialog({required this.controller});

  final PersistedLibraryController controller;

  @override
  State<_CreateCollectionDialog> createState() =>
      _CreateCollectionDialogState();
}

class _CreateCollectionDialogState extends State<_CreateCollectionDialog> {
  final name = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final created = await widget.controller.createCollection(name.text);
    if (mounted) Navigator.pop(context, created);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.newCollection),
      content: TextField(
        controller: name,
        autofocus: true,
        maxLength: maxCollectionName,
        decoration: InputDecoration(hintText: l10n.collectionNameHint),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancelAction),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.createCollection)),
      ],
    );
  }
}

class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    required this.documentId,
    this.onCover = false,
    super.key,
  });

  final String documentId;
  final bool onCover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(libraryProvider);
    final l10n = AppLocalizations.of(context);
    final favorite = controller.isFavorite(documentId);
    final button = IconButton(
      tooltip: favorite ? l10n.removeFromFavorites : l10n.addToFavorites,
      visualDensity: VisualDensity.compact,
      iconSize: 18,
      color: onCover
          ? Colors.white
          : favorite
          ? Theme.of(context).colorScheme.error
          : Theme.of(context).colorScheme.onSurfaceVariant,
      icon: Icon(favorite ? Icons.favorite : Icons.favorite_border),
      onPressed: () => controller.toggleFavorite(documentId),
    );
    if (!onCover) return button;
    return Material(
      color: const Color(0x66000000),
      shape: const CircleBorder(),
      child: button,
    );
  }
}

class BookActionsButton extends ConsumerWidget {
  const BookActionsButton({
    required this.documentId,
    this.onCover = false,
    super.key,
  });

  final String documentId;
  final bool onCover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(libraryProvider);
    final l10n = AppLocalizations.of(context);
    final menu = PopupMenuButton<String>(
      tooltip: l10n.bookActions,
      padding: EdgeInsets.zero,
      icon: Icon(
        Icons.more_vert,
        size: 18,
        color: onCover
            ? Colors.white
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      onSelected: (value) async {
        if (value == 'edit-identity') {
          await showEditBookIdentityDialog(context, ref, documentId);
          return;
        }
        if (value == 'new') {
          final created = await showCreateCollectionDialog(context, ref);
          if (created != null) {
            await controller.addToCollection(created.id, documentId);
          }
          return;
        }
        if (value == 'delete-book') {
          await confirmAndDeleteBook(context, ref, documentId);
          return;
        }
        await controller.toggleInCollection(value, documentId);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit-identity',
          child: Text(l10n.editBookIdentity),
        ),
        for (final collection in controller.collections)
          PopupMenuItem(
            value: collection.id,
            child: Text(
              controller.isInCollection(collection.id, documentId)
                  ? l10n.removeFromNamedCollection(collection.name)
                  : l10n.addToNamedCollection(collection.name),
            ),
          ),
        PopupMenuItem(value: 'new', child: Text(l10n.newCollection)),
        PopupMenuItem(
          value: 'delete-book',
          child: Text(l10n.deleteFromLibrary),
        ),
      ],
    );
    if (!onCover) return menu;
    return Material(
      color: const Color(0x66000000),
      shape: const CircleBorder(),
      child: menu,
    );
  }
}
