import '../../core/models.dart';
import 'reader_adapter_registry.dart';

const readerPluginManifestVersion = 1;
const readerPluginApiVersion = 1;

final _pluginIdPattern = RegExp(r'^[a-z][a-z0-9]*(?:[.-][a-z0-9][a-z0-9-]*)+$');
final _versionPattern = RegExp(r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$');

enum ReaderPluginIssueCode {
  incompatibleManifestVersion,
  incompatibleApiVersion,
  invalidPluginId,
  invalidVersion,
  invalidName,
  invalidFormats,
  duplicatePluginId,
  duplicateAdapterId,
  formatConflict,
  adapterContractMismatch,
  adapterFailure,
}

class ReaderPluginIssue {
  const ReaderPluginIssue({
    required this.pluginId,
    required this.code,
    required this.message,
  });

  final String pluginId;
  final ReaderPluginIssueCode code;
  final String message;

  @override
  String toString() => '$pluginId: ${code.name}: $message';
}

class ReaderPluginManifest {
  ReaderPluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.apiVersion,
    required Set<DocumentFormat> formats,
    this.manifestVersion = readerPluginManifestVersion,
  }) : formats = Set.unmodifiable(formats);

  factory ReaderPluginManifest.fromJson(Map<String, Object?> json) {
    final manifestVersion = json['manifestVersion'];
    final id = json['id'];
    final name = json['name'];
    final version = json['version'];
    final apiVersion = json['apiVersion'];
    final rawFormats = json['formats'];
    if (manifestVersion is! int ||
        id is! String ||
        name is! String ||
        version is! String ||
        apiVersion is! int ||
        rawFormats is! List) {
      throw const FormatException('Invalid reader plugin manifest.');
    }
    final formats = <DocumentFormat>{};
    for (final rawFormat in rawFormats) {
      if (rawFormat is! String) {
        throw const FormatException('Plugin formats must be strings.');
      }
      final format = DocumentFormat.values
          .where((candidate) => candidate.name == rawFormat)
          .firstOrNull;
      if (format == null || format == DocumentFormat.unknown) {
        throw FormatException('Unsupported plugin format: $rawFormat');
      }
      formats.add(format);
    }
    return ReaderPluginManifest(
      manifestVersion: manifestVersion,
      id: id,
      name: name,
      version: version,
      apiVersion: apiVersion,
      formats: formats,
    );
  }

  final int manifestVersion;
  final String id;
  final String name;
  final String version;
  final int apiVersion;
  final Set<DocumentFormat> formats;

  Map<String, Object> toJson() {
    return {
      'manifestVersion': manifestVersion,
      'id': id,
      'name': name,
      'version': version,
      'apiVersion': apiVersion,
      'formats': formats.map((format) => format.name).toList()..sort(),
    };
  }
}

abstract interface class ReaderPlugin {
  ReaderPluginManifest get manifest;
  List<ReaderFormatAdapter> get adapters;
}

class ReaderPluginHost {
  factory ReaderPluginHost({
    ReaderAdapterRegistry? base,
    Iterable<ReaderPlugin> plugins = const [],
  }) {
    return _compose(base ?? ReaderAdapterRegistry.standard, plugins);
  }

  ReaderPluginHost._({
    required this.registry,
    required List<ReaderPluginIssue> issues,
    required Set<String> acceptedPluginIds,
  }) : issues = List.unmodifiable(issues),
       acceptedPluginIds = Set.unmodifiable(acceptedPluginIds);

  final ReaderAdapterRegistry registry;
  final List<ReaderPluginIssue> issues;
  final Set<String> acceptedPluginIds;

