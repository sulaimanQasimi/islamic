import 'dart:convert';

import 'package:flutter/material.dart';

import 'app_storage.dart';

class BookCollection {
  const BookCollection({
    required this.id,
    required this.name,
    required this.bookIds,
    this.colorIndex = 0,
  });

  final String id;
  final String name;
  final List<String> bookIds;
  final int colorIndex;

  static const palette = <Color>[
    Color(0xFF1A5C4E),
    Color(0xFF8B6914),
    Color(0xFF3D5A80),
    Color(0xFF9B4D6C),
    Color(0xFF5C6B4A),
  ];

  Color get color => palette[colorIndex.clamp(0, palette.length - 1)];

  BookCollection copyWith({
    String? name,
    List<String>? bookIds,
    int? colorIndex,
  }) =>
      BookCollection(
        id: id,
        name: name ?? this.name,
        bookIds: bookIds ?? this.bookIds,
        colorIndex: colorIndex ?? this.colorIndex,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'bookIds': bookIds,
        'colorIndex': colorIndex,
      };

  factory BookCollection.fromJson(Map<String, dynamic> json) => BookCollection(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'قفسه',
        bookIds: (json['bookIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
      );
}

class CollectionsStore {
  CollectionsStore._();

  static const _key = 'bookCollections';

  static Future<List<BookCollection>> load() async {
    final prefs = await AppStorage.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <BookCollection>[];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((e) => BookCollection.fromJson(Map<String, dynamic>.from(e)))
          .where((c) => c.id.isNotEmpty)
          .toList();
    } catch (_) {
      return <BookCollection>[];
    }
  }

  static Future<void> save(List<BookCollection> items) async {
    final prefs = await AppStorage.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(items.map((e) => e.toJson()).toList()),
    );
  }

  static Future<BookCollection> create(String name, {int colorIndex = 0}) async {
    final items = List<BookCollection>.from(await load());
    final collection = BookCollection(
      id: 'c_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim().isEmpty ? 'قفسهٔ جدید' : name.trim(),
      bookIds: <String>[],
      colorIndex: colorIndex,
    );
    items.insert(0, collection);
    await save(items);
    return collection;
  }

  static Future<void> update(BookCollection collection) async {
    final items = List<BookCollection>.from(await load());
    final i = items.indexWhere((c) => c.id == collection.id);
    if (i < 0) return;
    items[i] = collection;
    await save(items);
  }

  static Future<void> delete(String id) async {
    final items = List<BookCollection>.from(await load());
    items.removeWhere((c) => c.id == id);
    await save(items);
  }

  static Future<void> toggleBook(String collectionId, String bookId) async {
    final items = List<BookCollection>.from(await load());
    final i = items.indexWhere((c) => c.id == collectionId);
    if (i < 0) return;
    final ids = List<String>.from(items[i].bookIds);
    if (ids.contains(bookId)) {
      ids.remove(bookId);
    } else {
      ids.add(bookId);
    }
    items[i] = items[i].copyWith(bookIds: ids);
    await save(items);
  }
}
