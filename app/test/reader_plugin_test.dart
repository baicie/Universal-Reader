import 'package:app/core/models.dart';
import 'package:app/core/reader_runtime.dart';
import 'package:app/core/rtf_document.dart';
import 'package:app/core/text_document.dart';
import 'package:app/features/reader/reader_adapter_registry.dart';
import 'package:app/features/reader/reader_plugin.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/plugin_fixture.dart';
import 'support/rtf_fixture.dart';

class _Plugin implements ReaderPlugin {
  const _Plugin({required this.manifest, required this.adapters});

  @override
  final ReaderPluginManifest manifest;

  @override
  final List<ReaderFormatAdapter> adapters;
}

class _ThrowingPlugin implements ReaderPlugin {
  const _ThrowingPlugin();

  @override
  ReaderPluginManifest get manifest => ReaderPluginManifest(
    id: 'io.universalreader.broken',
    name: 'Broken',
    version: '1.0.0',
    apiVersion: readerPluginApiVersion,
    formats: const {DocumentFormat.rtf},
  );

  @override
  List<ReaderFormatAdapter> get adapters => throw StateError('broken plugin');
}

class _ConflictRtfAdapter extends ReaderFormatAdapter {
  const _ConflictRtfAdapter()
    : super(
        id: 'io.universalreader.compat.conflict-rtf',
        formats: const {DocumentFormat.rtf},
      );

  @override
  ReaderDocument openSync(DocumentSource source) => RtfReaderDocument.parse(
    metadata: metadataFor(source),
    bytes: source.bytes!,
  );
}

class _ChmCompatibilityAdapter extends ReaderFormatAdapter {
  const _ChmCompatibilityAdapter()
    : super(
        id: 'io.universalreader.compat.chm',
        formats: const {DocumentFormat.chm},
      );

  @override
  ReaderDocument openSync(DocumentSource source) => TextReaderDocument.parse(
    metadata: metadataFor(source),
    bytes: source.bytes!,
  );
}

