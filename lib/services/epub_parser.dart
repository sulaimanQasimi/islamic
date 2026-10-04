import 'dart:convert';

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
  static EpubDocument parse(
    List<int> bytes, {
    required String fallbackTitle,
    required String fallbackAuthor,
  }) {
    final archive = ZipDecoder().decodeBytes(bytes);
    String read(String path) {
      final entry = archive.findFile(_normalize(path));
      if (entry == null) throw FormatException('Missing EPUB item: $path');
      final content = entry.content;
      if (content is List<int>) {
        return utf8.decode(content, allowMalformed: true);
      }
      throw FormatException('Invalid EPUB item: $path');
    }

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
