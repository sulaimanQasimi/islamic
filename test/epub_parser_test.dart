import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:islamic/services/epub_parser.dart';

void main() {
  const files = [
    'persian_literature_1.epub',
    'persian_literature_2.epub',
    'mesnevi.epub',
    'bustan_sadi.epub',
    'sketches_persia.epub',
  ];

  for (final file in files) {
    test('parses $file', () async {
      final bytes = await File('backend/books/$file').readAsBytes();
      final book = EpubParser.parse(
        bytes,
        fallbackTitle: file,
        fallbackAuthor: 'Project Gutenberg',
      );
      expect(book.title, isNotEmpty);
      expect(book.chapters, isNotEmpty);
      expect(book.chapters.first.body, isNotEmpty);
    });
  }
}
