import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

import '../models/text_highlight.dart';

/// Lightweight EPUB/XHTML renderer — no flutter_html dependency.
class EpubHtmlView extends StatelessWidget {
  const EpubHtmlView({
    super.key,
    required this.html,
    required this.style,
    required this.textAlign,
    required this.textDirection,
    this.highlights = const [],
    this.darkHighlights = false,
  });

  final String html;
  final TextStyle style;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final List<TextHighlight> highlights;
  final bool darkHighlights;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(html);
    if (blocks.isEmpty) {
      return Text.rich(
        TextSpan(
          children: _highlightPlain(
            _stripTags(html),
            style,
            highlights,
            darkHighlights,
          ),
        ),
        textAlign: textAlign,
        textDirection: textDirection,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final block in blocks) ...[
          block.build(
            style: style,
            textAlign: textAlign,
            textDirection: textDirection,
            highlights: highlights,
            darkHighlights: darkHighlights,
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  static List<_Block> _parseBlocks(String raw) {
    final wrapped = _wrapFragment(raw);
    try {
      final doc = XmlDocument.parse(wrapped);
      final root = doc.rootElement;
      final blocks = <_Block>[];
      _collectBlocks(root, blocks);
      return blocks;
    } catch (_) {
      return _fallbackBlocks(raw);
    }
  }

  static String _wrapFragment(String raw) {
    var body = raw.trim();
    body = body
        .replaceAll(RegExp(r'<!--[\s\S]*?-->'), '')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '<br/>')
        .replaceAll(RegExp(r'<hr\s*/?>', caseSensitive: false), '<hr/>')
        .replaceAllMapped(
          RegExp(r'<img\b([^>]*?)(/?)>', caseSensitive: false),
          (m) => m.group(2) == '/' ? m.group(0)! : '<img${m.group(1)}/>',
        )
        .replaceAll('&nbsp;', '&#160;')
        .replaceAllMapped(
          RegExp(r'&(?!(#\d+|#x[0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]*);)'),
          (_) => '&amp;',
        );
    return '<chapter>$body</chapter>';
  }

  static void _collectBlocks(XmlNode node, List<_Block> out) {
    if (node is! XmlElement) {
      if (node is XmlText) {
        final text = _decode(node.value).trim();
        if (text.isNotEmpty) {
          out.add(_TextBlock([_Span(text, const {})]));
        }
      }
      return;
    }

    final name = node.localName.toLowerCase();
    if (_isBlockTag(name)) {
      if (name == 'img') {
        final src = node.getAttribute('src') ?? '';
        final bytes = _dataUriBytes(src);
        if (bytes != null) out.add(_ImageBlock(bytes));
        return;
      }
      if (name == 'hr') {
        out.add(const _DividerBlock());
        return;
      }
      if (name == 'br') {
        out.add(_TextBlock([_Span('\n', const {})]));
        return;
      }

      final spans = <_Span>[];
      _collectSpans(node, spans, {});
      final text = spans.map((s) => s.text).join().trim();
      final hasImageChild = node.descendants.any(
        (n) => n is XmlElement && n.localName.toLowerCase() == 'img',
      );

      for (final child in node.childElements) {
        if (child.localName.toLowerCase() == 'img') {
          final src = child.getAttribute('src') ?? '';
          final bytes = _dataUriBytes(src);
          if (bytes != null) out.add(_ImageBlock(bytes));
        }
      }

      if (text.isNotEmpty) {
        out.add(
          _TextBlock(
            spans
                .where((s) => s.text.trim().isNotEmpty || s.text.contains('\n'))
                .toList(),
            headingLevel: _headingLevel(name),
            quote: name == 'blockquote',
          ),
        );
      } else if (!hasImageChild && name.startsWith('h')) {
        // empty heading — skip
      }
      return;
    }

    for (final child in node.children) {
      _collectBlocks(child, out);
    }
  }

  static void _collectSpans(
    XmlNode node,
    List<_Span> out,
    Set<String> marks,
  ) {
    if (node is XmlText) {
      final text = _decode(node.value);
      if (text.isEmpty) return;
      out.add(_Span(text, Set<String>.from(marks)));
      return;
    }
    if (node is! XmlElement) return;

    final name = node.localName.toLowerCase();
    if (name == 'br') {
      out.add(_Span('\n', Set<String>.from(marks)));
      return;
    }
    if (name == 'img') return;

    final next = Set<String>.from(marks);
    if (name == 'i' || name == 'em') next.add('i');
    if (name == 'b' || name == 'strong') next.add('b');
    if (name == 'u') next.add('u');
    if (name == 'sup') next.add('sup');
    if (name == 'sub') next.add('sub');

    for (final child in node.children) {
      _collectSpans(child, out, next);
    }
  }

  static bool _isBlockTag(String name) => const {
        'p',
        'div',
        'section',
        'article',
        'header',
        'footer',
        'blockquote',
        'li',
        'h1',
        'h2',
        'h3',
        'h4',
        'h5',
        'h6',
        'pre',
        'table',
        'tr',
        'td',
        'th',
        'img',
        'hr',
        'br',
      }.contains(name);

  static int? _headingLevel(String name) {
    if (name.length == 2 && name.startsWith('h')) {
      return int.tryParse(name.substring(1));
    }
    return null;
  }

  static Uint8List? _dataUriBytes(String src) {
    final match = RegExp(
      r'^data:image/[^;]+;base64,(.+)$',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(src.trim());
    if (match == null) return null;
    try {
      return Uint8List.fromList(base64Decode(match.group(1)!));
    } catch (_) {
      return null;
    }
  }

  static String _decode(String value) => value
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#160;', ' ')
      .replaceAll('&nbsp;', ' ');

  static String _stripTags(String html) => html
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static List<_Block> _fallbackBlocks(String raw) {
    final parts = raw
        .split(
          RegExp(
            r'</(?:p|div|h[1-6]|li|blockquote)\s*>',
            caseSensitive: false,
          ),
        )
        .map(_stripTags)
        .where((t) => t.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      final t = _stripTags(raw);
      return t.isEmpty ? const [] : [_TextBlock([_Span(t, const {})])];
    }
    return [
      for (final p in parts) _TextBlock([_Span(p, const {})]),
    ];
  }
}

class _Span {
  const _Span(this.text, this.marks);
  final String text;
  final Set<String> marks;
}

abstract class _Block {
  const _Block();
  Widget build({
    required TextStyle style,
    required TextAlign textAlign,
    required TextDirection textDirection,
    required List<TextHighlight> highlights,
    required bool darkHighlights,
  });
}

class _TextBlock extends _Block {
  const _TextBlock(this.spans, {this.headingLevel, this.quote = false});
  final List<_Span> spans;
  final int? headingLevel;
  final bool quote;

  @override
  Widget build({
    required TextStyle style,
    required TextAlign textAlign,
    required TextDirection textDirection,
    required List<TextHighlight> highlights,
    required bool darkHighlights,
  }) {
    var base = style;
    if (headingLevel != null) {
      final scale = switch (headingLevel!) {
        1 => 1.4,
        2 => 1.28,
        3 => 1.16,
        _ => 1.08,
      };
      base = style.copyWith(
        fontSize: (style.fontSize ?? 22) * scale,
        fontWeight: FontWeight.w800,
        height: ((style.height ?? 1.6) * 0.92).clamp(1.2, 2.2),
      );
    }
    if (quote) {
      base = base.copyWith(
        fontStyle: FontStyle.italic,
        color: style.color?.withValues(alpha: 0.92),
      );
    }

    final children = _buildHighlightedSpans(
      spans,
      base,
      highlights,
      darkHighlights,
    );

    final text = Text.rich(
      TextSpan(children: children),
      textAlign: textAlign,
      textDirection: textDirection,
    );

    if (!quote) return text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          right: textDirection == TextDirection.rtl
              ? BorderSide(color: Colors.teal.withValues(alpha: 0.45), width: 3)
              : BorderSide.none,
          left: textDirection == TextDirection.ltr
              ? BorderSide(color: Colors.teal.withValues(alpha: 0.45), width: 3)
              : BorderSide.none,
        ),
      ),
      child: text,
    );
  }
}

