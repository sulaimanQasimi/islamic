import 'dart:typed_data';

import '../models/book.dart';
import 'book_backend.dart';
import 'book_cache.dart';
import 'epub_parser.dart';

/// Background prefetch of upcoming books / covers for smoother reading.
class PrefetchService {
  PrefetchService._();

  static Future<void> prefetchBooks({
    required BookBackend backend,
    required List<Book> books,
    int limit = 3,
  }) async {
    var n = 0;
    for (final book in books) {
      if (n >= limit) break;
      try {
        final cached = await BookCache.read(book.id);
        if (cached != null) {
          final cover = await BookCache.readCover(book.id);
          if (cover == null || cover.isEmpty) {
            final extracted = EpubParser.extractCover(cached);
            if (extracted != null && extracted.isNotEmpty) {
              await BookCache.writeCover(book.id, extracted);
            }
          }
          n++;
          continue;
        }
        final bytes = await backend.downloadBytes(book);
        await BookCache.write(book.id, bytes);
        final cover = EpubParser.extractCover(bytes);
        if (cover != null && cover.isNotEmpty) {
          await BookCache.writeCover(book.id, Uint8List.fromList(cover));
        }
        n++;
      } catch (_) {}
    }
  }
}
