import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import 'format_detector.dart';
import 'models.dart';

const _imageSuffixes = ['.png', '.jpg', '.jpeg', '.webp', '.gif'];

List<int>? extractCover({required String fileName, required List<int> bytes}) {
  final format = const FormatDetector().detect(
    DocumentSource(name: fileName, bytes: bytes),
  );
  try {
    return switch (format) {
      DocumentFormat.epub => _epubCover(bytes),
      DocumentFormat.fb2 => _fb2Cover(bytes),
      DocumentFormat.cbz || DocumentFormat.cbr => _zipFirstImage(bytes),
      _ => null,
    };
  } catch (_) {
    // 封面失败不能挡住导入；没有封面就继续用颜色块。
    return null;
  }
}

bool looksLikeImageName(String name) {
  final lower = name.replaceAll('\\', '/').split('/').last.toLowerCase();
  if (lower.startsWith('.') || name.contains('__macosx')) return false;
  return _imageSuffixes.any(lower.endsWith);
}

List<int>? _epubCover(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final files = <String, ArchiveFile>{};
  for (final file in archive) {
    if (file.isFile) {
      files[_normalize(file.name)] = file;
    }
  }
  final container = _xml(_read(files, 'meta-inf/container.xml'));
  final rootPath = container.descendants
      .whereType<XmlElement>()
      .where((element) => element.name.local == 'rootfile')
      .map((element) => element.getAttribute('full-path'))
      .whereType<String>()
      .where((value) => value.isNotEmpty)
      .firstOrNull;
  if (rootPath == null) return _zipFirstImage(bytes);
  final opfPath = _normalize(rootPath);
  final opf = _xml(_read(files, opfPath));
  String? href;
  for (final meta in opf.descendants.whereType<XmlElement>()) {
    if (meta.name.local == 'meta' && meta.getAttribute('name') == 'cover') {
      final id = meta.getAttribute('content');
      href = _manifestHref(opf, opfPath, id: id);
    }
  }
  href ??= _manifestHref(opf, opfPath, coverProperty: true);
  if (href != null) {
    final file = files[_normalize(href)];
    if (file != null) return List<int>.from(file.content as List<int>);
  }
  return _zipFirstImage(bytes);
}

String? _manifestHref(
  XmlDocument opf,
  String opfPath, {
  String? id,
  bool coverProperty = false,
}) {
  for (final item in opf.descendants.whereType<XmlElement>()) {
    if (item.name.local != 'item') continue;
    final href = item.getAttribute('href');
    if (href == null) continue;
    final properties = item.getAttribute('properties') ?? '';
    if (id != null && item.getAttribute('id') == id) {
      return _resolve(opfPath, href);
    }
    if (coverProperty && properties.contains('cover-image')) {
      return _resolve(opfPath, href);
    }
  }
  return null;
}

List<int>? _fb2Cover(List<int> bytes) {
  final xml = XmlDocument.parse(String.fromCharCodes(bytes));
  for (final binary in xml.descendants.whereType<XmlElement>()) {
    if (binary.name.local != 'binary') continue;
    final id = (binary.getAttribute('id') ?? '').toLowerCase();
    if (!id.contains('cover')) continue;
    final text = binary.innerText.replaceAll(RegExp(r'\s+'), '');
    if (text.isEmpty) continue;
    try {
      return base64Decode(text);
    } on FormatException {
      return null;
    }
  }
  return null;
}

List<int>? _zipFirstImage(List<int> bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final names =
      archive
          .where((file) => file.isFile && looksLikeImageName(file.name))
          .map((file) => file.name)
          .toList()
        ..sort();
  if (names.isEmpty) return null;
  final file = archive.firstWhere((item) => item.name == names.first);
  return List<int>.from(file.content as List<int>);
}

String _read(Map<String, ArchiveFile> files, String path) {
  final file = files[_normalize(path)];
  if (file == null) throw const FormatException('missing cover source');
  return String.fromCharCodes(file.content as List<int>);
}

XmlDocument _xml(String source) => XmlDocument.parse(source);

String _resolve(String basePath, String href) {
  final cleaned = href.split('#').first.replaceAll('\\', '/');
  final slash = basePath.lastIndexOf('/');
  final dir = slash < 0 ? '' : basePath.substring(0, slash + 1);
  return _normalize(cleaned.startsWith('/') ? cleaned : '$dir$cleaned');
}

String _normalize(String path) {
  return path
      .replaceAll('\\', '/')
      .replaceAll(RegExp(r'^/+'), '')
      .toLowerCase();
}
