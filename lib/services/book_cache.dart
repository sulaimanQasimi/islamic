import 'dart:typed_data';

import 'book_cache_web.dart' if (dart.library.io) 'book_cache_io.dart' as cache;

class BookCache {
  static Future<Uint8List?> read(String id) => cache.read(id);
  static Future<void> write(String id, Uint8List bytes) =>
      cache.write(id, bytes);
  static Future<bool> contains(String id) => cache.contains(id);
}
