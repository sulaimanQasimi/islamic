import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:xml/xml.dart';

/// Lightweight EPUB/XHTML renderer — no flutter_html dependency.
class EpubHtmlView extends StatelessWidget {
  const EpubHtmlView({
    super.key,
    required this.html,
    required this.style,
    required this.textAlign,
    required this.textDirection,
  });

  final String html;
  final TextStyle style;
  final TextAlign textAlign;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(html);
    if (blocks.isEmpty) {
      return Text(
        _stripTags(html),
        style: style,
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
      // Fall back: split on block tags with regex when XML is too messy.
      return _fallbackBlocks(raw);
    }
  }

  static String _wrapFragment(String raw) {
    var body = raw.trim();
    // Make common HTML-ish fragments parseable as XML.
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

      // Prefer dedicated image blocks inside wrappers.
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
            spans.where((s) => s.text.trim().isNotEmpty || s.text.contains('\n')).toList(),
            headingLevel: _headingLevel(name),
            quote: name == 'blockquote',
          ),
        );
      } else if (!hasImageChild && name.startsWith('h')) {
        // empty heading — skip
      }
      return;
    }

    // Non-block container: recurse.
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
    if (name == 'img') return; // handled as block

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
        .split(RegExp(r'</(?:p|div|h[1-6]|li|blockquote)\s*>', caseSensitive: false))
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

    final children = <InlineSpan>[
      for (final span in spans)
        TextSpan(
          text: span.text,
          style: base.copyWith(
            fontStyle: span.marks.contains('i') ? FontStyle.italic : null,
            fontWeight: span.marks.contains('b') ? FontWeight.w800 : null,
            decoration: span.marks.contains('u') ? TextDecoration.underline : null,
            fontSize: span.marks.contains('sup') || span.marks.contains('sub')
                ? (base.fontSize ?? 22) * 0.72
                : null,
          ),
        ),
    ];

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

class _ImageBlock extends _Block {
  const _ImageBlock(this.bytes);
  final Uint8List bytes;

  @override
  Widget build({
    required TextStyle style,
    required TextAlign textAlign,
    required TextDirection textDirection,
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
  }) {
    return Divider(color: style.color?.withValues(alpha: 0.15));
  }
}
