import 'dart:convert';

import 'package:flutter/material.dart';

/// A saved text highlight inside a book chapter.
class TextHighlight {
  const TextHighlight({
    required this.id,
    required this.chapter,
    required this.text,
    this.colorIndex = 0,
    this.note,
    this.tags = const [],
    required this.createdAtMs,
  });

  final String id;
  final int chapter;
  final String text;
  final int colorIndex;
  final String? note;
  final List<String> tags;
  final int createdAtMs;

  static const palette = <Color>[
    Color(0xFFFFF176),
    Color(0xFFA5D6A7),
    Color(0xFF90CAF9),
    Color(0xFFF48FB1),
    Color(0xFFFFCC80),
  ];

  static const paletteLabels = <String>[
    'زرد',
    'سبز',
    'آبی',
    'صورتی',
    'نارنجی',
  ];

  static const suggestedTags = <String>[
    'اخلاق',
    'دعا',
    'حفظ',
    'تفسیر',
    'حکمت',
    'مهم',
  ];

  Color get color => palette[colorIndex.clamp(0, palette.length - 1)];

  Color backgroundForTheme({required bool dark}) =>
      color.withValues(alpha: dark ? 0.45 : 0.72);

  TextHighlight copyWith({
    String? id,
    int? chapter,
    String? text,
    int? colorIndex,
    String? note,
    bool clearNote = false,
    List<String>? tags,
    int? createdAtMs,
  }) {
    return TextHighlight(
      id: id ?? this.id,
      chapter: chapter ?? this.chapter,
      text: text ?? this.text,
      colorIndex: colorIndex ?? this.colorIndex,
      note: clearNote ? null : (note ?? this.note),
      tags: tags ?? this.tags,
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'chapter': chapter,
        'text': text,
        'colorIndex': colorIndex,
        if (note != null && note!.isNotEmpty) 'note': note,
        if (tags.isNotEmpty) 'tags': tags,
        'createdAtMs': createdAtMs,
      };

  factory TextHighlight.fromJson(Map<String, dynamic> json) {
    return TextHighlight(
      id: json['id'] as String? ??
          'h_${json['createdAtMs'] ?? DateTime.now().millisecondsSinceEpoch}',
      chapter: (json['chapter'] as num?)?.toInt() ?? 0,
      text: (json['text'] as String? ?? '').trim(),
      colorIndex: (json['colorIndex'] as num?)?.toInt() ?? 0,
      note: json['note'] as String?,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .where((t) => t.trim().isNotEmpty)
              .toList() ??
          const [],
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  factory TextHighlight.fromLegacy(String entry) {
    final sep = entry.indexOf('|');
    final chapter = sep > 0 ? (int.tryParse(entry.substring(0, sep)) ?? 0) : 0;
    final text = sep >= 0 ? entry.substring(sep + 1).trim() : entry.trim();
    final now = DateTime.now().millisecondsSinceEpoch;
    return TextHighlight(
      id: 'legacy_${chapter}_${text.hashCode}_$now',
      chapter: chapter,
      text: text,
      createdAtMs: now,
    );
  }

  static List<TextHighlight> decodeList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return <TextHighlight>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <TextHighlight>[];
      return decoded
          .whereType<Map>()
          .map((e) => TextHighlight.fromJson(Map<String, dynamic>.from(e)))
          .where((h) => h.text.isNotEmpty)
          .toList();
    } catch (_) {
      return <TextHighlight>[];
    }
  }

  static String encodeList(List<TextHighlight> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());
}