  static ReaderPluginHost _compose(
    ReaderAdapterRegistry base,
    Iterable<ReaderPlugin> plugins,
  ) {
    final issues = <ReaderPluginIssue>[];
    final acceptedPluginIds = <String>{};
    final acceptedAdapters = <ReaderFormatAdapter>[...base.adapters];
    final adapterIds = <String>{
      for (final adapter in base.adapters) adapter.id,
    };
    final byFormat = <DocumentFormat, ReaderFormatAdapter>{
      for (final adapter in base.adapters)
        for (final format in adapter.formats) format: adapter,
    };

    for (final plugin in plugins) {
      final manifest = plugin.manifest;
      final pluginId = manifest.id.trim().isEmpty ? '<unknown>' : manifest.id;

      final manifestIssue = _validateManifest(manifest);
      if (manifestIssue != null) {
        issues.add(
          ReaderPluginIssue(
            pluginId: pluginId,
            code: manifestIssue.$1,
            message: manifestIssue.$2,
          ),
        );
        continue;
      }
      if (!acceptedPluginIds.add(manifest.id)) {
        issues.add(
          ReaderPluginIssue(
            pluginId: manifest.id,
            code: ReaderPluginIssueCode.duplicatePluginId,
            message: 'A plugin with this id is already registered.',
          ),
        );
        continue;
      }

      late final List<ReaderFormatAdapter> adapters;
      try {
        adapters = List.unmodifiable(plugin.adapters);
      } catch (error) {
        acceptedPluginIds.remove(manifest.id);
        issues.add(
          ReaderPluginIssue(
            pluginId: manifest.id,
            code: ReaderPluginIssueCode.adapterFailure,
            message: 'Could not create plugin adapters: $error',
          ),
        );
        continue;
      }

      final pluginAdapterIds = <String>{};
      final pluginFormats = <DocumentFormat>{};
      ReaderPluginIssue? adapterIssue;
      for (final adapter in adapters) {
        if (adapter.id.trim().isEmpty ||
            adapterIds.contains(adapter.id) ||
            !pluginAdapterIds.add(adapter.id)) {
          adapterIssue = ReaderPluginIssue(
            pluginId: manifest.id,
            code: ReaderPluginIssueCode.duplicateAdapterId,
            message: 'Adapter id "${adapter.id}" is empty or already used.',
          );
          break;
        }
        final conflicts = adapter.formats.where(byFormat.containsKey).toList();
        if (conflicts.isNotEmpty) {
          adapterIssue = ReaderPluginIssue(
            pluginId: manifest.id,
            code: ReaderPluginIssueCode.formatConflict,
            message:
                'Adapter "${adapter.id}" conflicts for: '
                '${conflicts.map((format) => format.name).join(', ')}.',
          );
          break;
        }
        pluginFormats.addAll(adapter.formats);
      }
      if (adapterIssue != null) {
        acceptedPluginIds.remove(manifest.id);
        issues.add(adapterIssue);
        continue;
      }
      if (adapters.isEmpty || !_sameFormats(pluginFormats, manifest.formats)) {
        acceptedPluginIds.remove(manifest.id);
        issues.add(
          ReaderPluginIssue(
            pluginId: manifest.id,
            code: ReaderPluginIssueCode.adapterContractMismatch,
            message:
                'Manifest formats ${manifest.formats.map((e) => e.name)} '
                'do not match adapter formats '
                '${pluginFormats.map((e) => e.name)}.',
          ),
        );
        continue;
      }

      acceptedAdapters.addAll(adapters);
      adapterIds.addAll(pluginAdapterIds);
      for (final adapter in adapters) {
        for (final format in adapter.formats) {
          byFormat[format] = adapter;
        }
      }
    }

    return ReaderPluginHost._(
      registry: ReaderAdapterRegistry(acceptedAdapters),
      issues: issues,
      acceptedPluginIds: acceptedPluginIds,
    );
  }

  static (ReaderPluginIssueCode, String)? _validateManifest(
    ReaderPluginManifest manifest,
  ) {
    if (manifest.manifestVersion != readerPluginManifestVersion) {
      return (
        ReaderPluginIssueCode.incompatibleManifestVersion,
        'Manifest version ${manifest.manifestVersion} is not supported; '
            'expected $readerPluginManifestVersion.',
      );
    }
    if (manifest.apiVersion != readerPluginApiVersion) {
      return (
        ReaderPluginIssueCode.incompatibleApiVersion,
        'Plugin API version ${manifest.apiVersion} is not supported; '
            'expected $readerPluginApiVersion.',
      );
    }
    if (!_pluginIdPattern.hasMatch(manifest.id)) {
      return (
        ReaderPluginIssueCode.invalidPluginId,
        'Plugin id must use lowercase reverse-domain syntax.',
      );
    }
    if (!_versionPattern.hasMatch(manifest.version)) {
      return (
        ReaderPluginIssueCode.invalidVersion,
        'Plugin version must use semantic version syntax.',
      );
    }
    if (manifest.name.trim().isEmpty) {
      return (
        ReaderPluginIssueCode.invalidName,
        'Plugin name must not be empty.',
      );
    }
    if (manifest.formats.isEmpty ||
        manifest.formats.contains(DocumentFormat.unknown)) {
      return (
        ReaderPluginIssueCode.invalidFormats,
        'Plugin manifest must declare supported formats.',
      );
    }
    return null;
  }

  static bool _sameFormats(
    Set<DocumentFormat> left,
    Set<DocumentFormat> right,
  ) {
    return left.length == right.length && left.containsAll(right);
  }
}
