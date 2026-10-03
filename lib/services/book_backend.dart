import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/book.dart';
import 'epub_parser.dart';

class BookBackend {
  BookBackend();

  static const _booksPrefix = 'assets/books/';
  final Map<String, String> _assetPaths = {};

  Future<List<Book>> fetchBooks() async {
    _assetPaths.clear();

    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final epubAssets = {
      for (final path in manifest.listAssets())
        if (path.startsWith(_booksPrefix) &&
            path.toLowerCase().endsWith('.epub'))
          path.substring(_booksPrefix.length): path,
    };

    if (epubAssets.isEmpty) {
      throw Exception('هیچ کتابی در پوشهٔ assets/books یافت نشد.');
    }

    final books = <Book>[];
    final claimedFiles = <String>{};

    try {
      final raw = await rootBundle.loadString('${_booksPrefix}catalog.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      for (final item in (json['books'] as List<dynamic>? ?? const [])) {
        final entry = Map<String, dynamic>.from(item as Map);
        final file = entry['file'] as String?;
        if (file == null || file.isEmpty) continue;
        final assetPath = epubAssets[file];
        if (assetPath == null) continue;
        final book = Book.fromJson(entry);
        claimedFiles.add(file);
        _assetPaths[book.id] = assetPath;
        books.add(book);
      }
    } catch (_) {
      // Catalogue is optional; books are still discovered from EPUB assets.
    }

    final orphanFiles = epubAssets.keys.where((f) => !claimedFiles.contains(f)).toList()
      ..sort();
    for (final fileName in orphanFiles) {
      final book = _bookFromFileName(fileName);
      _assetPaths[book.id] = epubAssets[fileName]!;
      books.add(book);
    }

    return books;
  }

  Future<EpubDocument> downloadBook(Book book) async {
    final bytes = await downloadBytes(book);
    return EpubParser.parse(
      bytes,
      fallbackTitle: book.title,
      fallbackAuthor: book.author,
    );
  }

  Future<Uint8List> downloadBytes(Book book) async {
    var assetPath = _assetPaths[book.id];
    if (assetPath == null) {
      await fetchBooks();
      assetPath = _assetPaths[book.id];
    }
    if (assetPath == null) {
      throw Exception('فایل کتاب پیدا نشد.');
    }
    final data = await rootBundle.load(assetPath);
    return data.buffer.asUint8List();
  }

  Book _bookFromFileName(String fileName) {
    final base =
        fileName.replaceAll(RegExp(r'\.epub$', caseSensitive: false), '');
    final id = base
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final title = base.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
    return Book(
      id: id.isEmpty ? base : id,
      title: title.isEmpty ? base : title,
      author: 'نویسنده نامشخص',
      category: 'عمومی',
      language: 'نامشخص',
      direction: 'rtl',
      description: '',
      color: const Color(0xFF2E6757),
      icon: Icons.auto_stories_rounded,
      featured: false,
      originalTitle: '',
      translator: '',
      gutenbergId: 0,
    );
  }
}