List<InlineSpan> _buildHighlightedSpans(
  List<_Span> spans,
  TextStyle base,
  List<TextHighlight> highlights,
  bool dark,
) {
  if (spans.isEmpty) return const [];
  if (highlights.isEmpty) {
    return [
      for (final span in spans) _plainSpan(span, base),
    ];
  }

  // Flatten characters with their formatting marks.
  final chars = <({String ch, Set<String> marks})>[];
  for (final span in spans) {
    for (final rune in span.text.runes) {
      chars.add((ch: String.fromCharCode(rune), marks: span.marks));
    }
  }
  final plain = chars.map((c) => c.ch).join();
  final ranges = _matchRanges(plain, highlights);

  if (ranges.isEmpty) {
    return [
      for (final span in spans) _plainSpan(span, base),
    ];
  }

  final byStart = <int, _HighlightRange>{
    for (final r in ranges) r.start: r,
  };

  final out = <InlineSpan>[];
  var i = 0;
  while (i < chars.length) {
    final hit = byStart[i];
    if (hit != null) {
      final end = hit.end.clamp(0, chars.length);
      out.addAll(
        _emitChunk(
          chars.sublist(i, end),
          base,
          hit.highlight.backgroundForTheme(dark: dark),
        ),
      );
      i = end;
      continue;
    }
    var next = chars.length;
    for (final r in ranges) {
      if (r.start > i && r.start < next) next = r.start;
    }
    out.addAll(_emitChunk(chars.sublist(i, next), base, null));
    i = next;
  }
  return out;
}

