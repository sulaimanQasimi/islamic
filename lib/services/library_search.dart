import 'dart:typed_data';

import '../models/book.dart';
import 'book_cache.dart';
import 'epub_parser.dart';

class LibrarySearchHit {
  const LibrarySearchHit({
    required this.book,
    required this.chapterIndex,
    required this.chapterTitle,
    required this.snippet,
  });

  final Book book;
  final int chapterIndex;
  final String chapterTitle;
  final String snippet;
}

class LibrarySearch {
  LibrarySearch._();

  /// Full-text search across cached EPUBs (and optional in-memory bytes).
  static Future<List<LibrarySearchHit>> search({
    required List<Book> books,
    required String query,
    Future<Uint8List?> Function(Book book)? loadBytes,
    int maxHits = 40,
  }) async {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return <LibrarySearchHit>[];
    final hits = <LibrarySearchHit>[];

    for (final book in books) {
      if (hits.length >= maxHits) break;
      try {
        Uint8List? bytes = await BookCache.read(book.id);
        bytes ??= loadBytes == null ? null : await loadBytes(book);
        if (bytes == null) {
          // Metadata-only fallback
          final blob =
              '${book.title} ${book.author} ${book.description} ${book.category}'
                  .toLowerCase();
          if (blob.contains(q)) {
            hits.add(
              LibrarySearchHit(
                book: book,
                chapterIndex: 0,
                chapterTitle: 'شناسهٔ کتاب',
                snippet: book.description.isNotEmpty
                    ? book.description
                    : book.title,
              ),
            );
          }
          continue;
        }
        final doc = EpubParser.parse(
          bytes,
          fallbackTitle: book.title,
          fallbackAuthor: book.author,
        );
        for (var i = 0; i < doc.chapters.length; i++) {
          if (hits.length >= maxHits) break;
          final ch = doc.chapters[i];
          final body = ch.body.toLowerCase();
          final idx = body.indexOf(q);
          if (idx < 0) continue;
          final start = (idx - 40).clamp(0, body.length);
          final end = (idx + q.length + 60).clamp(0, body.length);
          var snippet = ch.body.substring(start, end).replaceAll('\n', ' ');
          if (start > 0) snippet = '…$snippet';
          if (end < ch.body.length) snippet = '$snippet…';
          hits.add(
            LibrarySearchHit(
              book: book,
              chapterIndex: i,
              chapterTitle: ch.title,
              snippet: snippet,
            ),
          );
        }
      } catch (_) {
        // Skip unreadable books
      }
    }
    return hits;
  }
}