void main() {
  final base = ReaderAdapterRegistry(const [TextFormatAdapter()]);

  test('manifest JSON freezes the public plugin fields', () {
    final manifest = RtfCompatibilityPlugin().manifest;

    expect(manifest.toJson(), {
      'manifestVersion': readerPluginManifestVersion,
      'id': 'io.universalreader.compat.rtf',
      'name': 'RTF Compatibility Fixture',
      'version': '1.0.0',
      'apiVersion': readerPluginApiVersion,
      'formats': ['rtf'],
    });
    expect(
      ReaderPluginManifest.fromJson(manifest.toJson()).toJson(),
      manifest.toJson(),
    );
  });

  test('manifest rejects unknown formats and invalid JSON types', () {
    expect(
      () => ReaderPluginManifest.fromJson({
        'manifestVersion': 1,
        'id': 'io.universalreader.bad',
        'name': 'Bad',
        'version': '1.0.0',
        'apiVersion': 1,
        'formats': ['not-a-format'],
      }),
      throwsFormatException,
    );
    expect(
      () => ReaderPluginManifest.fromJson({
        'manifestVersion': '1',
        'id': 'io.universalreader.bad',
        'name': 'Bad',
        'version': '1.0.0',
        'apiVersion': 1,
        'formats': ['rtf'],
      }),
      throwsFormatException,
    );
  });

  test('invalid manifest metadata is isolated with a precise issue', () {
    final cases = <(ReaderPluginManifest, ReaderPluginIssueCode)>[
      (
        ReaderPluginManifest(
          manifestVersion: readerPluginManifestVersion + 1,
          id: 'io.universalreader.future',
          name: 'Future',
          version: '1.0.0',
          apiVersion: readerPluginApiVersion,
          formats: const {DocumentFormat.rtf},
        ),
        ReaderPluginIssueCode.incompatibleManifestVersion,
      ),
      (
        ReaderPluginManifest(
          id: 'Invalid Id',
          name: 'Bad id',
          version: '1.0.0',
          apiVersion: readerPluginApiVersion,
          formats: const {DocumentFormat.rtf},
        ),
        ReaderPluginIssueCode.invalidPluginId,
      ),
      (
        ReaderPluginManifest(
          id: 'io.universalreader.bad-version',
          name: 'Bad version',
          version: 'v1',
          apiVersion: readerPluginApiVersion,
          formats: const {DocumentFormat.rtf},
        ),
        ReaderPluginIssueCode.invalidVersion,
      ),
      (
        ReaderPluginManifest(
          id: 'io.universalreader.no-name',
          name: ' ',
          version: '1.0.0',
          apiVersion: readerPluginApiVersion,
          formats: const {DocumentFormat.rtf},
        ),
        ReaderPluginIssueCode.invalidName,
      ),
      (
        ReaderPluginManifest(
          id: 'io.universalreader.no-formats',
          name: 'No formats',
          version: '1.0.0',
          apiVersion: readerPluginApiVersion,
          formats: const {},
        ),
        ReaderPluginIssueCode.invalidFormats,
      ),
    ];

    for (final (manifest, expectedCode) in cases) {
      final host = ReaderPluginHost(
        base: base,
        plugins: [
          _Plugin(manifest: manifest, adapters: const [RtfFormatAdapter()]),
        ],
      );
      expect(host.issues.single.code, expectedCode);
    }
  });

  test('compatible plugin registers and opens its format', () async {
    final host = ReaderPluginHost(
      base: base,
      plugins: const [RtfCompatibilityPlugin()],
    );

    expect(host.issues, isEmpty);
    expect(host.acceptedPluginIds, {'io.universalreader.compat.rtf'});
    expect(
      host.registry.formats,
      containsAll({DocumentFormat.txt, DocumentFormat.rtf}),
    );
    final document = await host.registry.open(
      metadata: const DocumentMetadata(
        id: 'plugged.rtf',
        title: 'Plugged',
        author: '',
        format: DocumentFormat.rtf,
        type: DocumentType.reflow,
      ),
      bytes: minimalRtfBytes(),
    );
    expect(document, isA<RtfReaderDocument>());
  });

  test('plugin can fill a format missing from the standard registry', () async {
    final host = ReaderPluginHost(
      plugins: [
        _Plugin(
          manifest: ReaderPluginManifest(
            id: 'io.universalreader.compat.chm',
            name: 'CHM Compatibility Fixture',
            version: '1.0.0',
            apiVersion: readerPluginApiVersion,
            formats: const {DocumentFormat.chm},
          ),
          adapters: const [_ChmCompatibilityAdapter()],
        ),
      ],
    );

    expect(host.issues, isEmpty);
    expect(host.registry.formats, contains(DocumentFormat.chm));
    final document = await host.registry.open(
      metadata: const DocumentMetadata(
        id: 'plugged.chm',
        title: 'Plugged CHM',
        author: '',
        format: DocumentFormat.chm,
        type: DocumentType.fixedPage,
      ),
      bytes: const [1, 2, 3],
    );
    expect(document, isA<TextReaderDocument>());
  });

  test('incompatible plugin API version is isolated', () {
    final host = ReaderPluginHost(
      base: base,
      plugins: [
        _Plugin(
          manifest: ReaderPluginManifest(
            id: 'io.universalreader.old',
            name: 'Old',
            version: '1.0.0',
            apiVersion: readerPluginApiVersion + 1,
            formats: const {DocumentFormat.rtf},
          ),
          adapters: const [RtfFormatAdapter()],
        ),
      ],
    );

    expect(host.registry.formats, base.formats);
    expect(
      host.issues.single.code,
      ReaderPluginIssueCode.incompatibleApiVersion,
    );
  });

  test('duplicate plugin id and adapter id are rejected independently', () {
    final duplicatePlugin = ReaderPluginHost(
      base: base,
      plugins: const [RtfCompatibilityPlugin(), RtfCompatibilityPlugin()],
    );
    expect(
      duplicatePlugin.issues.single.code,
      ReaderPluginIssueCode.duplicatePluginId,
    );

    final duplicateAdapter = ReaderPluginHost(
      base: base,
      plugins: [
        _Plugin(
          manifest: ReaderPluginManifest(
            id: 'io.universalreader.duplicate',
            name: 'Duplicate',
            version: '1.0.0',
            apiVersion: readerPluginApiVersion,
            formats: const {DocumentFormat.rtf},
          ),
          adapters: const [TextFormatAdapter()],
        ),
      ],
    );
    expect(
      duplicateAdapter.issues.single.code,
      ReaderPluginIssueCode.duplicateAdapterId,
    );
  });

  test('format conflicts and adapter contract mismatches are rejected', () {
    final conflict = ReaderPluginHost(
      base: ReaderAdapterRegistry.standard,
      plugins: [
        _Plugin(
          manifest: ReaderPluginManifest(
            id: 'io.universalreader.conflict',
            name: 'Conflict',
            version: '1.0.0',
            apiVersion: readerPluginApiVersion,
            formats: const {DocumentFormat.rtf},
          ),
          adapters: const [_ConflictRtfAdapter()],
        ),
      ],
    );
    expect(conflict.issues.single.code, ReaderPluginIssueCode.formatConflict);

    final mismatch = ReaderPluginHost(
      base: base,
      plugins: [
        _Plugin(
          manifest: ReaderPluginManifest(
            id: 'io.universalreader.mismatch',
            name: 'Mismatch',
            version: '1.0.0',
            apiVersion: readerPluginApiVersion,
            formats: const {DocumentFormat.txt},
          ),
          adapters: const [RtfFormatAdapter()],
        ),
      ],
    );
    expect(
      mismatch.issues.single.code,
      ReaderPluginIssueCode.adapterContractMismatch,
    );
  });

  test('throwing plugin does not affect the base registry', () {
    final host = ReaderPluginHost(
      base: base,
      plugins: const [_ThrowingPlugin()],
    );

    expect(host.registry.formats, base.formats);
    expect(host.issues.single.code, ReaderPluginIssueCode.adapterFailure);
  });
}
