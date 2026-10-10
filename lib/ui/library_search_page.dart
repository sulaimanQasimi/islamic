import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/book_backend.dart';
import '../services/library_search.dart';
import '../theme/marefat_theme.dart';

class LibrarySearchPage extends StatefulWidget {
  const LibrarySearchPage({
    super.key,
    required this.books,
    required this.backend,
    required this.onOpenHit,
  });

  final List<Book> books;
  final BookBackend backend;
  final void Function(Book book, int chapter) onOpenHit;

  @override
  State<LibrarySearchPage> createState() => _LibrarySearchPageState();
}

class _LibrarySearchPageState extends State<LibrarySearchPage> {
  final _controller = TextEditingController();
  List<LibrarySearchHit> _hits = [];
  bool _searching = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    final q = _controller.text.trim();
    if (q.length < 2) return;
    setState(() => _searching = true);
    final hits = await LibrarySearch.search(
      books: widget.books,
      query: q,
      loadBytes: (b) => widget.backend.downloadBytes(b),
    );
    if (!mounted) return;
    setState(() {
      _hits = hits;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('جست‌وجوی سراسری')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: 'عبارت را بنویسید…',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _run(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _searching ? null : _run,
                    child: const Text('جست‌وجو'),
                  ),
                ],
              ),
            ),
            if (_searching) const LinearProgressIndicator(),
            Expanded(
              child: _hits.isEmpty
                  ? const Center(
                      child: Text(
                        'نتیجه‌ای نیست.\nکتاب‌های کش‌شده سریع‌تر جست‌وجو می‌شوند.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: MarefatColors.muted, height: 1.6),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: _hits.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) {
                        final h = _hits[i];
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          tileColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.4),
                          title: Text(
                            h.book.title,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            '${h.chapterTitle}\n${h.snippet}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          isThreeLine: true,
                          onTap: () {
                            Navigator.pop(context);
                            widget.onOpenHit(h.book, h.chapterIndex);
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
