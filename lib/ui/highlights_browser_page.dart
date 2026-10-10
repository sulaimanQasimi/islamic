import 'package:flutter/material.dart';

import '../models/book.dart';
import '../models/text_highlight.dart';
import '../services/app_storage.dart';
import '../theme/marefat_theme.dart';

class HighlightItem {
  const HighlightItem({
    required this.book,
    required this.highlight,
  });
  final Book book;
  final TextHighlight highlight;
}

class HighlightsBrowserPage extends StatefulWidget {
  const HighlightsBrowserPage({
    super.key,
    required this.books,
    required this.onOpen,
  });

  final List<Book> books;
  final void Function(Book book, int chapter) onOpen;

  @override
  State<HighlightsBrowserPage> createState() => _HighlightsBrowserPageState();
}

class _HighlightsBrowserPageState extends State<HighlightsBrowserPage> {
  List<HighlightItem> _items = [];
  String _query = '';
  String? _tag;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await AppStorage.getInstance();
    final out = <HighlightItem>[];
    for (final book in widget.books) {
      final list = TextHighlight.decodeList(
        prefs.getString('highlights_json_${book.id}'),
      );
      for (final h in list) {
        out.add(HighlightItem(book: book, highlight: h));
      }
    }
    out.sort(
      (a, b) => b.highlight.createdAtMs.compareTo(a.highlight.createdAtMs),
    );
    if (mounted) setState(() => _items = out);
  }

  List<HighlightItem> get _filtered {
    final q = _query.trim().toLowerCase();
    return _items.where((item) {
      if (_tag != null && !item.highlight.tags.contains(_tag)) return false;
      if (q.isEmpty) return true;
      final blob =
          '${item.highlight.text} ${item.highlight.note ?? ''} ${item.highlight.tags.join(' ')} ${item.book.title}'
              .toLowerCase();
      return blob.contains(q);
    }).toList();
  }

  Set<String> get _allTags {
    final tags = <String>{};
    for (final i in _items) {
      tags.addAll(i.highlight.tags);
    }
    return tags;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('جست‌وجوی برجسته‌ها')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'جست‌وجو در متن، یادداشت یا برچسب…',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            if (_allTags.isNotEmpty)
              SizedBox(
                height: 42,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    FilterChip(
                      label: const Text('همه'),
                      selected: _tag == null,
                      onSelected: (_) => setState(() => _tag = null),
                    ),
                    const SizedBox(width: 6),
                    for (final t in _allTags) ...[
                      FilterChip(
                        label: Text(t),
                        selected: _tag == t,
                        onSelected: (_) => setState(
                          () => _tag = _tag == t ? null : t,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'موردی پیدا نشد.',
                        style: TextStyle(color: MarefatColors.muted),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final item = filtered[i];
                        final h = item.highlight;
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          tileColor: h.color.withValues(alpha: 0.25),
                          title: Text(
                            h.text,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${item.book.title} · فصل ${h.chapter + 1}'
                            '${h.tags.isEmpty ? '' : ' · ${h.tags.join('، ')}'}',
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            widget.onOpen(item.book, h.chapter);
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
