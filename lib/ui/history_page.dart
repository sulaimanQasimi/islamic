import 'package:flutter/material.dart';

import '../models/book.dart';
import '../services/reading_history.dart';
import '../theme/marefat_theme.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({
    super.key,
    required this.books,
    required this.onOpenBook,
  });

  final List<Book> books;
  final ValueChanged<Book> onOpenBook;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<HistoryEntry> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await ReadingHistory.load();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Book? _bookFor(String id) {
    try {
      return widget.books.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }

  String _when(int ms) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} دقیقه پیش';
    if (diff.inHours < 24) return '${diff.inHours} ساعت پیش';
    if (diff.inDays < 7) return '${diff.inDays} روز پیش';
    return '${dt.year}/${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('تاریخچهٔ مطالعه'),
          actions: [
            if (_items.isNotEmpty)
              IconButton(
                tooltip: 'پاک کردن',
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => Directionality(
                      textDirection: TextDirection.rtl,
                      child: AlertDialog(
                        title: const Text('پاک کردن تاریخچه؟'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('لغو'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('پاک شود'),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (ok == true) {
                    await ReadingHistory.clear();
                    await _load();
                  }
                },
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? const Center(
                    child: Text(
                      'هنوز تاریخچه‌ای ثبت نشده است.',
                      style: TextStyle(color: MarefatColors.muted),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final book = _bookFor(item.bookId);
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        tileColor: Theme.of(context)
                            .colorScheme
                            .surface
                            .withValues(alpha: 0.9),
                        leading: CircleAvatar(
                          backgroundColor: MarefatColors.mistDeep,
                          child: Text(
                            '${item.chapter + 1}',
                            style: const TextStyle(
                              color: MarefatColors.forest,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${item.author} · فصل ${item.chapter + 1} · ${_when(item.atMs)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: book == null
                            ? null
                            : () {
                                Navigator.pop(context);
                                widget.onOpenBook(book);
                              },
                      );
                    },
                  ),
      ),
    );
  }
}
