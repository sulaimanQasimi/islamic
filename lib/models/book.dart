import 'package:flutter/material.dart';

class Book {
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.language,
    required this.direction,
    required this.description,
    required this.color,
    required this.icon,
    required this.featured,
    required this.originalTitle,
    required this.translator,
    required this.gutenbergId,
  });

  final String id;
  final String title;
  final String author;
  final String category;
  final String language;

  /// Content direction: `rtl` or `ltr`.
  final String direction;
  final String description;
  final Color color;
  final IconData icon;
  final bool featured;
  final String originalTitle;
  final String translator;
  final int gutenbergId;

  TextDirection get textDirection =>
      direction == 'ltr' ? TextDirection.ltr : TextDirection.rtl;

  static String normalizeDirection(String? value, {String? language}) {
    final normalized = value?.trim().toLowerCase();
    if (normalized == 'ltr' || normalized == 'rtl') return normalized!;
    final lang = (language ?? '').toLowerCase();
    if (lang.contains('انگلیسی') ||
        lang.contains('english') ||
        lang.contains('فرانسوی') ||
        lang.contains('french') ||
        lang.contains('latin')) {
      return 'ltr';
    }
    return 'rtl';
  }

  /// Cache/file-safe id: lowercase letters, digits, and hyphens only.
  static String normalizeId(String raw) {
    final id = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (id.isEmpty) {
      throw ArgumentError.value(raw, 'id', 'Invalid book id');
    }
    return id;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'category': category,
    'language': language,
    'direction': direction,
    'description': description,
    'originalTitle': originalTitle,
    'translator': translator,
    'color':
        '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
    'icon': switch (icon) {
      Icons.local_florist_rounded => 'local_florist',
      Icons.waves_rounded => 'waves',
      Icons.park_rounded => 'park',
      Icons.landscape_rounded => 'landscape',
      Icons.menu_book_rounded => 'menu_book',
      Icons.contacts_rounded => 'contacts',
      _ => 'auto_stories',
    },
    'featured': featured,
    'gutenbergId': gutenbergId,
  };

  factory Book.fromJson(Map<String, dynamic> json) {
    final colorText = (json['color'] as String? ?? '#2E6757').replaceFirst(
      '#',
      '',
    );
    final colorValue = int.tryParse(colorText, radix: 16) ?? 0xFF2E6757;
    final color = colorText.length >= 8
        ? Color(colorValue)
        : Color(colorValue | 0xFF000000);
    final language = json['language'] as String? ?? 'دری';
    final icon = switch (json['icon']) {
      'local_florist' => Icons.local_florist_rounded,
      'waves' => Icons.waves_rounded,
      'park' => Icons.park_rounded,
      'landscape' => Icons.landscape_rounded,
      'menu_book' => Icons.menu_book_rounded,
      'contacts' => Icons.contacts_rounded,
      _ => Icons.auto_stories_rounded,
    };
    return Book(
      id: normalizeId(json['id'] as String? ?? ''),
      title: json['title'] as String? ?? 'کتاب بی‌نام',
      author: json['author'] as String? ?? 'نویسنده نامشخص',
      category: json['category'] as String? ?? 'عمومی',
      language: language,
      direction: normalizeDirection(
        json['direction'] as String?,
        language: language,
      ),
      description: json['description'] as String? ?? '',
      originalTitle: json['originalTitle'] as String? ?? '',
      translator: json['translator'] as String? ?? '',
      color: color,
      icon: icon,
      featured: json['featured'] as bool? ?? false,
      gutenbergId: (json['gutenbergId'] as num?)?.toInt() ?? 0,
    );
  }
}
