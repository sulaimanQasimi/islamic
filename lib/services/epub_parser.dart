import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:collection/collection.dart';
import 'package:xml/xml.dart';

class EpubChapter {
  const EpubChapter({required this.title, required this.body});
  final String title;
  final String body;
}

class EpubDocument {
  const EpubDocument({
    required this.title,
    required this.author,
    required this.chapters,
  });
  final String title;
  final String author;
  final List<EpubChapter> chapters;
}

class EpubParser {
  static final _imageExt = RegExp(
    r'\.(jpe?g|png|webp|gif)$',
    caseSensitive: false,
  );
  static final _htmlImgSrc = RegExp(
    r'''(?:src|xlink:href)\s*=\s*["']([^"']+)["']''',
    caseSensitive: false,
  );

  /// Cover image from OPF metadata, or the first image on the first content page.
  static Uint8List? extractCover(List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      final readText = _textReader(archive);
      final readBytes = _bytesReader(archive);

      final container = XmlDocument.parse(readText('META-INF/container.xml'));
      final opfPath = container
          .findAllElements('rootfile')
          .first
          .getAttribute('full-path');
      if (opfPath == null || opfPath.isEmpty) return null;

      final package = XmlDocument.parse(readText(opfPath));
      final base = opfPath.contains('/')
          ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
          : '';

      final manifestPath = <String, String>{};
      final manifestProps = <String, String>{};
      final manifestMedia = <String, String>{};
      for (final item in package.findAllElements('item')) {
        final id = item.getAttribute('id');
        final href = item.getAttribute('href');
        if (id == null || href == null) continue;
        final path = _normalize(
          '$base${Uri.decodeComponent(Uri.parse(href).path)}',
        );
        manifestPath[id] = path;
        manifestProps[id] = item.getAttribute('properties') ?? '';
        manifestMedia[id] = item.getAttribute('media-type') ?? '';
      }

      // 1) EPUB3 cover-image property
      for (final entry in manifestProps.entries) {
        if (entry.value.split(RegExp(r'\s+')).contains('cover-image')) {
          final bytes = readBytes(manifestPath[entry.key]!);
          if (bytes != null && bytes.isNotEmpty) return bytes;
        }
      }

      // 2) EPUB2 meta name="cover"
      final metadata = package.findAllElements('metadata').firstOrNull;
      final coverId = metadata
          ?.findAllElements('meta')
          .where((m) => m.getAttribute('name')?.toLowerCase() == 'cover')
          .map((m) => m.getAttribute('content'))
          .firstWhere((c) => c != null && c.isNotEmpty, orElse: () => null);
      if (coverId != null && manifestPath.containsKey(coverId)) {
        final bytes = readBytes(manifestPath[coverId]!);
        if (bytes != null && bytes.isNotEmpty) return bytes;
      }

      // 3) Manifest item whose id/href looks like a cover
      for (final entry in manifestPath.entries) {
        final key = '${entry.key} ${entry.value}'.toLowerCase();
        final media = manifestMedia[entry.key] ?? '';
        if (key.contains('cover') &&
            (media.startsWith('image/') || _imageExt.hasMatch(entry.value))) {
          final bytes = readBytes(entry.value);
          if (bytes != null && bytes.isNotEmpty) return bytes;
        }
      }

      // 4) First <img> in spine HTML (skip empty nav pages)
      for (final ref in package.findAllElements('itemref')) {
        final idref = ref.getAttribute('idref');
        final path = idref == null ? null : manifestPath[idref];
        if (path == null) continue;
        final lower = path.toLowerCase();
        if (!(lower.endsWith('.xhtml') ||
            lower.endsWith('.html') ||
            lower.endsWith('.htm') ||
            lower.endsWith('.xml'))) {
          continue;
        }
        String html;
        try {
          html = readText(path);
        } catch (_) {
          continue;
        }
        final pageBase = path.contains('/')
            ? path.substring(0, path.lastIndexOf('/') + 1)
            : '';
        for (final match in _htmlImgSrc.allMatches(html)) {
          final rawSrc = match.group(1)?.trim();
          if (rawSrc == null || rawSrc.isEmpty) continue;
          if (rawSrc.startsWith('data:')) continue;
          final cleaned = rawSrc.split('#').first.split('?').first;
          final resolved = _normalize(
            '$pageBase${Uri.decodeComponent(Uri.parse(cleaned).path)}',
          );
          final bytes = readBytes(resolved);
          if (bytes == null || bytes.isEmpty) continue;
          if (_imageExt.hasMatch(resolved) || _looksLikeImage(bytes)) {
            return bytes;
          }
        }
      }

      // 5) Largest raster image in the archive
      Uint8List? best;
      var bestSize = 0;
      for (final file in archive.files) {
        if (!file.isFile) continue;
        final name = _normalize(file.name);
        if (!_imageExt.hasMatch(name)) continue;
        final content = file.content;
        if (content is! List<int>) continue;
        if (content.length > bestSize) {
          bestSize = content.length;
          best = Uint8List.fromList(content);
        }
      }
      return best;
    } catch (_) {
      return null;
    }
  }

  static bool _looksLikeImage(Uint8List bytes) {
    if (bytes.length < 4) return false;
    // JPEG
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) return true;
    // PNG
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }
    // GIF
    if (bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46) return true;
    // WEBP
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46) {
      return true;
    }
    return false;
  }

  static String Function(String path) _textReader(Archive archive) {
    return (path) {
      final entry = archive.findFile(_normalize(path));
      if (entry == null) throw FormatException('Missing EPUB item: $path');
      final content = entry.content;
      if (content is List<int>) {
        return utf8.decode(content, allowMalformed: true);
      }
      throw FormatException('Invalid EPUB item: $path');
    };
  }

  static Uint8List? Function(String path) _bytesReader(Archive archive) {
    return (path) {
      final entry = archive.findFile(_normalize(path));
      if (entry == null) return null;
      final content = entry.content;
      if (content is List<int>) return Uint8List.fromList(content);
      return null;
    };
  }

  static EpubDocument parse(
    List<int> bytes, {
    required String fallbackTitle,
    required String fallbackAuthor,
  }) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final read = _textReader(archive);

    final container = XmlDocument.parse(read('META-INF/container.xml'));
    final opfPath = container
        .findAllElements('rootfile')
        .first
        .getAttribute('full-path');
    if (opfPath == null || opfPath.isEmpty) {
      throw const FormatException('EPUB package is missing.');
    }
    final package = XmlDocument.parse(read(opfPath));
    final base = opfPath.contains('/')
        ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
        : '';
    final manifest = <String, String>{};
    for (final item in package.findAllElements('item')) {
      final id = item.getAttribute('id');
      final href = item.getAttribute('href');
      if (id == null || href == null) continue;
      final uri = Uri.parse(href);
      manifest[id] = _normalize('$base${Uri.decodeComponent(uri.path)}');
    }

    final metadata = package.findAllElements('metadata').firstOrNull;
    final title = metadata?.findElements('title').firstOrNull?.innerText.trim();
    final author = metadata
        ?.findElements('creator')
        .firstOrNull
        ?.innerText
        .trim();
    final chapters = <EpubChapter>[];
    final titlesByPath = _tocTitles(read, base);
    for (final ref in package.findAllElements('itemref')) {
      final path = manifest[ref.getAttribute('idref')];
      if (path == null) continue;
      // Note: inline markup (italics, images, tables) is flattened to plain
      // text; only paragraph structure is preserved.
      final html = read(path)
          .replaceAll(
            RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false),
            ' ',
          )
          .replaceAll(
            RegExp(
              r'<br\s*/?>|</(p|div|li|h[1-6]|blockquote|section)>',
              caseSensitive: false,
            ),
            '\n',
          )
          .replaceAll(RegExp(r'<[^>]+>'), ' ');
      final body = _decodeEntities(html)
          .replaceAll(RegExp(r'[ \t\r\f]+'), ' ')
          .replaceAll(RegExp(r' *\n *'), '\n')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();
      if (body.isEmpty) continue;
      chapters.add(
        EpubChapter(
          title: titlesByPath[path] ?? 'فصل ${chapters.length + 1}',
          body: body,
        ),
      );
    }
    if (chapters.isEmpty) {
      throw const FormatException('EPUB contains no readable text.');
    }
    return EpubDocument(
      title: title?.isNotEmpty == true ? title! : fallbackTitle,
      author: author?.isNotEmpty == true ? author! : fallbackAuthor,
      chapters: chapters,
    );
  }

  /// Maps normalized content paths to chapter titles from the NCX table of
  /// contents, when the EPUB provides one.
  static Map<String, String> _tocTitles(
    String Function(String path) read,
    String base,
  ) {
    try {
      // The NCX path is not tracked in the manifest above, so locate it via
      // the item whose href ends with .ncx.
      final container = XmlDocument.parse(read('META-INF/container.xml'));
      final opfPath = container
          .findAllElements('rootfile')
          .first
          .getAttribute('full-path');
      if (opfPath == null) return const {};
      final package = XmlDocument.parse(read(opfPath));
      String? ncxPath;
      for (final item in package.findAllElements('item')) {
        final href = item.getAttribute('href');
        if (href != null && href.toLowerCase().endsWith('.ncx')) {
          ncxPath = _normalize(
            '$base${Uri.decodeComponent(Uri.parse(href).path)}',
          );
          break;
        }
      }
      if (ncxPath == null) return const {};
      final ncx = XmlDocument.parse(read(ncxPath));
      final titles = <String, String>{};
      for (final point in ncx.findAllElements('navPoint')) {
        final label = point
            .findAllElements('text')
            .firstOrNull
            ?.innerText
            .trim();
        final src = point.findAllElements('content').firstOrNull?.getAttribute('src');
        if (label == null || label.isEmpty || src == null) continue;
        final path = src.split('#').first;
        if (path.isEmpty) continue;
        titles[_normalize('$base${Uri.decodeComponent(Uri.parse(path).path)}')] = label;
      }
      return titles;
    } catch (_) {
      return const {};
    }
  }

  static String _normalize(String path) {
    final parts = <String>[];
    for (final part in path.replaceAll('\\', '/').split('/')) {
      if (part.isEmpty || part == '.') continue;
      if (part == '..') {
        if (parts.isNotEmpty) parts.removeLast();
      } else {
        parts.add(part);
      }
    }
    return parts.join('/');
  }

  static String _decodeEntities(String source) => source.replaceAllMapped(
    RegExp(
      r'&(#x[0-9a-f]+|#\d+|amp|lt|gt|quot|apos|nbsp);',
      caseSensitive: false,
    ),
    (match) {
      final value = match[1]!;
      if (value.startsWith('#x')) {
        final sb = StringBuffer()..writeCharCode(int.parse(value.substring(2), radix: 16));
        return sb.toString();
      }
      if (value.startsWith('#')) {
        final sb = StringBuffer()..writeCharCode(int.parse(value.substring(1)));
        return sb.toString();
      }
      return switch (value.toLowerCase()) {
        'amp' => '&',
        'lt' => '<',
        'gt' => '>',
        'quot' => '"',
        'apos' => "'",
        'nbsp' => ' ',
        _ => match[0]!,
      };
    },
  );
}
