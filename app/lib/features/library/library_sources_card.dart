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
  final s3Endpoint = TextEditingController();
  final s3Region = TextEditingController();
  final s3Bucket = TextEditingController();
  final s3Prefix = TextEditingController();
  final s3AccessKey = TextEditingController();
  final s3SecretKey = TextEditingController();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    folder.dispose();
    webdavUrl.dispose();
    webdavUser.dispose();
    webdavPassword.dispose();
    s3Endpoint.dispose();
    s3Region.dispose();
    s3Bucket.dispose();
    s3Prefix.dispose();
    s3AccessKey.dispose();
    s3SecretKey.dispose();
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => _run(() async {
                      final result = await syncLibraryFolder(
                        ref.read(libraryRepositoryProvider),
                        folder.text.trim(),
                      );
                      await applySourceImport(
                        ref.read(libraryProvider),
                        result,
                      );
                    }),
              child: Text(l10n.syncFolder),
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
            const SizedBox(height: 12),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: Text(l10n.s3CompatibleStorage),
              children: [
                TextField(
                  controller: s3Endpoint,
                  decoration: InputDecoration(labelText: l10n.s3Endpoint),
                ),
                TextField(
                  controller: s3Region,
                  decoration: InputDecoration(labelText: l10n.s3Region),
                ),
                TextField(
                  controller: s3Bucket,
                  decoration: InputDecoration(labelText: l10n.s3Bucket),
                ),
                TextField(
                  controller: s3Prefix,
                  decoration: InputDecoration(labelText: l10n.s3Prefix),
                ),
                TextField(
                  controller: s3AccessKey,
                  decoration: InputDecoration(labelText: l10n.s3AccessKey),
                ),
                TextField(
                  controller: s3SecretKey,
                  obscureText: true,
                  decoration: InputDecoration(labelText: l10n.s3SecretKey),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => _run(() async {
                          final result = await importLibraryS3(
                            ref.read(libraryRepositoryProvider),
                            endpoint: s3Endpoint.text,
                            region: s3Region.text,
                            bucket: s3Bucket.text,
                            prefix: s3Prefix.text,
                            accessKey: s3AccessKey.text,
                            secretKey: s3SecretKey.text,
                          );
                          await applySourceImport(
                            ref.read(libraryProvider),
                            result,
                          );
                        }),
                  child: Text(l10n.importFromS3),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: busy
                      ? null
                      : () => _run(() async {
                          final result = await syncLibraryS3(
                            ref.read(libraryRepositoryProvider),
                            endpoint: s3Endpoint.text,
                            region: s3Region.text,
                            bucket: s3Bucket.text,
                            prefix: s3Prefix.text,
                            accessKey: s3AccessKey.text,
                            secretKey: s3SecretKey.text,
                          );
                          await applySourceImport(
                            ref.read(libraryProvider),
                            result,
                          );
                        }),
                  child: Text(l10n.syncS3),
                ),
              ],
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
