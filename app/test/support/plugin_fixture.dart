import 'package:app/core/models.dart';
import 'package:app/features/reader/reader_adapter_registry.dart';
import 'package:app/features/reader/reader_plugin.dart';

class RtfCompatibilityPlugin implements ReaderPlugin {
  const RtfCompatibilityPlugin();

  @override
  ReaderPluginManifest get manifest => ReaderPluginManifest(
    id: 'io.universalreader.compat.rtf',
    name: 'RTF Compatibility Fixture',
    version: '1.0.0',
    apiVersion: readerPluginApiVersion,
    formats: const {DocumentFormat.rtf},
  );

  @override
  List<ReaderFormatAdapter> get adapters => const [RtfFormatAdapter()];
}
