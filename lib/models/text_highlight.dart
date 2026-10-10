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
    required this.createdAtMs,
  });

  final String id;
  final int chapter;
  final String text;
  final int colorIndex;
  final String? note;
  final int createdAtMs;

  static const palette = <Color>[
    Color(0xFFFFF176), // yellow
    Color(0xFFA5D6A7), // green
    Color(0xFF90CAF9), // blue
    Color(0xFFF48FB1), // pink
    Color(0xFFFFCC80), // orange
  ];

  static const paletteLabels = <String>[
    'زرد',
    'سبز',
    'آبی',
    'صورتی',
    'نارنجی',
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
    int? createdAtMs,
  }) {
    return TextHighlight(
      id: id ?? this.id,
      chapter: chapter ?? this.chapter,
      text: text ?? this.text,
      colorIndex: colorIndex ?? this.colorIndex,
      note: clearNote ? null : (note ?? this.note),
      createdAtMs: createdAtMs ?? this.createdAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'chapter': chapter,
        'text': text,
        'colorIndex': colorIndex,
        if (note != null && note!.isNotEmpty) 'note': note,
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
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Legacy storage: `"chapter|selected text"`.
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
