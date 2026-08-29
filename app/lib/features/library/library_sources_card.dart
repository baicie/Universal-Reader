import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../l10n/l10n.dart';
import 'library_sources.dart';

class LibrarySourcesCard extends ConsumerStatefulWidget {
  const LibrarySourcesCard({super.key});

  @override
  ConsumerState<LibrarySourcesCard> createState() => _LibrarySourcesCardState();
}

class _LibrarySourcesCardState extends ConsumerState<LibrarySourcesCard> {
  final folder = TextEditingController();
  final webdavUrl = TextEditingController();
  final webdavUser = TextEditingController();
  final webdavPassword = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    folder.dispose();
    webdavUrl.dispose();
    webdavUser.dispose();
    webdavPassword.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final library = ref.watch(libraryProvider);
    if (!library.usesRemoteStore) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.librarySources, style: theme.textTheme.titleSmall),
            const SizedBox(height: 12),
            TextField(
              controller: folder,
              decoration: InputDecoration(
                labelText: l10n.scanFolder,
                hintText: l10n.scanFolderHint,
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => _run(() async {
                      final result = await scanLibraryFolder(
                        ref.read(libraryRepositoryProvider),
                        folder.text.trim(),
                      );
                      await applySourceImport(
                        ref.read(libraryProvider),
                        result,
                      );
                    }),
              child: Text(l10n.scanFolder),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => _run(() async {
                      await watchLibraryFolder(
                        ref.read(libraryRepositoryProvider),
                        folder.text.trim(),
                      );
                    }),
              child: Text(l10n.watchFolder),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: webdavUrl,
              decoration: InputDecoration(labelText: l10n.webdavUrl),
            ),
            TextField(
              controller: webdavUser,
              decoration: InputDecoration(labelText: l10n.webdavUser),
            ),
            TextField(
              controller: webdavPassword,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.webdavPassword),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => _run(() async {
                      final result = await importLibraryWebDav(
                        ref.read(libraryRepositoryProvider),
                        baseUrl: webdavUrl.text,
                        username: webdavUser.text,
                        password: webdavPassword.text,
                      );
                      await applySourceImport(
                        ref.read(libraryProvider),
                        result,
                      );
                    }),
              child: Text(l10n.importFromWebdav),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => _run(() async {
                      final result = await syncLibraryWebDav(
                        ref.read(libraryRepositoryProvider),
                        baseUrl: webdavUrl.text,
                        username: webdavUser.text,
                        password: webdavPassword.text,
                      );
                      await applySourceImport(
                        ref.read(libraryProvider),
                        result,
                      );
                    }),
              child: Text(l10n.syncWebdav),
            ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Text(
                error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