List<InlineSpan> _emitChunk(
  List<({String ch, Set<String> marks})> chunk,
  TextStyle base,
  Color? background,
) {
  if (chunk.isEmpty) return const [];
  final out = <InlineSpan>[];
  var buf = StringBuffer();
  Set<String>? currentMarks;

  void flush() {
    if (buf.isEmpty || currentMarks == null) return;
    final marks = currentMarks!;
    out.add(
      TextSpan(
        text: buf.toString(),
        style: base.copyWith(
          fontStyle: marks.contains('i') ? FontStyle.italic : null,
          fontWeight: marks.contains('b') ? FontWeight.w800 : null,
          decoration: marks.contains('u') ? TextDecoration.underline : null,
          fontSize: marks.contains('sup') || marks.contains('sub')
              ? (base.fontSize ?? 22) * 0.72
              : null,
          backgroundColor: background,
        ),
      ),
    );
    buf = StringBuffer();
  }

  for (final item in chunk) {
    if (currentMarks == null) {
      currentMarks = item.marks;
      buf.write(item.ch);
    } else if (_sameMarks(currentMarks, item.marks)) {
      buf.write(item.ch);
    } else {
      flush();
      currentMarks = item.marks;
      buf.write(item.ch);
    }
  }
  flush();
  return out;
}

bool _sameMarks(Set<String> a, Set<String> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final v in a) {
    if (!b.contains(v)) return false;
  }
  return true;
}

TextSpan _plainSpan(_Span span, TextStyle base) {
  return TextSpan(
    text: span.text,
    style: base.copyWith(
      fontStyle: span.marks.contains('i') ? FontStyle.italic : null,
      fontWeight: span.marks.contains('b') ? FontWeight.w800 : null,
      decoration: span.marks.contains('u') ? TextDecoration.underline : null,
      fontSize: span.marks.contains('sup') || span.marks.contains('sub')
          ? (base.fontSize ?? 22) * 0.72
          : null,
    ),
  );
}

List<InlineSpan> _highlightPlain(
  String text,
  TextStyle style,
  List<TextHighlight> highlights,
  bool dark,
) {
  return _buildHighlightedSpans(
    [_Span(text, const {})],
    style,
    highlights,
    dark,
  );
}

class _HighlightRange {
  const _HighlightRange(this.start, this.end, this.highlight);
  final int start;
  final int end;
  final TextHighlight highlight;
}

/// Greedy non-overlapping matches; longer needles win at the same index.
List<_HighlightRange> _matchRanges(
  String plain,
  List<TextHighlight> highlights,
) {
  if (plain.isEmpty || highlights.isEmpty) return const [];

  final sorted = [...highlights]
    ..sort((a, b) => b.text.length.compareTo(a.text.length));
  final occupied = List<bool>.filled(plain.length, false);
  final ranges = <_HighlightRange>[];

  for (final h in sorted) {
    final needle = h.text;
    if (needle.trim().isEmpty) continue;
    var from = 0;
    while (true) {
      final match = _findFlexible(plain, needle, from);
      if (match == null) break;
      final i = match.$1;
      final end = match.$2;
      var free = true;
      for (var j = i; j < end; j++) {
        if (occupied[j]) {
          free = false;
          break;
        }
      }
      if (free) {
        for (var j = i; j < end; j++) {
          occupied[j] = true;
        }
        ranges.add(_HighlightRange(i, end, h));
      }
      from = i + 1;
    }
  }

  ranges.sort((a, b) => a.start.compareTo(b.start));
  return ranges;
}

/// Exact match first; then whitespace-flexible match for selection quirks.
(int, int)? _findFlexible(String haystack, String needle, int from) {
  if (from >= haystack.length) return null;
  final exact = haystack.indexOf(needle, from);
  if (exact >= 0) return (exact, exact + needle.length);

  final trimmed = needle.trim();
  if (trimmed.isEmpty) return null;
  final parts = trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return null;
  final pattern = parts.map(RegExp.escape).join(r'\s+');
  final match = RegExp(pattern).firstMatch(haystack.substring(from));
  if (match == null) return null;
  return (from + match.start, from + match.end);
}

class _ImageBlock extends _Block {
  const _ImageBlock(this.bytes);
  final Uint8List bytes;

  @override
  Widget build({
    required TextStyle style,
    required TextAlign textAlign,
    required TextDirection textDirection,
    required List<TextHighlight> highlights,
    required bool darkHighlights,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.memory(
        bytes,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}

class _DividerBlock extends _Block {
  const _DividerBlock();

  @override
  Widget build({
    required TextStyle style,
    required TextAlign textAlign,
    required TextDirection textDirection,
    required List<TextHighlight> highlights,
    required bool darkHighlights,
  }) {
    return Divider(color: style.color?.withValues(alpha: 0.15));
  }
}
