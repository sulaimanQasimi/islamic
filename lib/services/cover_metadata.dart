import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Lightweight cover/metadata assist (practical stand-in for OCR):
/// reads title/author from EPUB OPF and optional filename heuristics.
class CoverMetadata {
  CoverMetadata._();

  static ({String? title, String? author, String? language}) extract(
    List<int> epubBytes,
  ) {
    try {
      final archive = ZipDecoder().decodeBytes(epubBytes);
      String read(String path) {
        final file = archive.findFile(path) ??
            archive.files.cast<ArchiveFile?>().firstWhere(
                  (f) =>
                      f != null &&
                      f.name.replaceAll('\\', '/').toLowerCase() ==
                          path.toLowerCase(),
                  orElse: () => null,
                );
        if (file == null) throw StateError('missing $path');
        return String.fromCharCodes(file.content as List<int>);
      }

      final container = XmlDocument.parse(read('META-INF/container.xml'));
      final opfPath = container
          .findAllElements('rootfile')
          .first
          .getAttribute('full-path');
      if (opfPath == null) return (title: null, author: null, language: null);
      final opf = XmlDocument.parse(read(opfPath));
      String? meta(String name) {
        for (final el in opf.findAllElements(name)) {
          final t = el.innerText.trim();
          if (t.isNotEmpty) return t;
        }
        // dc:title style
        for (final el in opf.descendants.whereType<XmlElement>()) {
          if (el.localName.toLowerCase() == name.toLowerCase()) {
            final t = el.innerText.trim();
            if (t.isNotEmpty) return t;
          }
        }
        return null;
      }

      return (
        title: meta('title'),
        author: meta('creator'),
        language: meta('language'),
      );
    } catch (_) {
      return (title: null, author: null, language: null);
    }
  }

  static String fromFileName(String fileName) {
    return fileName
        .replaceAll(RegExp(r'\.epub$', caseSensitive: false), '')
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .trim();
  }
}
